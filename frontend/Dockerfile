FROM node:18-slim

WORKDIR /app

COPY frontend/ /app/

RUN npm install

EXPOSE 8080

CMD ["node", "server.js"] 