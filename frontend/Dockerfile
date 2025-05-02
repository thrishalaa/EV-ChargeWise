# Use official Flutter image
FROM cirrusci/flutter:stable

# Enable web
RUN flutter config --enable-web

# Set working directory
WORKDIR /app

# Copy dependency files first for caching
COPY pubspec.* ./
RUN flutter pub get

# Copy everything else
COPY . .

# Build Flutter web
RUN flutter build web

# Use simple web server to serve files
FROM nginx:alpine
COPY --from=0 /app/build/web /usr/share/nginx/html

# Expose port
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
