# Personalized AI Feed - Deployment Guide

## Overview

This guide covers deploying the Personalized AI Feed application, including both the FastAPI backend and Flutter frontend.

## Prerequisites

- Docker and Docker Compose
- PostgreSQL 15+
- Redis 7+
- Python 3.11+
- Flutter 3.16+
- Required API keys (see Environment Variables section)

## Environment Variables

Create a `.env` file in the project root with the following variables:

```bash
# Database Configuration
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/personalized_ai_feed

# LLM API Keys
GROQ_API_KEY=your_groq_api_key_here
HF_API_KEY=your_huggingface_api_key_here

# OAuth Credentials
GMAIL_CLIENT_ID=your_gmail_client_id
GMAIL_CLIENT_SECRET=your_gmail_client_secret
INSTAGRAM_CLIENT_ID=your_instagram_client_id
INSTAGRAM_CLIENT_SECRET=your_instagram_client_secret
GOOGLE_CALENDAR_CLIENT_ID=your_google_calendar_client_id
GOOGLE_CALENDAR_CLIENT_SECRET=your_google_calendar_client_secret

# News APIs
NEWSAPI_KEY=your_newsapi_key
GNEWS_API_KEY=your_gnews_api_key

# Social Media APIs
REDDIT_CLIENT_ID=your_reddit_client_id
REDDIT_CLIENT_SECRET=your_reddit_client_secret
TELEGRAM_BOT_TOKEN=your_telegram_bot_token

# Security
ENCRYPTION_KEY=your_32_character_encryption_key
JWT_SECRET=your_jwt_secret_key

# Redis
REDIS_URL=redis://localhost:6379/0
```

## Quick Start with Docker Compose

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd personalized-ai-feed
   ```

2. **Create environment file:**
   ```bash
   cp flutter_backend/env.example .env
   # Edit .env with your actual values
   ```

3. **Start the services:**
   ```bash
   docker-compose up -d
   ```

4. **Initialize the database:**
   ```bash
   docker-compose exec backend python -c "from storage.db import init_db; init_db()"
   ```

5. **Access the application:**
   - Frontend: http://localhost
   - Backend API: http://localhost:8000
   - API Documentation: http://localhost:8000/docs

## Manual Deployment

### Backend Deployment

1. **Install Python dependencies:**
   ```bash
   cd flutter_backend
   pip install -r requirements.txt
   ```

2. **Set up the database:**
   ```bash
   # Create PostgreSQL database
   createdb personalized_ai_feed
   
   # Initialize tables
   python -c "from storage.db import init_db; init_db()"
   ```

3. **Run the backend:**
   ```bash
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```

### Frontend Deployment

1. **Install Flutter dependencies:**
   ```bash
   cd flutter_application_1
   flutter pub get
   ```

2. **Build for web:**
   ```bash
   flutter build web --release
   ```

3. **Serve with nginx:**
   ```bash
   # Copy built files to nginx directory
   sudo cp -r build/web/* /var/www/html/
   
   # Configure nginx (see nginx.conf)
   sudo systemctl restart nginx
   ```

## Production Deployment

### Using Docker Swarm

1. **Initialize swarm:**
   ```bash
   docker swarm init
   ```

2. **Deploy stack:**
   ```bash
   docker stack deploy -c docker-compose.yml personalized-ai
   ```

### Using Kubernetes

1. **Create namespace:**
   ```bash
   kubectl create namespace personalized-ai
   ```

2. **Apply configurations:**
   ```bash
   kubectl apply -f k8s/ -n personalized-ai
   ```

3. **Check deployment:**
   ```bash
   kubectl get pods -n personalized-ai
   ```

## Monitoring Setup

### Prometheus + Grafana

1. **Start monitoring stack:**
   ```bash
   docker-compose -f docker-compose.monitoring.yml up -d
   ```

2. **Access monitoring:**
   - Prometheus: http://localhost:9090
   - Grafana: http://localhost:3000 (admin/admin)

### Custom Metrics

The backend exposes metrics at `/metrics` endpoint for Prometheus scraping.

## Security Considerations

### SSL/TLS Setup

1. **Generate SSL certificates:**
   ```bash
   # Using Let's Encrypt
   certbot certonly --standalone -d yourdomain.com
   ```

2. **Configure nginx with SSL:**
   ```nginx
   server {
       listen 443 ssl;
       ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
       ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
       # ... rest of configuration
   }
   ```

### Environment Security

- Use strong, unique passwords for all services
- Rotate API keys regularly
- Enable firewall rules
- Use secrets management for production

## Backup and Recovery

### Database Backup

```bash
# Create backup
pg_dump personalized_ai_feed > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore backup
psql personalized_ai_feed < backup_file.sql
```

### Application Data Backup

```bash
# Backup vector store and uploaded files
tar -czf app_data_backup_$(date +%Y%m%d_%H%M%S).tar.gz /app/data/
```

## Scaling

### Horizontal Scaling

1. **Backend scaling:**
   ```bash
   docker-compose up -d --scale backend=3
   ```

2. **Load balancer configuration:**
   ```nginx
   upstream backend {
       server backend1:8000;
       server backend2:8000;
       server backend3:8000;
   }
   ```

### Database Scaling

- Use read replicas for read-heavy workloads
- Consider connection pooling (PgBouncer)
- Implement database sharding for large datasets

## Troubleshooting

### Common Issues

1. **Database connection errors:**
   - Check DATABASE_URL format
   - Verify PostgreSQL is running
   - Check network connectivity

2. **API key errors:**
   - Verify all required environment variables are set
   - Check API key validity and permissions

3. **Memory issues:**
   - Monitor memory usage with `docker stats`
   - Adjust container memory limits
   - Optimize vector store operations

### Logs

```bash
# View application logs
docker-compose logs -f backend
docker-compose logs -f frontend

# View specific service logs
docker-compose logs -f postgres
docker-compose logs -f redis
```

## Performance Optimization

### Backend Optimization

- Enable database connection pooling
- Use Redis for caching
- Implement request rate limiting
- Optimize vector search operations

### Frontend Optimization

- Enable gzip compression
- Use CDN for static assets
- Implement service worker for offline support
- Optimize bundle size

## Maintenance

### Regular Tasks

- Monitor disk space and clean up old logs
- Update dependencies regularly
- Backup database and application data
- Review and rotate API keys
- Monitor performance metrics

### Updates

1. **Backend updates:**
   ```bash
   docker-compose pull backend
   docker-compose up -d backend
   ```

2. **Frontend updates:**
   ```bash
   docker-compose pull frontend
   docker-compose up -d frontend
   ```

## Support

For issues and questions:
- Check the logs first
- Review this documentation
- Create an issue in the repository
- Contact the development team


