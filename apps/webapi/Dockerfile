# Multi-stage Dockerfile for .NET 8 WebAPI
# Production-ready with security hardening

# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:8.0.12-bookworm-slim AS build

# Metadata labels
LABEL org.opencontainers.image.title="WebAPI" \
      org.opencontainers.image.description=".NET 8 Web API" \
      org.opencontainers.image.vendor="Platform Team" \
      org.opencontainers.image.version="1.0.0" \
      maintainer="platform-team@example.com"

WORKDIR /src

# Copy csproj and restore dependencies (cached layer)
COPY ["webapi.csproj", "./"]
RUN dotnet restore "webapi.csproj" \
    --runtime linux-x64 \
    --no-cache

# Copy everything else and build
COPY . .
RUN dotnet build "webapi.csproj" \
    -c Release \
    -o /app/build \
    --no-restore \
    /p:TreatWarningsAsErrors=true

# Stage 2: Publish
FROM build AS publish
RUN dotnet publish "webapi.csproj" \
    -c Release \
    -o /app/publish \
    --no-build \
    --no-restore \
    /p:UseAppHost=false \
    /p:PublishTrimmed=false \
    /p:PublishSingleFile=false

# Stage 3: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0.12-bookworm-slim AS final

# Metadata
LABEL org.opencontainers.image.title="WebAPI Runtime" \
      org.opencontainers.image.description=".NET 8 Web API Runtime"

WORKDIR /app

# Security: Create non-root user with specific UID matching Kubernetes securityContext
RUN groupadd -r -g 1000 dotnetuser && \
    useradd -r -u 1000 -g dotnetuser -m -s /sbin/nologin dotnetuser && \
    chown -R dotnetuser:dotnetuser /app

# Copy published app with proper ownership
COPY --from=publish --chown=dotnetuser:dotnetuser /app/publish .

# Security: Switch to non-root user
USER dotnetuser

# Expose port
EXPOSE 5000

# Environment variables
ENV ASPNETCORE_URLS=http://+:5000 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Entrypoint
ENTRYPOINT ["dotnet", "webapi.dll"]
