# Use ultralytics base image which already has YOLOv8 and dependencies
FROM ultralytics/ultralytics:latest-cpu

WORKDIR /app

# Install Flask and additional requirements
COPY requirements.txt .
RUN pip install --no-cache-dir flask flask-cors

# Copy application code
COPY . .

# Expose port
EXPOSE 5000

# Start the application
CMD ["python", "ai_server.py"]
