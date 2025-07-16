FROM node:18-slim

WORKDIR /app

COPY frontend/ /app/frontend/
COPY server.js /app/
COPY package*.json /app/

RUN npm install

EXPOSE 8080

CMD ["node", "server.js"] 