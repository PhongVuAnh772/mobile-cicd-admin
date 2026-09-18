# 🚀 Enterprise Mobile OTA & App Distribution Suite

Hệ thống phân phối ứng dụng Over-The-Air (OTA) và Web Portal tự lưu trữ (Self-Hosted), hỗ trợ:
- **Đa môi trường**: `DEV` (Debug), `BETA` / `STAGING`, `PROD` (Production).
- **Đa nền tảng**: Cài đặt trực tiếp iOS `.ipa` qua Safari (giao thức `itms-services`), tải trực tiếp Android `.apk` / `.aab`.
- **Ghi chú & Tác giả**: Hiển thị nổi bật ghi chú bản vá (ví dụ: `Gửi bản dev cho @TE_HauTV`), tác giả, nhánh Git, phiên bản.
- **Tích hợp sâu**: Fastlane lanes cho iOS & Android, và script CLI `upload-build.sh` tiện dụng.
- **Cập nhật nóng (Hotfix)**: Đẩy bản vá JS Bundle trong 30 giây qua AWS S3 không cần duyệt Store.

---

## 📂 Cấu trúc Thư mục

```bash
ota-distribution/
├── .env                      # File cấu hình biến môi trường (PORT, BASE_URL, AWS S3)
├── .env.example              # Mẫu cấu hình môi trường
├── Dockerfile                # Đóng gói container chạy server Node.js
├── docker-compose.yml        # Chạy nhanh trên Docker / VPS
├── deploy.sh                 # Build Docker AMD64 & trigger Deploy trên Render
├── render.yaml               # Blueprint deploy 1-click lên Render.com
│
├── server/                   # Backend Node.js / Express phục vụ OTA API & Web Portal
│   ├── index.js              # Xử lý upload .ipa, .apk, .aab, sinh plist & QR code
│   ├── package.json          # Dependencies (express, multer, plist, qrcode, @aws-sdk)
│   ├── db.json               # Lưu trữ metadata các bản build (Dev/Beta/Prod)
│   └── uploads/              # Lưu file cài đặt cục bộ (nếu không dùng S3)
│
├── web/                      # Giao diện Web Portal
│   └── public/
│       ├── index.html        # 🌟 Dashboard chính (Tabs DEV/BETA/PROD, lọc iOS/Android, QR modal)
│       └── install.html      # 📲 Trang landing page khi quét QR trên điện thoại
│
├── app-distribution-web/     # 🌐 Web Store tĩnh S3 (Host trên AWS S3 Static Website)
│   ├── index.html            # Giao diện dạng Tree-View (Prod/Staging/Dev)
│   ├── builds.json           # Metadata bản build trên S3
│   └── app.js & styles.css
│
├── scripts/                  # 🐍 Scripts tự động hóa
│   ├── upload-build.sh       # 🚀 CLI upload file build kèm -m="...", --env, --author
│   ├── deploy-ota-s3.py      # Đóng gói JS Bundle OTA hotfix lên S3 (< 30s)
│   ├── deploy-aws-s3.py      # Đẩy APK/IPA lên S3 theo quy tắc Branch
│   └── deploy-aws-s3.sh      # Bash script deploy S3 qua AWS CLI
│
└── client/                   # 📱 Client SDK
    └── otaUpdateService.ts   # React Native service tự động tải bản vá OTA khi mở app
```

---

## 🛠️ Hướng dẫn Sử dụng cho Dự án React Native

### 1. Cú pháp Makefile (`configs/Makefile` hoặc `ota-distribution/Makefile`)

Trong dự án React Native, bạn có thể chạy trực tiếp:

```bash
# Gửi bản build DEV cho tester kèm ghi chú
make distributed-ios-dev -m="Gửi bản dev cho @TE_HauTV"
make distributed-android-dev -m="Gửi bản dev cho @TE_HauTV"

# Gửi bản build STAGING / BETA
make distributed-ios-beta -m="Bản beta kiểm thử luồng thanh toán"
make distributed-android-beta -m="Bản beta kiểm thử luồng thanh toán"

# Gửi bản build PRODUCTION lên OTA Portal
make distributed-ios-prod -m="Release v1.2.0 chính thức"
make distributed-android-prod -m="Release v1.2.0 chính thức"

# ⚡ Đẩy bản vá nóng JS Bundle (AWS S3 OTA) trong 30 giây không cần duyệt Store
make ota-hotfix -m="Hotfix sửa lỗi màn hình ví trong 30s"

# Đóng gói và upload Google Play Console
make appbundle
make internal
```

### 2. Đẩy nhanh bằng Script CLI (`upload-build.sh`)

Bạn có thể đẩy trực tiếp file build (`.ipa`, `.apk`, `.aab`) từ terminal hoặc CI/CD pipeline:

```bash
# Đẩy bản DEV cho tester kèm ghi chú
./ota-distribution/scripts/upload-build.sh \
  --file "android/app/build/outputs/apk/release/app-release.apk" \
  --env "dev" \
  --flavor "dev" \
  -m "Gửi bản dev cho @TE_HauTV" \
  --author "@TE_HauTV" \
  --branch "feature/login"
```

### 3. Tích hợp Fastlane

Các lane sau đã được cấu hình sẵn trong `configs/android/fastlane/Fastfile` và `configs/ios/fastlane/Fastfile`:
- **Android**: `fastlane upload` tự động tìm `.apk` và gọi API `/api/ota/upload`.
- **iOS**: `fastlane app_distribution` tự động tìm `.ipa` (hoặc build qua `gym`) và gọi API `/api/ota/upload`.
- **Google Play**: `fastlane upload_internal` tự động đẩy `.aab` lên Google Play Internal Testing Track qua `GPLAY_SERVICE_ACCOUNT_JSON`.

---

## 🌐 Giao diện Web Portal (`/`)

Dashboard hỗ trợ đầy đủ các tab phân loại môi trường:
1. 🌟 **Tất cả (All Builds)**: Danh sách toàn bộ các bản build đã phát hành.
2. 🛠️ **DEV / DEBUG**: Bản build dev phục vụ dev/test nội bộ nhanh (`flavor=dev`).
3. 🧪 **STAGING / BETA**: Bản build beta ổn định cho QA/Tester (`flavor=beta`).
4. 👑 **PRODUCTION**: Bản build release chính thức (`flavor=pro`).
5. **Bộ lọc Nền tảng**: Lọc riêng ` iOS (.ipa)` hoặc `🤖 Android (.apk / .aab)`.
6. **Mỗi thẻ bản build hiển thị**:
   - Tên App, Version, Build Number, Flavor, Platform.
   - Badge môi trường nổi bật (`DEV`, `BETA`, `PROD`).
   - Khung trích dẫn ghi chú bản vá: `💬 "Gửi bản dev cho @TE_HauTV"`.
   - Tác giả (`👤 @TE_HauTV`) và Nhánh Git (`🌿 feature/login`).
   - Nút **"Cài đặt trực tiếp"**, **"Quét mã QR"** (hiển thị popup mã QR cho camera điện thoại), và **"Sao chép link"**.

---

## 🚀 Khởi động Server Cục bộ

```bash
cd ota-distribution/server
npm install
npm start
```
Mở trình duyệt tại: `http://localhost:3000`.
