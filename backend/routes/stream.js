const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');

// Data file path
const dataFilePath = path.join(__dirname, '../data/cctvData.json');

// Load CCTV data from file
function loadCctvData() {
    try {
        if (fs.existsSync(dataFilePath)) {
            const data = fs.readFileSync(dataFilePath, 'utf8');
            return JSON.parse(data);
        }
    } catch (e) {
        console.error('Error loading CCTV data:', e);
    }
    return { cctvList: [], categories: [] };
}

// Get stream info for a CCTV
router.get('/:id', (req, res) => {
    const data = loadCctvData();
    const cctv = data.cctvList.find(c => c.id === req.params.id);

    if (!cctv) {
        return res.status(404).json({
            success: false,
            error: 'CCTV not found'
        });
    }

    // Return stream URLs
    // In production, this would return HLS/WebSocket URLs
    const streamInfo = {
        id: cctv.id,
        name: cctv.name,
        streams: cctv.streams.map(s => ({
            quality: s.quality,
            // WebSocket URL for streaming
            wsUrl: `ws://${req.headers.host}/ws/stream/${cctv.id}/${s.quality}`,
            // HLS URL (if available)
            hlsUrl: `/hls/${cctv.id}/${s.quality}/stream.m3u8`
        })),
        thumbnail: cctv.thumbnail
    };

    res.json({
        success: true,
        data: streamInfo
    });
});

// Get multiple streams info
router.post('/multi', (req, res) => {
    const { ids } = req.body;

    if (!ids || !Array.isArray(ids)) {
        return res.status(400).json({
            success: false,
            error: 'Invalid request. Provide array of CCTV IDs'
        });
    }

    const data = loadCctvData();
    const streams = ids.map(id => {
        const cctv = data.cctvList.find(c => c.id === id);
        if (!cctv) return null;

        return {
            id: cctv.id,
            name: cctv.name,
            streams: cctv.streams.map(s => ({
                quality: s.quality,
                wsUrl: `ws://${req.headers.host}/ws/stream/${cctv.id}/${s.quality}`,
                hlsUrl: `/hls/${cctv.id}/${s.quality}/stream.m3u8`
            })),
            thumbnail: cctv.thumbnail
        };
    }).filter(s => s !== null);

    res.json({
        success: true,
        count: streams.length,
        data: streams
    });
});

module.exports = router;
