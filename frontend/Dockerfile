FROM node:18-slim

WORKDIR /app

COPY frontend/ /app/frontend/
COPY frontend/server.js /app/
COPY frontend/package*.json /app/

RUN npm install

EXPOSE 8080

CMD ["node", "server.js"] 