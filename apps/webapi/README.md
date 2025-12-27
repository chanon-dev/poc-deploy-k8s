# Sample WebAPI - C# ASP.NET Core Backend

ASP.NET Core 8.0 Web API backend service.

## Features

- Minimal API architecture
- Swagger/OpenAPI documentation
- CORS support for frontend
- Health check endpoint
- Production-ready Docker configuration
- Lightweight and fast

## Tech Stack

- **Framework:** ASP.NET Core 8.0
- **Language:** C#
- **Runtime:** .NET 8 SDK/Runtime

## Development

### Prerequisites

- .NET 8 SDK

### Install .NET 8

```bash
# macOS (Homebrew)
brew install dotnet@8

# Or download from:
# https://dotnet.microsoft.com/download/dotnet/8.0
```

### Restore Dependencies

```bash
dotnet restore
```

### Run Development Server

```bash
dotnet run
```

Access at: http://localhost:5000

### Run with Watch Mode

```bash
dotnet watch run
```

Auto-restarts on file changes.

## API Endpoints

### Health Check

```bash
GET /api/health
```

Response:
```json
{
  "message": "API is running successfully!",
  "timestamp": "2025-12-26T10:30:00.000Z",
  "environment": "Production",
  "version": "1.0.0"
}
```

### Sample Data

```bash
GET /api/data
```

Response:
```json
{
  "items": [
    {
      "id": 1,
      "name": "Sample Item 1",
      "description": "This is a sample item"
    }
  ],
  "count": 3,
  "timestamp": "2025-12-26T10:30:00.000Z"
}
```

### Root

```bash
GET /
```

Returns API information and available endpoints.

### Swagger Documentation

Access interactive API documentation at:

http://localhost:5000/swagger

## Environment Variables

### Development

Set in `appsettings.Development.json`:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug"
    }
  }
}
```

### Production

Set environment variables:

- `ASPNETCORE_ENVIRONMENT` - Environment name (Production/Development)
- `ASPNETCORE_URLS` - Listening URLs (default: http://+:5000)

## Docker

### Build Image

```bash
docker build -t webapi:latest .
```

### Run Container

```bash
docker run -p 5000:5000 webapi:latest
```

## Project Structure

```
webapi/
├── Program.cs                 # Main application entry point
├── appsettings.json          # Production configuration
├── appsettings.Development.json  # Development configuration
├── webapi.csproj             # Project file
├── Dockerfile                # Docker configuration
└── .gitignore               # Git ignore rules
```

## CORS Configuration

The API is configured to allow requests from:

- http://localhost:3000 (local development)
- http://webapp.local (Kubernetes deployment)
- https://webapp.local (HTTPS)

To add more origins, edit `Program.cs`:

```csharp
policy.WithOrigins(
    "http://localhost:3000",
    "http://webapp.local",
    "https://webapp.local",
    "http://your-domain.com"  // Add here
)
```

## Deployment

### Kubernetes

Deployed using the manifests in `environments/dev/webapi-deployment.yaml`

Key configurations:
- **Replicas:** 2
- **Port:** 5000
- **Liveness/Readiness:** HTTP GET on /api/health
- **Resources:** 128Mi-256Mi RAM, 100m-200m CPU

### Ingress

Accessible via: http://api.local

## Troubleshooting

### Port Already in Use

```bash
# Find process using port 5000
lsof -i :5000

# Kill the process
kill -9 <PID>

# Or use a different port
dotnet run --urls "http://localhost:5001"
```

### CORS Errors

If frontend shows CORS errors:

1. Check frontend URL is in allowed origins
2. Verify CORS middleware is configured correctly
3. Check browser console for specific error
4. Ensure preflight requests are handled

### Build Errors

```bash
# Clean and rebuild
dotnet clean
dotnet build

# Restore packages
dotnet restore --force
```

### Docker Issues

```bash
# Build without cache
docker build --no-cache -t webapi:latest .

# Check container logs
docker logs <container-id>

# Access container shell
docker exec -it <container-id> /bin/bash
```

## Testing

### Using curl

```bash
# Health check
curl http://localhost:5000/api/health

# Get data
curl http://localhost:5000/api/data

# Root endpoint
curl http://localhost:5000/
```

### Using HTTPie

```bash
# Install HTTPie
brew install httpie

# Health check
http GET :5000/api/health
```

## Performance

The application uses:
- **Minimal API** for reduced overhead
- **Multi-stage Docker build** for smaller images
- **Non-root user** in container for security
- **.NET 8 AOT** ready for ahead-of-time compilation

## Security

- Runs as non-root user in Docker (UID 1001)
- CORS restricted to specific origins
- No sensitive data in logs
- HTTPS ready (configure in production)
