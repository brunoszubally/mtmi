FROM nginx:alpine

# Copy static files to nginx
COPY frontend/index.html frontend/script.js frontend/style.css frontend/logo.png /usr/share/nginx/html/
COPY frontend/admin/ /usr/share/nginx/html/admin/

# Copy custom nginx config for routing
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"] 