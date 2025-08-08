FROM nginx:alpine

# Copy static files to nginx
COPY *.html *.js *.css *.png /usr/share/nginx/html/
COPY admin/ /usr/share/nginx/html/admin/

# Copy custom nginx config for routing
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"] 