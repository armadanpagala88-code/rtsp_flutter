import cv2
import time
import threading
from yolo_detector import TrashDetector
import json

class StreamProcessor:
    """Process RTSP stream with AI detection"""
    
    def __init__(self, config_path='config.json'):
        """Initialize stream processor"""
        with open(config_path, 'r') as f:
            self.config = json.load(f)
        
        self.detector = TrashDetector(config_path)
        self.active_streams = {}
        self.stream_stats = {}
        
    def process_stream(self, stream_id, rtsp_url, output_callback):
        """
        Process RTSP stream and call output_callback with processed frames
        
        Args:
            stream_id: Unique identifier for this stream
            rtsp_url: RTSP URL to process
            output_callback: Function to call with processed frames
        """
        print(f"Starting stream processing for {stream_id}: {rtsp_url}")
        
        # Open video capture
        cap = cv2.VideoCapture(rtsp_url)
        
        if not cap.isOpened():
            print(f"Failed to open stream: {rtsp_url}")
            return False
        
        # Set capture properties for better performance
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        
        # Get stream properties
        fps = self.config['streaming']['fps']
        frame_delay = 1.0 / fps
        
        # Initialize stats
        self.stream_stats[stream_id] = {
            'frames_processed': 0,
            'detections': {
                'container': 0,
                'sampah_overload': 0,
                'sampah_berserakan': 0
            },
            'last_update': time.time()
        }
        
        self.active_streams[stream_id] = True
        
        try:
            while self.active_streams.get(stream_id, False):
                start_time = time.time()
                
                # Read frame
                ret, frame = cap.read()
                if not ret:
                    print(f"Failed to read frame from {stream_id}")
                    time.sleep(0.1)
                    continue
                
                # Resize if needed
                max_width = self.config['streaming']['max_width']
                max_height = self.config['streaming']['max_height']
                h, w = frame.shape[:2]
                
                if w > max_width or h > max_height:
                    scale = min(max_width / w, max_height / h)
                    new_w = int(w * scale)
                    new_h = int(h * scale)
                    frame = cv2.resize(frame, (new_w, new_h))
                
                # Process frame with YOLO
                processed_frame, detection_stats = self.detector.process_frame(frame)
                
                if processed_frame is not None:
                    # Update stats
                    self.stream_stats[stream_id]['frames_processed'] += 1
                    for key in detection_stats:
                        if key != 'total_detections':
                            self.stream_stats[stream_id]['detections'][key] += detection_stats[key]
                    self.stream_stats[stream_id]['last_update'] = time.time()
                    
                    # Call output callback with processed frame
                    output_callback(stream_id, processed_frame, detection_stats)
                
                # Control frame rate
                elapsed = time.time() - start_time
                sleep_time = max(0, frame_delay - elapsed)
                if sleep_time > 0:
                    time.sleep(sleep_time)
                    
        except Exception as e:
            print(f"Error processing stream {stream_id}: {e}")
        finally:
            cap.release()
            if stream_id in self.active_streams:
                del self.active_streams[stream_id]
            print(f"Stream processing stopped for {stream_id}")
        
        return True
    
    def start_stream_async(self, stream_id, rtsp_url, output_callback):
        """Start stream processing in a separate thread"""
        thread = threading.Thread(
            target=self.process_stream,
            args=(stream_id, rtsp_url, output_callback),
            daemon=True
        )
        thread.start()
        return thread
    
    def stop_stream(self, stream_id):
        """Stop processing a stream"""
        if stream_id in self.active_streams:
            self.active_streams[stream_id] = False
            if stream_id in self.stream_stats:
                del self.stream_stats[stream_id]
            return True
        return False
    
    def get_stats(self, stream_id=None):
        """Get detection statistics"""
        if stream_id:
            return self.stream_stats.get(stream_id, {})
        return self.stream_stats
    
    def is_active(self, stream_id):
        """Check if stream is active"""
        return self.active_streams.get(stream_id, False)
