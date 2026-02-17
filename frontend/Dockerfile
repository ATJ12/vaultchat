# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Enable web
RUN flutter config --enable-web

# Copy files and get dependencies
COPY pubspec.yaml .
RUN flutter pub get

# Copy the rest and build
COPY . .
RUN flutter build web --release --no-tree-shake-icons

# Stage 2: Serve
FROM nginx:stable-alpine

# Copy the build artifacts from stage 1
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose port 80
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
