FROM python:3.9-alpine

WORKDIR /app

# Copy static files
COPY . /app/

# Expose port
EXPOSE 8080

# Start simple HTTP server
CMD ["python", "-m", "http.server", "8080"] 