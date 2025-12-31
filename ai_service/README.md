# AI Detection Service for RTSP CCTV

This service provides AI-powered trash detection for RTSP video streams using YOLOv8.

## Features

- **Real-time Detection**: Detect trash bins, overflowing trash, and scattered trash in RTSP streams
- **YOLO Integration**: Uses YOLOv8 for object detection
- **REST API**: Flask-based API for easy integration
- **Multi-stream Support**: Process multiple RTSP streams simultaneously
- **Statistics**: Track detection counts and stream performance

## Setup

### Install Dependencies

```bash
cd ai_service
pip3 install -r requirements.txt
```

### Configuration

Edit `config.json` to customize:
- YOLO model type (yolov8n, yolov8s, yolov8m, etc.)
- Confidence thresholds
- Class mappings and colors
- Streaming parameters

## Usage

### Start the AI Service

```bash
python3 ai_server.py
```

The service will start on port 5000 by default.

### API Endpoints

#### Health Check
```bash
GET /health
```

#### Start AI Detection
```bash
POST /api/ai/start
Content-Type: application/json

{
  "streamId": "cctv-1",
  "rtspUrl": "rtsp://example.com/stream"
}
```

#### Stop AI Detection
```bash
POST /api/ai/stop
Content-Type: application/json

{
  "streamId": "cctv-1"
}
```

#### Get Video Stream (MJPEG)
```bash
GET /api/ai/stream/{streamId}
```

#### Get Detection Statistics
```bash
GET /api/ai/stats/{streamId}
GET /api/ai/stats  # All streams
```

#### Get Active Streams
```bash
GET /api/ai/active
```

## Detection Classes

The system detects three main categories:

1. **Bak Sampah** (Trash Container)
   - Color: Blue bounding box
   - Detects trash bins and containers

2. **Sampah_Overload** (Overflowing Trash)
   - Color: White box with dark blue text
   - Triggered when multiple items detected in cluster

3. **Sampah_Berserakan** (Scattered Trash)
   - Color: Cyan bounding box
   - Detects scattered trash items (bottles, cups, etc.)

## Integration with Node.js Backend

The AI service is designed to work alongside the Node.js backend. The Node.js server can proxy requests to this service for AI-enhanced streaming.

## Performance Tips

- Use GPU acceleration for better performance (CUDA-enabled GPU)
- Adjust `fps` in config.json to balance performance and accuracy
- Use lighter YOLO models (yolov8n) for faster processing
- Limit concurrent streams based on available resources

## Troubleshooting

### YOLO Model Download
On first run, YOLOv8 will download the model file (~6MB for yolov8n). Ensure internet connection is available.

### RTSP Connection Issues
- Verify RTSP URL is accessible
- Check firewall settings
- Some cameras require authentication in the URL format: `rtsp://user:pass@ip:port/path`

### Performance Issues
- Reduce stream resolution in config.json
- Lower FPS setting
- Use a lighter YOLO model
- Check CPU/GPU usage
