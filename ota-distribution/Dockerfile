# Sử dụng Node.js bản stable
FROM node:20-slim

# Tạo thư mục app
WORKDIR /app

# Copy package.json của server vào để install trước (tận dụng cache)
COPY server/package.json ./server/
WORKDIR /app/server
RUN npm install --production

# Quay lại thư mục gốc và copy toàn bộ code
WORKDIR /app
COPY server/ ./server/
COPY web/ ./web/

# Tạo thư mục uploads nếu chưa có
RUN mkdir -p server/uploads

# Chuyển vào thư mục server để chạy lệnh start
WORKDIR /app/server

# Render dùng biến PORT mặc định là 10000 hoặc bạn có thể tự set
EXPOSE 3000

# Chạy server
CMD ["node", "index.js"]
