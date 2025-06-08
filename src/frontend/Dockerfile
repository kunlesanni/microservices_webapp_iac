# # Multi-stage build for optimized production image
# FROM node:20.19 as builder

# WORKDIR /app

# # Copy package files
# COPY package.json ./

# # Install dependencies
# RUN yarn install

# # Copy source code
# COPY . .

# # Build the application with Vite
# RUN yarn build

# # Production stage
# FROM nginx:alpine

# # Copy built app to nginx (Vite outputs to 'build' directory)
# COPY --from=builder /app/build /usr/share/nginx/html

# # Copy nginx configuration
# COPY nginx.conf /etc/nginx/conf.d/default.conf

# # Health check
# HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
#     CMD wget --no-verbose --tries=1 --spider http://localhost:80/ || exit 1

# EXPOSE 80

# CMD ["nginx", "-g", "daemon off;"]


# Stage 1: Build the React app using Yarn
FROM node:20-alpine AS build

# Install system dependencies for native modules (if needed)
RUN apk add --no-cache libc6-compat python3 make g++

# Set working directory
WORKDIR /app

# Copy package files and install dependencies using Yarn
COPY package.json yarn.lock ./
RUN yarn install

# Copy the rest of the application and build it
COPY . .
RUN yarn build

# Stage 2: Serve the built app using Nginx
FROM nginx:alpine AS production

# Copy built static files from the build stage
COPY --from=build /app/build /usr/share/nginx/html

# Expose default web port
EXPOSE 80

# Start nginx server
CMD ["nginx", "-g", "daemon off;"]