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
    // Return default data if file doesn't exist
    return { cctvList: [], categories: [] };
}

// Get all categories
router.get('/categories', (req, res) => {
    const data = loadCctvData();
    res.json({
        success: true,
        data: data.categories
    });
});

// Get all CCTV
// Optional auth - if authenticated, show streams; otherwise hide them
router.get('/', (req, res) => {
    const { category, status, search } = req.query;
    const data = loadCctvData();

    let filtered = [...data.cctvList];

    // Filter by category
    if (category) {
        filtered = filtered.filter(cctv => cctv.category === category);
    }

    // Filter by status
    if (status) {
        filtered = filtered.filter(cctv => cctv.status === status);
    }

    // Search by name
    if (search) {
        const searchLower = search.toLowerCase();
        filtered = filtered.filter(cctv =>
            cctv.name.toLowerCase().includes(searchLower) ||
            cctv.owner.toLowerCase().includes(searchLower)
        );
    }

    // Check if user is authenticated (has valid JWT token)
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    let isAuthenticated = false;

    if (token) {
        try {
            const jwt = require('jsonwebtoken');
            const JWT_SECRET = process.env.JWT_SECRET || 'cctv-streaming-secret-key-2024';
            jwt.verify(token, JWT_SECRET);
            isAuthenticated = true;
        } catch (err) {
            // Invalid token - treat as unauthenticated
            isAuthenticated = false;
        }
    }

    // If NOT authenticated, hide stream URLs (they contain credentials)
    if (!isAuthenticated) {
        filtered = filtered.map(cctv => {
            const { streams, ...safeData } = cctv;
            return {
                ...safeData,
                streams: [] // Hide streams for public access
            };
        });
    }

    res.json({
        success: true,
        count: filtered.length,
        data: filtered,
        authenticated: isAuthenticated
    });
});

// Get CCTV by ID
router.get('/:id', (req, res) => {
    const data = loadCctvData();
    const cctv = data.cctvList.find(c => c.id === req.params.id);

    if (!cctv) {
        return res.status(404).json({
            success: false,
            error: 'CCTV not found'
        });
    }

    // Check if user is authenticated
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    let isAuthenticated = false;

    if (token) {
        try {
            const jwt = require('jsonwebtoken');
            const JWT_SECRET = process.env.JWT_SECRET || 'cctv-streaming-secret-key-2024';
            jwt.verify(token, JWT_SECRET);
            isAuthenticated = true;
        } catch (err) {
            isAuthenticated = false;
        }
    }

    // Hide streams if not authenticated
    let responseData = cctv;
    if (!isAuthenticated) {
        const { streams, ...safeData } = cctv;
        responseData = { ...safeData, streams: [] };
    }

    res.json({
        success: true,
        data: responseData
    });
});

// Get CCTV by category
router.get('/category/:categoryId', (req, res) => {
    const data = loadCctvData();
    const filtered = data.cctvList.filter(c => c.category === req.params.categoryId);

    res.json({
        success: true,
        count: filtered.length,
        data: filtered
    });
});

// Get statistics
router.get('/stats/overview', (req, res) => {
    const data = loadCctvData();
    const stats = {
        total: data.cctvList.length,
        online: data.cctvList.filter(c => c.status === 'online').length,
        offline: data.cctvList.filter(c => c.status === 'offline').length,
        byCategory: {}
    };

    data.categories.forEach(cat => {
        stats.byCategory[cat.id] = data.cctvList.filter(c => c.category === cat.id).length;
    });

    res.json({
        success: true,
        data: stats
    });
});

module.exports = router;
