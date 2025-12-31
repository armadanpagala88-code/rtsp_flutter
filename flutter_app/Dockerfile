FROM debian:latest AS build-env

# Install Flutter dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Clone Flutter SDK
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter

# Set Flutter path
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Run Flutter doctor
RUN flutter doctor -v

# Set Flutter channel to stable
RUN flutter channel stable
RUN flutter upgrade

# Set working directory
WORKDIR /app

# Copy Flutter app
COPY . .

# Get dependencies
RUN flutter pub get

# Build web app
RUN flutter build web --release

# Production stage with Nginx
FROM nginx:alpine

# Copy built web app
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
