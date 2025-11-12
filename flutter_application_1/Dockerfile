# Flutter App Dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-11-jdk \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /flutter
ENV PATH="/flutter/bin:${PATH}"

# Enable Flutter web and accept licenses
RUN flutter config --enable-web && \
    flutter doctor --android-licenses || true

# Set working directory
WORKDIR /app

# Copy pubspec files
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy source code
COPY . ./

# Build the app
RUN flutter build web --release --web-renderer html

# Install nginx
RUN apt-get update && apt-get install -y nginx && rm -rf /var/lib/apt/lists/*

# Copy nginx config if provided, otherwise create a default one
RUN if [ -f nginx.conf ]; then \
      cp nginx.conf /etc/nginx/sites-available/default ; \
    else \
      echo 'server { listen 80; root /var/www/html; index index.html; location / { try_files \$uri \$uri/ /index.html; } }' > /etc/nginx/sites-available/default ; \
    fi

# Copy built app to nginx directory
RUN cp -r build/web/. /var/www/html/

# Create non-root user
RUN useradd --create-home --shell /bin/bash app && \
    chown -R app:app /var/www/html

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]

