import cv2
import numpy as np
from ultralytics import YOLO
import json
import os

class TrashDetector:
    """YOLO-based trash detection for identifying trash bins and scattered waste"""
    
    def __init__(self, config_path='config.json'):
        """Initialize the detector with configuration"""
        with open(config_path, 'r') as f:
            self.config = json.load(f)
        
        # Load YOLO model
        model_type = self.config['model']['type']
        print(f"Loading YOLO model: {model_type}")
        self.model = YOLO(model_type)
        
        self.conf_threshold = self.config['model']['confidence_threshold']
        self.iou_threshold = self.config['model']['iou_threshold']
        
        # Class configurations
        self.classes = self.config['classes']
        
    def map_class_name(self, class_name, confidence):
        """Map COCO class names to trash-specific categories"""
        class_name_lower = class_name.lower()
        
        # Check for container/bin
        if any(keyword in class_name_lower for keyword in self.classes['container'].get('keywords', [])):
            return 'container', self.classes['container']['label']
        
        # Check for scattered trash (bottles, cups, etc)
        if any(keyword in class_name_lower for keyword in self.classes['sampah_berserakan'].get('keywords', [])):
            return 'sampah_berserakan', self.classes['sampah_berserakan']['label']
        
        # Default mapping for common trash items
        trash_items = ['bottle', 'cup', 'bowl', 'fork', 'knife', 'spoon', 
                      'banana', 'apple', 'sandwich', 'orange', 'carrot']
        if class_name_lower in trash_items:
            return 'sampah_berserakan', self.classes['sampah_berserakan']['label']
        
        return None, None
    
    def detect_overflow(self, boxes, image_height):
        """
        Detect if trash is overflowing based on detection patterns
        This is a simple heuristic - you may need to customize based on your needs
        """
        # Check if there are multiple detections clustered together
        if len(boxes) > 3:
            # Check vertical positions - items on top suggest overflow
            top_detections = sum(1 for box in boxes if box[1] < image_height * 0.3)
            if top_detections > 1:
                return True
        return False
    
    def draw_detection(self, frame, box, label, confidence, class_type):
        """Draw bounding box and label on frame"""
        x1, y1, x2, y2 = map(int, box)
        
        # Get color configuration
        color_bgr = tuple(self.classes[class_type]['color'])
        text_color = self.classes[class_type].get('text_color', [255, 255, 255])
        text_color_bgr = tuple(text_color)
        
        # Draw bounding box
        cv2.rectangle(frame, (x1, y1), (x2, y2), color_bgr, 2)
        
        # Prepare label text with confidence
        label_text = f"{label} {confidence:.2f}"
        
        # Calculate text size
        font = cv2.FONT_HERSHEY_SIMPLEX
        font_scale = 0.6
        thickness = 2
        (text_width, text_height), baseline = cv2.getTextSize(
            label_text, font, font_scale, thickness
        )
        
        # Draw background rectangle for text
        bg_y1 = max(0, y1 - text_height - 10)
        bg_y2 = y1
        cv2.rectangle(frame, (x1, bg_y1), (x1 + text_width + 10, bg_y2), color_bgr, -1)
        
        # Draw text
        text_y = y1 - 5
        cv2.putText(frame, label_text, (x1 + 5, text_y), 
                   font, font_scale, text_color_bgr, thickness)
        
        return frame
    
    def process_frame(self, frame):
        """
        Process a single frame and return frame with detections
        """
        if frame is None:
            return None, {}
        
        # Run YOLO detection
        results = self.model(frame, conf=self.conf_threshold, iou=self.iou_threshold, verbose=False)
        
        detection_stats = {
            'container': 0,
            'sampah_overload': 0,
            'sampah_berserakan': 0,
            'total_detections': 0
        }
        
        all_boxes = []
        
        # Process detections
        for result in results:
            boxes = result.boxes
            for box in boxes:
                # Get box coordinates
                x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                all_boxes.append([x1, y1, x2, y2])
                
                # Get confidence and class
                confidence = float(box.conf[0])
                class_id = int(box.cls[0])
                class_name = self.model.names[class_id]
                
                # Map to trash categories
                class_type, label = self.map_class_name(class_name, confidence)
                
                if class_type:
                    # Draw detection
                    frame = self.draw_detection(frame, [x1, y1, x2, y2], 
                                              label, confidence, class_type)
                    detection_stats[class_type] += 1
                    detection_stats['total_detections'] += 1
        
        # Check for overflow condition
        if self.detect_overflow(all_boxes, frame.shape[0]):
            detection_stats['sampah_overload'] += 1
            # Draw overflow indicator in top-right corner
            cv2.putText(frame, "⚠ OVERLOAD DETECTED", (frame.shape[1] - 300, 40),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
        
        return frame, detection_stats
