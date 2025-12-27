# Sample Webapp - Next.js Frontend

Next.js 14 frontend application with TypeScript and React.

## Features

- Server-side rendering (SSR)
- TypeScript for type safety
- API integration with C# backend
- Responsive design
- Health check integration
- Production-ready Docker configuration

## Tech Stack

- **Framework:** Next.js 14
- **Language:** TypeScript
- **Runtime:** Node.js 20
- **Package Manager:** npm

## Development

### Prerequisites

- Node.js 20 or higher
- npm

### Install Dependencies

```bash
npm install
```

### Run Development Server

```bash
npm run dev
```

Access at: http://localhost:3000

### Build for Production

```bash
npm run build
npm start
```

## Environment Variables

Create a `.env.local` file:

```env
NEXT_PUBLIC_API_URL=http://localhost:5000
```

### Available Variables

- `NEXT_PUBLIC_API_URL` - Backend API URL (default: http://localhost:5000)

## Docker

### Build Image

```bash
docker build -t webapp:latest .
```

### Run Container

```bash
docker run -p 3000:3000 \
  -e NEXT_PUBLIC_API_URL=http://webapi:5000 \
  webapp:latest
```

## Project Structure

```
webapp/
├── src/
│   └── app/
│       ├── page.tsx          # Main page component
│       ├── layout.tsx         # Root layout
│       ├── globals.css        # Global styles
│       └── page.module.css    # Component styles
├── public/                    # Static assets
├── Dockerfile                 # Docker configuration
├── next.config.js            # Next.js configuration
├── tsconfig.json             # TypeScript configuration
└── package.json              # Dependencies
```

## API Integration

The webapp connects to the C# backend API to fetch data.

### Health Check Endpoint

```typescript
const response = await fetch(`${apiUrl}/api/health`);
const data = await response.json();

// Response format:
{
  message: string,
  timestamp: string,
  environment: string
}
```

## Deployment

### Kubernetes

Deployed using the manifests in `environments/dev/webapp-deployment.yaml`

Key configurations:
- **Replicas:** 2
- **Port:** 3000
- **Liveness/Readiness:** HTTP GET on /
- **Resources:** 128Mi-256Mi RAM, 100m-200m CPU

### Ingress

Accessible via: http://webapp.local

## Troubleshooting

### API Connection Issues

If the webapp cannot connect to the API:

1. Check `NEXT_PUBLIC_API_URL` environment variable
2. Verify API service is running
3. Check network connectivity
4. Review CORS configuration on API

### Build Errors

```bash
# Clear Next.js cache
rm -rf .next

# Clear node_modules
rm -rf node_modules package-lock.json
npm install
```

### Docker Issues

```bash
# Build without cache
docker build --no-cache -t webapp:latest .

# Check container logs
docker logs <container-id>
```

## Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm start` - Start production server
- `npm run lint` - Run ESLint

## Performance

The application uses:
- **Standalone output** for minimal Docker image size
- **Automatic static optimization** for fast page loads
- **Code splitting** for efficient bundle sizes
- **Production builds** with minification and optimization
