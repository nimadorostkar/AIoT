FROM node:20-alpine

WORKDIR /usr/src/app

COPY package.json package-lock.json* ./
RUN npm install || true

COPY . .

EXPOSE 5173

CMD ["sh","-c","npm run dev -- --host 0.0.0.0 --port 5173"]

