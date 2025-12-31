from flask import Flask, Response, jsonify, request
from flask_cors import CORS
import cv2
import json
import os
from stream_processor import StreamProcessor

app = Flask(__name__)
CORS(app)

# Initialize stream processor
processor = StreamProcessor()

# Store frame buffers for each stream
frame_buffers = {}

def frame_callback(stream_id, frame, detection_stats):
    """Callback function to receive processed frames"""
    # Encode frame as JPEG
    _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
    frame_buffers[stream_id] = {
        'frame': buffer.tobytes(),
        'stats': detection_stats
    }

def generate_stream(stream_id):
    """Generator function for MJPEG stream"""
    while processor.is_active(stream_id):
        if stream_id in frame_buffers and frame_buffers[stream_id]['frame']:
            frame_bytes = frame_buffers[stream_id]['frame']
            
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
        
        # Small delay to control bandwidth
        import time
        time.sleep(0.033)  # ~30fps max

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'ok',
        'service': 'AI Detection Service',
        'active_streams': len(processor.active_streams)
    })

@app.route('/api/ai/start', methods=['POST'])
def start_detection():
    """Start AI detection on a stream"""
    data = request.json
    stream_id = data.get('streamId')
    rtsp_url = data.get('rtspUrl')
    
    if not stream_id or not rtsp_url:
        return jsonify({
            'success': False,
            'error': 'streamId and rtspUrl are required'
        }), 400
    
    # Check if already processing
    if processor.is_active(stream_id):
        return jsonify({
            'success': False,
            'error': 'Stream already being processed'
        }), 400
    
    # Start processing
    processor.start_stream_async(stream_id, rtsp_url, frame_callback)
    
    # Wait a moment for stream to initialize
    import time
    time.sleep(1)
    
    return jsonify({
        'success': True,
        'streamId': stream_id,
        'streamUrl': f'/api/ai/stream/{stream_id}'
    })

@app.route('/api/ai/stop', methods=['POST'])
def stop_detection():
    """Stop AI detection on a stream"""
    data = request.json
    stream_id = data.get('streamId')
    
    if not stream_id:
        return jsonify({
            'success': False,
            'error': 'streamId is required'
        }), 400
    
    stopped = processor.stop_stream(stream_id)
    
    if stream_id in frame_buffers:
        del frame_buffers[stream_id]
    
    return jsonify({
        'success': True,
        'stopped': stopped
    })

@app.route('/api/ai/stream/<stream_id>')
def stream_video(stream_id):
    """Stream processed video with detections"""
    if not processor.is_active(stream_id):
        return jsonify({
            'success': False,
            'error': 'Stream not active'
        }), 404
    
    return Response(
        generate_stream(stream_id),
        mimetype='multipart/x-mixed-replace; boundary=frame'
    )

@app.route('/api/ai/stats/<stream_id>', methods=['GET'])
def get_stats(stream_id):
    """Get detection statistics for a stream"""
    stats = processor.get_stats(stream_id)
    
    if not stats:
        return jsonify({
            'success': False,
            'error': 'Stream not found'
        }), 404
    
    return jsonify({
        'success': True,
        'data': stats
    })

@app.route('/api/ai/stats', methods=['GET'])
def get_all_stats():
    """Get statistics for all streams"""
    stats = processor.get_stats()
    
    return jsonify({
        'success': True,
        'count': len(stats),
        'data': stats
    })

@app.route('/api/ai/active', methods=['GET'])
def get_active_streams():
    """Get list of active AI streams"""
    active = list(processor.active_streams.keys())
    
    return jsonify({
        'success': True,
        'count': len(active),
        'streams': active
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5001))
    print(f"🤖 AI Detection Service starting on port {port}")
    print(f"📹 Ready to process RTSP streams with YOLOv8")
    app.run(host='0.0.0.0', port=port, threaded=True, debug=False)
