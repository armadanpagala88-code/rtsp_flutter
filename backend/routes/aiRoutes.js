const express = require('express');
const router = express.Router();
const axios = require('axios');
const fs = require('fs');
const path = require('path');

// AI Service configuration
const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://localhost:5001';

// Load CCTV data to get RTSP URLs
const dataFilePath = path.join(__dirname, '../data/cctvData.json');

function loadCctvData() {
    try {
        if (fs.existsSync(dataFilePath)) {
            const data = fs.readFileSync(dataFilePath, 'utf8');
            return JSON.parse(data);
        }
    } catch (e) {
        console.error('Error loading CCTV data:', e);
    }
    return { cctvList: [] };
}

// Check AI service health
router.get('/health', async (req, res) => {
    try {
        const response = await axios.get(`${AI_SERVICE_URL}/health`, {
            timeout: 5000
        });
        res.json({
            success: true,
            aiService: response.data
        });
    } catch (error) {
        res.status(503).json({
            success: false,
            error: 'AI service not available',
            message: error.message
        });
    }
});

// Start AI detection on a stream
router.post('/start', async (req, res) => {
    const { cctvId, quality = 'preview' } = req.body;

    if (!cctvId) {
        return res.status(400).json({
            success: false,
            error: 'cctvId is required'
        });
    }

    try {
        // Get CCTV data
        const data = loadCctvData();
        const cctv = data.cctvList.find(c => c.id === cctvId);

        if (!cctv) {
            return res.status(404).json({
                success: false,
                error: 'CCTV not found'
            });
        }

        // Get RTSP URL based on quality
        const rtspUrl = quality === 'hd' ? cctv.rtspUrl : cctv.previewUrl;

        if (!rtspUrl) {
            return res.status(400).json({
                success: false,
                error: 'RTSP URL not configured for this CCTV'
            });
        }

        // Start AI detection via AI service
        const streamId = `${cctvId}_${quality}`;
        const aiResponse = await axios.post(`${AI_SERVICE_URL}/api/ai/start`, {
            streamId,
            rtspUrl
        }, {
            timeout: 10000
        });

        res.json({
            success: true,
            data: {
                cctvId,
                quality,
                streamId,
                streamUrl: `${AI_SERVICE_URL}${aiResponse.data.streamUrl}`,
                localStreamUrl: `/api/ai/stream/${streamId}`
            }
        });

    } catch (error) {
        console.error('AI start error:', error.message);
        res.status(500).json({
            success: false,
            error: 'Failed to start AI detection',
            message: error.response?.data?.error || error.message
        });
    }
});

// Stop AI detection on a stream
router.post('/stop', async (req, res) => {
    const { cctvId, quality = 'preview' } = req.body;

    if (!cctvId) {
        return res.status(400).json({
            success: false,
            error: 'cctvId is required'
        });
    }

    try {
        const streamId = `${cctvId}_${quality}`;

        const aiResponse = await axios.post(`${AI_SERVICE_URL}/api/ai/stop`, {
            streamId
        }, {
            timeout: 5000
        });

        res.json({
            success: true,
            stopped: aiResponse.data.stopped
        });

    } catch (error) {
        console.error('AI stop error:', error.message);
        res.status(500).json({
            success: false,
            error: 'Failed to stop AI detection',
            message: error.response?.data?.error || error.message
        });
    }
});

// Get detection statistics
router.get('/stats/:cctvId', async (req, res) => {
    const { cctvId } = req.params;
    const { quality = 'preview' } = req.query;

    try {
        const streamId = `${cctvId}_${quality}`;

        const aiResponse = await axios.get(`${AI_SERVICE_URL}/api/ai/stats/${streamId}`, {
            timeout: 5000
        });

        res.json({
            success: true,
            data: aiResponse.data.data
        });

    } catch (error) {
        res.status(error.response?.status || 500).json({
            success: false,
            error: 'Failed to get statistics',
            message: error.response?.data?.error || error.message
        });
    }
});

// Get all active AI streams
router.get('/active', async (req, res) => {
    try {
        const aiResponse = await axios.get(`${AI_SERVICE_URL}/api/ai/active`, {
            timeout: 5000
        });

        res.json({
            success: true,
            count: aiResponse.data.count,
            streams: aiResponse.data.streams
        });

    } catch (error) {
        res.status(500).json({
            success: false,
            error: 'Failed to get active streams',
            message: error.response?.data?.error || error.message
        });
    }
});

// Proxy stream endpoint (optional - can directly use AI service URL)
router.get('/stream/:streamId', async (req, res) => {
    const { streamId } = req.params;

    try {
        // Proxy the MJPEG stream from AI service
        const streamResponse = await axios.get(
            `${AI_SERVICE_URL}/api/ai/stream/${streamId}`,
            {
                responseType: 'stream',
                timeout: 30000
            }
        );

        res.setHeader('Content-Type', 'multipart/x-mixed-replace; boundary=frame');
        streamResponse.data.pipe(res);

    } catch (error) {
        res.status(error.response?.status || 500).json({
            success: false,
            error: 'Stream not available',
            message: error.response?.data?.error || error.message
        });
    }
});

module.exports = router;
