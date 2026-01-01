const express = require('express');
const cors = require('cors');
const http = require('http');
const WebSocket = require('ws');
const path = require('path');

// Routes
const cctvRoutes = require('./routes/cctv');
const streamRoutes = require('./routes/stream');
const adminRoutes = require('./routes/admin');
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const categoryRoutes = require('./routes/categoryRoutes');
const trashBinRoutes = require('./routes/trashBinRoutes');
const geojsonRoutes = require('./routes/geojsonRoutes');
// const aiRoutes = require('./routes/aiRoutes'); // AI service deployed separately

// Services
const rtspProxyService = require('./services/rtspProxy');

const app = express();
const server = http.createServer(app);

// WebSocket server for streaming
const wss = new WebSocket.Server({ server, path: '/ws' });

// Middleware
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Static files for HLS streams
app.use('/hls', express.static(path.join(__dirname, 'hls')));

// Static files for uploads
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// API Routes
app.use('/api/cctv', cctvRoutes);
app.use('/api/stream', streamRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/admin/users', userRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/trash-bins', trashBinRoutes);
app.use('/api/geojson', geojsonRoutes);
// app.use('/api/ai', aiRoutes); // AI service deployed separately

// Health check
app.get('/api/health', (req, res) => {
    res.json({
        success: true,
        message: 'RTSP CCTV Backend is running',
        timestamp: new Date().toISOString()
    });
});

// Get active streams
app.get('/api/streams/active', (req, res) => {
    const activeStreams = rtspProxyService.getAllActiveStreams();
    res.json({
        success: true,
        count: activeStreams.length,
        data: activeStreams
    });
});

// Start a stream
app.post('/api/streams/start', (req, res) => {
    const { cctvId, quality = 'preview' } = req.body;

    if (!cctvId) {
        return res.status(400).json({
            success: false,
            error: 'cctvId is required'
        });
    }

    try {
        // Assign a dynamic port for this stream
        const basePort = 9000;
        const activeStreams = rtspProxyService.getAllActiveStreams();
        const wsPort = basePort + activeStreams.length;

        const streamInfo = rtspProxyService.startStream(cctvId, quality, wsPort);

        res.json({
            success: true,
            data: {
                cctvId,
                quality,
                wsPort: streamInfo.wsPort
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Stop a stream
app.post('/api/streams/stop', (req, res) => {
    const { cctvId, quality = 'preview' } = req.body;

    if (!cctvId) {
        return res.status(400).json({
            success: false,
            error: 'cctvId is required'
        });
    }

    const stopped = rtspProxyService.stopStream(cctvId, quality);

    res.json({
        success: true,
        stopped
    });
});

// WebSocket connection handling
wss.on('connection', (ws, req) => {
    console.log('New WebSocket connection');

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);

            if (data.type === 'subscribe') {
                // Handle stream subscription
                console.log(`Client subscribed to stream: ${data.cctvId}`);
            }
        } catch (error) {
            console.error('WebSocket message error:', error);
        }
    });

    ws.on('close', () => {
        console.log('WebSocket connection closed');
    });
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({
        success: false,
        error: 'Internal server error'
    });
});

// Serve Flutter Web frontend from public folder
app.use(express.static(path.join(__dirname, 'public')));

// SPA fallback - serve index.html for non-API routes
app.get('*', (req, res) => {
    // If it's an API route that wasn't found, return 404 JSON
    if (req.path.startsWith('/api/')) {
        return res.status(404).json({
            success: false,
            error: 'API route not found'
        });
    }
    // For all other routes, serve the Flutter web app
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

const PORT = process.env.PORT || 3000;

server.listen(PORT, () => {
    console.log(`🚀 RTSP CCTV Backend running on port ${PORT}`);
    console.log(`📡 WebSocket server running on ws://localhost:${PORT}/ws`);
    console.log(`🔗 API available at http://localhost:${PORT}/api`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received. Shutting down gracefully...');
    rtspProxyService.stopAllStreams();
    server.close(() => {
        console.log('Server closed');
        process.exit(0);
    });
});

module.exports = { app, server };
