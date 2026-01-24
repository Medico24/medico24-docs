# Deployment Guide

## Overview

This guide covers deployment strategies for all components of the Medico24 platform.

## Prerequisites

- Docker and Docker Compose
- Cloud infrastructure (AWS, GCP, or Azure)
- Domain name and SSL certificates
- Git repository access

## Environment Setup

### Production Environment Variables

```bash
# Backend Environment
DATABASE_URL=postgresql://user:pass@db:5432/medico24
REDIS_URL=redis://redis:6379
JWT_SECRET=your-secure-secret
GOOGLE_MAPS_API_KEY=your-google-maps-key
WEATHER_API_KEY=your-weather-api-key
AIR_QUALITY_API_KEY=your-air-quality-key

# Firebase Configuration
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY=your-private-key
FIREBASE_CLIENT_EMAIL=your-service-account-email
```

### Mobile App Configuration

```yaml
# pubspec.yaml
version: 1.0.0+1
```

Update version numbers and build configurations for production releases.

## Backend Deployment

### Using Docker

1. **Build the container:**
   ```bash
   docker build -t medico24-backend .
   ```

2. **Deploy with Docker Compose:**
   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

### Cloud Deployment

#### AWS Deployment

1. **ECS Setup:**
   - Create ECS cluster
   - Configure task definitions
   - Set up load balancer

2. **RDS Configuration:**
   - PostgreSQL instance
   - Redis ElastiCache

#### Google Cloud Deployment

1. **Cloud Run Setup:**
   - Deploy containerized application
   - Configure Cloud SQL
   - Set up Redis Memorystore

## Mobile App Deployment

### iOS Deployment

1. **Build for iOS:**
   ```bash
   flutter build ios --release
   ```

2. **App Store Distribution:**
   - Archive in Xcode
   - Upload to App Store Connect
   - Submit for review

### Android Deployment

1. **Build APK/AAB:**
   ```bash
   flutter build apk --release
   flutter build appbundle --release
   ```

2. **Play Store Distribution:**
   - Upload to Google Play Console
   - Complete store listing
   - Submit for review

## Web Dashboard Deployment

### Next.js Deployment

1. **Build the application:**
   ```bash
   npm run build
   ```

2. **Deploy to Vercel:**
   ```bash
   vercel --prod
   ```

3. **Alternative: AWS S3 + CloudFront**
   ```bash
   aws s3 sync out/ s3://your-bucket --delete
   aws cloudfront create-invalidation --distribution-id YOUR_ID --paths "/*"
   ```

## ML Module Deployment

### Model Deployment

1. **Containerize models:**
   ```dockerfile
   FROM python:3.9-slim
   COPY models/ /app/models/
   COPY src/ /app/src/
   WORKDIR /app
   RUN pip install -r requirements.txt
   CMD ["python", "src/api.py"]
   ```

2. **Deploy to cloud:**
   - AWS SageMaker
   - Google AI Platform
   - Azure ML

## Monitoring and Observability

### Prometheus Configuration

Deploy monitoring stack:

```bash
cd medico24-observability
docker-compose up -d
```

### Log Management

Configure centralized logging:
- ELK Stack for log aggregation
- Structured logging format
- Log retention policies

## CI/CD Pipeline

### GitHub Actions Example

```yaml
name: Deploy Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy Backend
        run: |
          docker build -t medico24-backend .
          docker push your-registry/medico24-backend:latest
      - name: Deploy Mobile
        run: |
          flutter build apk --release
```

## Security Considerations

### SSL/TLS Setup

1. **Certificate Management:**
   - Use Let's Encrypt for free certificates
   - Configure automatic renewal

2. **Security Headers:**
   ```nginx
   add_header X-Content-Type-Options nosniff;
   add_header X-Frame-Options DENY;
   add_header X-XSS-Protection "1; mode=block";
   ```

### Environment Security

- Use secrets management (AWS Secrets Manager, Azure Key Vault)
- Implement network security groups
- Configure firewall rules

## Backup and Recovery

### Database Backups

1. **Automated backups:**
   ```bash
   pg_dump -h localhost -U user medico24 > backup.sql
   ```

2. **Backup rotation:**
   - Daily backups for 30 days
   - Weekly backups for 12 weeks
   - Monthly backups for 12 months

### Disaster Recovery

- Multi-region deployment
- Database replication
- Automated failover procedures

## Performance Optimization

### CDN Configuration

Use CDN for static assets:
- CloudFront (AWS)
- Cloud CDN (GCP)
- Azure CDN

### Caching Strategy

- Redis for application caching
- Database query optimization
- Static asset caching

## Rollback Procedures

### Blue-Green Deployment

1. **Deploy to staging environment**
2. **Run health checks**
3. **Switch traffic to new version**
4. **Monitor for issues**
5. **Rollback if needed**

### Database Migrations

1. **Backup before migration**
2. **Test migrations on staging**
3. **Run migrations with rollback plan**

## Troubleshooting

### Common Issues

1. **Database Connection Issues:**
   - Check connection strings
   - Verify network connectivity
   - Review firewall rules

2. **Mobile App Crashes:**
   - Review crash logs
   - Check API compatibility
   - Verify certificate validity

3. **Performance Issues:**
   - Monitor resource usage
   - Check database queries
   - Review caching effectiveness

### Health Checks

Implement health check endpoints:
```python
@app.get("/health")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.now()}
```

## Support and Maintenance

### Monitoring Alerts

Set up alerts for:
- API response times
- Error rates
- Resource utilization
- Database performance

### Maintenance Windows

- Schedule regular maintenance
- Communicate downtime to users
- Perform updates during low-traffic periods

## Resources

- [AWS Deployment Guide](https://aws.amazon.com/getting-started/)
- [Flutter Deployment](https://flutter.dev/docs/deployment)
- [Next.js Deployment](https://nextjs.org/docs/deployment)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)