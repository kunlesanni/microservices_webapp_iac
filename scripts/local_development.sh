
# ================================
# scripts/local_development.sh
# Local development setup script
# ================================

#!/bin/bash
set -e

echo "🛠️ Setting up local development environment for Python React Cloud Native App..."

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install it first."
    echo "Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install it first."
    echo "Visit: https://docs.docker.com/compose/install/"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "❌ Docker daemon is not running. Please start Docker first."
    exit 1
fi

echo "✅ Prerequisites check passed!"

# Create Docker Compose file for local development
echo "📝 Creating docker-compose.yml for local development..."

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: pyreact-postgres
    environment:
      POSTGRES_DB: pyreact_dev
      POSTGRES_USER: pgadmin
      POSTGRES_PASSWORD: password
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8"
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init-db.sql:/docker-entrypoint-initdb.d/init-db.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U pgadmin -d pyreact_dev"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - app-network

  redis:
    image: redis:7-alpine
    container_name: pyreact-redis
    ports:
      - "6379:6379"
    command: redis-server --requirepass password --appendonly yes
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - app-network

  backend:
    build: 
      context: ./src/backend
      dockerfile: Dockerfile
    container_name: pyreact-backend
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://pgadmin:password@postgres:5432/pyreact_dev
      - REDIS_URL=redis://:password@redis:6379/0
      - ENVIRONMENT=development
      - CORS_ORIGINS=http://localhost:3000,http://localhost:3001
    volumes:
      - ./src/backend:/app
      - backend_cache:/app/__pycache__
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - app-network
    restart: unless-stopped

  frontend:
    build: 
      context: ./src/frontend
      dockerfile: Dockerfile.dev
    container_name: pyreact-frontend
    ports:
      - "3000:3000"
    environment:
      - REACT_APP_API_URL=http://localhost:8000/api
      - REACT_APP_ENVIRONMENT=development
      - CHOKIDAR_USEPOLLING=true
    volumes:
      - ./src/frontend:/app
      - /app/node_modules
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - app-network
    restart: unless-stopped

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  backend_cache:
    driver: local

networks:
  app-network:
    driver: bridge
EOF

# Create database initialization script
echo "🗄️ Creating database initialization script..."
mkdir -p scripts

cat > scripts/init-db.sql << 'EOF'
-- Initialize database for local development
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create additional databases if needed
-- CREATE DATABASE pyreact_test;

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE pyreact_dev TO pgadmin;

-- You can add initial data or schema here
EOF

# Create development Dockerfile for frontend
echo "🐳 Creating development Dockerfile for frontend..."
cat > src/frontend/Dockerfile.dev << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Expose port
EXPOSE 3000

# Start development server
CMD ["npm", "start"]
EOF

# Create environment files
echo "🔧 Creating environment configuration files..."

cat > .env.local << 'EOF'
# Local Development Environment Variables
DATABASE_URL=postgresql://pgadmin:password@localhost:5432/pyreact_dev
REDIS_URL=redis://:password@localhost:6379/0
REACT_APP_API_URL=http://localhost:8000/api
ENVIRONMENT=development
EOF

cat > .env.example << 'EOF'
# Example Environment Variables
DATABASE_URL=postgresql://username:password@localhost:5432/database_name
REDIS_URL=redis://:password@localhost:6379/0
REACT_APP_API_URL=http://localhost:8000/api
ENVIRONMENT=development
EOF

# Create development scripts
echo "📜 Creating development utility scripts..."

cat > scripts/dev_start.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting local development environment..."
docker-compose up -d
echo "✅ Development environment started!"
echo ""
echo "🌐 Application URLs:"
echo "- Frontend: http://localhost:3000"
echo "- Backend API: http://localhost:8000"
echo "- API Documentation: http://localhost:8000/docs"
echo "- Database: localhost:5432"
echo "- Redis: localhost:6379"
echo ""
echo "📊 To view logs: docker-compose logs -f"
echo "🛑 To stop: docker-compose down"
EOF

cat > scripts/dev_stop.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping local development environment..."
docker-compose down
echo "✅ Development environment stopped!"
EOF

cat > scripts/dev_logs.sh << 'EOF'
#!/bin/bash
echo "📊 Showing development environment logs..."
docker-compose logs -f
EOF

cat > scripts/dev_reset.sh << 'EOF'
#!/bin/bash
echo "🔄 Resetting local development environment..."
echo "This will remove all containers and volumes. Continue? (y/N)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    docker-compose down -v
    docker-compose up -d --build
    echo "✅ Development environment reset complete!"
else
    echo "❌ Reset cancelled."
fi
EOF

# Make scripts executable
chmod +x scripts/dev_*.sh

echo ""
echo "✅ Local development environment setup complete!"
echo ""
echo "🚀 Quick start commands:"
echo "  ./scripts/dev_start.sh    # Start all services"
echo "  ./scripts/dev_stop.sh     # Stop all services"
echo "  ./scripts/dev_logs.sh     # View logs"
echo "  ./scripts/dev_reset.sh    # Reset everything"
echo ""
echo "🌐 Once started, access:"
echo "  Frontend: http://localhost:3000"
echo "  Backend: http://localhost:8000"
echo "  API Docs: http://localhost:8000/docs"
echo ""
echo "💡 For manual control:"
echo "  docker-compose up -d      # Start services"
echo "  docker-compose down       # Stop services"
echo "  docker-compose logs -f    # Follow logs"
