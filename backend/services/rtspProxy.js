const { spawn } = require('child_process');
const WebSocket = require('ws');
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

class RtspProxyService {
    constructor() {
        this.activeStreams = new Map();
    }

    /**
     * Start streaming for a specific CCTV
     */
    startStream(cctvId, quality = 'preview', wsPort) {
        const streamKey = `${cctvId}-${quality}`;

        if (this.activeStreams.has(streamKey)) {
            console.log(`Stream ${streamKey} already active`);
            return this.activeStreams.get(streamKey);
        }

        const data = loadCctvData();
        const cctv = data.cctvList.find(c => c.id === cctvId);
        if (!cctv) throw new Error(`CCTV ${cctvId} not found`);

        const streamConfig = cctv.streams.find(s => s.quality === quality);
        if (!streamConfig) throw new Error(`Stream quality ${quality} not found for CCTV ${cctvId}`);

        console.log(`Setting up stream for ${cctvId} via port ${wsPort}`);

        // Find available port if requested port is in use
        const usedPorts = Array.from(this.activeStreams.values()).map(s => s.wsPort);
        while (usedPorts.includes(wsPort)) {
            console.log(`Port ${wsPort} already in use, trying next port`);
            wsPort++;
        }

        console.log(`Using port ${wsPort} for stream ${streamKey}`);

        // Setup WebSocket Server for this stream
        const wss = new WebSocket.Server({ port: wsPort });

        // Log when server is actually listening
        wss.on('listening', () => {
            console.log(`✅ WebSocket server LISTENING on port ${wsPort} for ${streamKey}`);
        });

        // Handle WebSocket server errors
        wss.on('error', (error) => {
            console.error(`❌ WebSocket server error for ${streamKey}:`, error.message, error.code);
            if (error.code === 'EADDRINUSE') {
                console.error(`Port ${wsPort} is in use, stream ${streamKey} will be stopped`);
            }
            this.stopStream(cctvId, quality);
        });

        // Setup FFmpeg with CORRECT argument order
        // Options BEFORE -i are input options
        const ffmpegArgs = [
            '-rtsp_transport', 'tcp',        // Critical for TP-LINK
            '-i', streamConfig.url,           // Input URL
            '-f', 'mpegts',                   // Output format
            '-codec:v', 'mpeg1video',         // Video codec for JSMpeg
            '-s', quality === 'preview' ? '640x360' : '1280x720',
            '-b:v', quality === 'preview' ? '800k' : '2000k',
            '-r', '25',
            '-bf', '0',
            '-preset', 'ultrafast',
            '-tune', 'zerolatency',
            '-an',                            // No audio to save bandwidth
            '-'                               // Output to stdout
        ];

        console.log(`FFmpeg command: ffmpeg ${ffmpegArgs.join(' ')}`);

        const ffmpegProcess = spawn('ffmpeg', ffmpegArgs);

        ffmpegProcess.stderr.on('data', (data) => {
            const msg = data.toString();
            if (msg.includes('frame=')) {
                // Typical progress message, keep it quiet or log sparingly
            } else {
                console.log(`FFmpeg [${streamKey}]: ${msg.trim()}`);
            }
        });

        ffmpegProcess.stdout.on('data', (data) => {
            // Broadcast to all connected WebSocket clients
            wss.clients.forEach((client) => {
                if (client.readyState === WebSocket.OPEN) {
                    client.send(data);
                }
            });
        });

        ffmpegProcess.on('close', (code) => {
            console.log(`FFmpeg process ${streamKey} exited with code ${code}`);
            this.stopStream(cctvId, quality);
        });

        const streamInfo = {
            wss,
            ffmpegProcess,
            wsPort,
            startTime: new Date(),
            viewers: 0
        };

        this.activeStreams.set(streamKey, streamInfo);

        wss.on('connection', (ws) => {
            streamInfo.viewers++;
            console.log(`New viewer for ${streamKey}. Total: ${streamInfo.viewers}`);

            ws.on('close', () => {
                streamInfo.viewers--;
                console.log(`Viewer left ${streamKey}. Total: ${streamInfo.viewers}`);
            });
        });

        return streamInfo;
    }

    /**
     * Stop streaming for a specific CCTV
     */
    stopStream(cctvId, quality = 'preview') {
        const streamKey = `${cctvId}-${quality}`;
        const streamInfo = this.activeStreams.get(streamKey);

        if (!streamInfo) return false;

        if (streamInfo.ffmpegProcess) {
            streamInfo.ffmpegProcess.kill('SIGKILL');
        }

        if (streamInfo.wss) {
            streamInfo.wss.close();
        }

        this.activeStreams.delete(streamKey);
        console.log(`Stopped stream ${streamKey}`);
        return true;
    }

    getStreamInfo(cctvId, quality = 'preview') {
        const streamKey = `${cctvId}-${quality}`;
        return this.activeStreams.get(streamKey) || null;
    }

    getAllActiveStreams() {
        const streams = [];
        this.activeStreams.forEach((value, key) => {
            streams.push({
                key,
                wsPort: value.wsPort,
                startTime: value.startTime,
                viewers: value.viewers
            });
        });
        return streams;
    }

    stopAllStreams() {
        this.activeStreams.forEach((value, key) => {
            if (value.ffmpegProcess) value.ffmpegProcess.kill('SIGKILL');
            if (value.wss) value.wss.close();
        });
        this.activeStreams.clear();
        console.log('All streams stopped');
    }
}

const rtspProxyService = new RtspProxyService();
module.exports = rtspProxyService;
