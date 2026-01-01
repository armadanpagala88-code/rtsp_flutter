const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const { authenticateToken } = require('../middleware/auth');

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
    // Return default data if file doesn't exist
    const { cctvList, categories } = require('../data/mockCctv');
    return { cctvList, categories };
}

// Save CCTV data to file
function saveCctvData(data) {
    try {
        fs.writeFileSync(dataFilePath, JSON.stringify(data, null, 2));
        return true;
    } catch (e) {
        console.error('Error saving CCTV data:', e);
        return false;
    }
}

// Initialize data file if not exists
if (!fs.existsSync(dataFilePath)) {
    const { cctvList, categories } = require('../data/mockCctv');
    saveCctvData({ cctvList, categories });
}

// Get all CCTV (for admin) - PROTECTED
router.get('/cctv', authenticateToken, (req, res) => {
    const data = loadCctvData();
    res.json({
        success: true,
        count: data.cctvList.length,
        data: data.cctvList
    });
});

// Get single CCTV by ID - PROTECTED
router.get('/cctv/:id', authenticateToken, (req, res) => {
    const data = loadCctvData();
    const cctv = data.cctvList.find(c => c.id === req.params.id);

    if (!cctv) {
        return res.status(404).json({
            success: false,
            error: 'CCTV not found'
        });
    }

    res.json({
        success: true,
        data: cctv
    });
});

// Create new CCTV - PROTECTED
router.post('/cctv', authenticateToken, (req, res) => {
    const data = loadCctvData();
    // Support WebRTC (preferred), HLS, and RTSP (legacy) field names
    const { name, owner, category, lat, lng, webrtcUrl, webrtcUrlHd, hlsUrl, hlsUrlHd, rtspUrl, rtspUrlHd, status } = req.body;
    const streamUrl = webrtcUrl || hlsUrl || rtspUrl;
    const streamUrlHd = webrtcUrlHd || hlsUrlHd || rtspUrlHd;

    // Validate required fields
    if (!name || !streamUrl) {
        return res.status(400).json({
            success: false,
            error: 'Name and Stream URL are required'
        });
    }

    // Generate new ID
    const newId = `cctv-${Date.now()}`;

    const newCctv = {
        id: newId,
        name: name,
        owner: owner || 'Admin',
        category: category || 'PANTAU_LALIN',
        location: {
            lat: parseFloat(lat) || -3.8513609,
            lng: parseFloat(lng) || 122.0338782
        },
        streams: [
            {
                quality: 'preview',
                url: streamUrl
            },
            {
                quality: 'main',
                url: streamUrlHd || streamUrl
            }
        ],
        status: status || 'online',
        thumbnail: `https://via.placeholder.com/320x180?text=${encodeURIComponent(name)}`
    };

    data.cctvList.push(newCctv);
    saveCctvData(data);

    res.status(201).json({
        success: true,
        message: 'CCTV created successfully',
        data: newCctv
    });
});

// Update CCTV - PROTECTED
router.put('/cctv/:id', authenticateToken, (req, res) => {
    const data = loadCctvData();
    const index = data.cctvList.findIndex(c => c.id === req.params.id);

    if (index === -1) {
        return res.status(404).json({
            success: false,
            error: 'CCTV not found'
        });
    }

    // Support WebRTC (preferred), HLS, and RTSP (legacy) field names
    const { name, owner, category, lat, lng, webrtcUrl, webrtcUrlHd, hlsUrl, hlsUrlHd, rtspUrl, rtspUrlHd, status } = req.body;
    const streamUrl = webrtcUrl || hlsUrl || rtspUrl;
    const streamUrlHd = webrtcUrlHd || hlsUrlHd || rtspUrlHd;
    const existingCctv = data.cctvList[index];

    // Update fields
    const updatedCctv = {
        ...existingCctv,
        name: name || existingCctv.name,
        owner: owner || existingCctv.owner,
        category: category || existingCctv.category,
        location: {
            lat: lat !== undefined ? parseFloat(lat) : existingCctv.location.lat,
            lng: lng !== undefined ? parseFloat(lng) : existingCctv.location.lng
        },
        streams: [
            {
                quality: 'preview',
                url: streamUrl || existingCctv.streams[0]?.url
            },
            {
                quality: 'main',
                url: streamUrlHd || streamUrl || existingCctv.streams[1]?.url
            }
        ],
        status: status || existingCctv.status,
        thumbnail: `https://via.placeholder.com/320x180?text=${encodeURIComponent(name || existingCctv.name)}`
    };

    data.cctvList[index] = updatedCctv;
    saveCctvData(data);

    res.json({
        success: true,
        message: 'CCTV updated successfully',
        data: updatedCctv
    });
});

// Delete CCTV - PROTECTED
router.delete('/cctv/:id', authenticateToken, (req, res) => {
    const data = loadCctvData();
    const index = data.cctvList.findIndex(c => c.id === req.params.id);

    if (index === -1) {
        return res.status(404).json({
            success: false,
            error: 'CCTV not found'
        });
    }

    const deleted = data.cctvList.splice(index, 1);
    saveCctvData(data);

    res.json({
        success: true,
        message: 'CCTV deleted successfully',
        data: deleted[0]
    });
});

// Get all categories
router.get('/categories', (req, res) => {
    const data = loadCctvData();
    res.json({
        success: true,
        data: data.categories
    });
});

module.exports = router;
