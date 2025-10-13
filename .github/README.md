# CI/CD Pipeline Documentation

This directory contains GitHub Actions workflows for the Personalized AI Feed project.

## Workflows Overview

### 1. Main CI/CD Pipeline (`ci-cd.yml`)
The primary workflow that runs on pushes to `main` and `develop` branches, and on pull requests to `main`.

**Jobs:**
- **Backend Tests**: Runs Python tests with PostgreSQL and Redis services
- **Frontend Tests**: Runs Flutter tests and builds web version
- **Security Scan**: Runs Trivy vulnerability scanner
- **Build and Push**: Builds and pushes Docker images to GitHub Container Registry
- **Deploy Staging**: Deploys to staging environment (develop branch)
- **Deploy Production**: Deploys to production environment (main branch)
- **Cleanup**: Cleans up old container images

### 2. Code Quality (`code-quality.yml`)
Ensures code quality and consistency across the project.

**Checks:**
- **Backend**: Black formatting, isort, Flake8 linting, MyPy type checking, Bandit security, Safety dependency check
- **Frontend**: Flutter analyze, format check, unused dependency detection
- **Documentation**: Validates required documentation files and links

### 3. Performance Testing (`performance-test.yml`)
Runs performance and load tests to ensure the application meets performance requirements.

**Tests:**
- **Backend Performance**: API response time tests, Locust load testing
- **Frontend Performance**: Build size analysis, bundle size checks
- **Memory Usage**: Memory consumption monitoring during imports and operations

### 4. PR Validation (`pr-validation.yml`)
Validates pull requests before they can be merged.

**Validations:**
- Semantic PR title format
- Conventional commit message format
- Sensitive file detection
- Quick syntax checks

### 5. Dependency Updates (`dependency-update.yml`)
Automatically updates dependencies and creates PRs with the changes.

**Updates:**
- Python dependencies in `requirements.txt`
- Flutter dependencies in `pubspec.lock`

## Environment Variables

### Required Secrets
Set these in your GitHub repository settings:

- `GROQ_API_KEY`: API key for Groq LLM service
- `HF_API_KEY`: API key for Hugging Face services
- `GITHUB_TOKEN`: Automatically provided by GitHub

### Environment Configuration
The workflows use different environments:
- **Test**: For running tests with test databases
- **Staging**: For staging deployments
- **Production**: For production deployments

## Docker Images

The pipeline builds and pushes two Docker images:

1. **Backend Image**: `ghcr.io/{repository}-backend:latest`
   - Based on Python 3.11-slim
   - Includes all Python dependencies
   - Runs FastAPI with Uvicorn

2. **Frontend Image**: `ghcr.io/{repository}-frontend:latest`
   - Based on Ubuntu 22.04
   - Includes Flutter SDK and built web app
   - Serves with Nginx

## Services Used

### Database Services
- **PostgreSQL 15**: For backend tests and production
- **Redis 7**: For caching and background jobs

### External Services
- **GitHub Container Registry**: For storing Docker images
- **Trivy**: For security vulnerability scanning
- **Codecov**: For code coverage reporting

## Branch Strategy

- **main**: Production branch, triggers full deployment pipeline
- **develop**: Staging branch, triggers staging deployment
- **feature/***: Feature branches, run tests and validation only

## Workflow Triggers

### Automatic Triggers
- Push to `main` or `develop` branches
- Pull requests to `main` branch
- Scheduled dependency updates (Mondays at 9 AM UTC)
- Daily performance tests (2 AM UTC)

### Manual Triggers
- Dependency update workflow can be triggered manually
- All workflows can be re-run from the GitHub Actions UI

## Monitoring and Notifications

### Success Notifications
- Production deployments show success messages
- Coverage reports are uploaded to Codecov

### Failure Handling
- Failed tests block deployment
- Security vulnerabilities block deployment
- Performance regressions are reported

## Local Development

To run the same checks locally:

```bash
# Backend quality checks
cd flutter_backend
black --check .
isort --check .
flake8 .
mypy .

# Frontend quality checks
cd flutter_application_1
flutter analyze
dart format --set-exit-if-changed .

# Run tests
cd flutter_backend
python run_tests.py

cd flutter_application_1
flutter test
```

## Troubleshooting

### Common Issues

1. **Test Failures**: Check database connectivity and environment variables
2. **Build Failures**: Verify Dockerfile syntax and dependencies
3. **Security Scan Failures**: Review and fix reported vulnerabilities
4. **Performance Test Failures**: Check for memory leaks or slow queries

### Debug Mode
To enable debug logging, set `ACTIONS_STEP_DEBUG=true` in repository secrets.

## Contributing

When adding new workflows:
1. Follow the existing naming conventions
2. Include proper error handling
3. Add appropriate documentation
4. Test workflows in a fork before submitting PRs

## Security Considerations

- All secrets are stored in GitHub repository settings
- Docker images are scanned for vulnerabilities
- Dependencies are regularly updated
- Sensitive files are blocked from PRs
- Non-root users are used in Docker containers

