# 📱 Hướng Dẫn Tích Hợp Hệ Thống Mobile CI/CD, OTA Distribution & Telegram
### Centralized Enterprise Mobile Release Pipeline

Tài liệu này cung cấp hướng dẫn đầy đủ, chi tiết từ A-Z để áp dụng hệ sinh thái **Centralized CI/CD, OTA Web Distribution Portal và Telegram Mobile Builder Card** vào bất kỳ dự án Mobile mới nào (React Native CLI, Expo Managed / Bare Workflow).

---

## 📑 Mục Lục
1. [Kiến Trúc Tổng Thể & Cơ Chế Hoạt Động](#1-kiến-trúc-tổng-thể--cơ-chế-hoạt-động)
2. [Quy Trình Triển Khai Cho Dự Án Mới (5 Giai Đoạn)](#2-quy-trình-triển-khai-cho-dự-án-mới)
   - [Giai đoạn 1: Cấu hình GitHub Repository](#giai-đoạn-1-cấu-hình-github-repository)
   - [Giai đoạn 2: Cấu hình toàn bộ Secrets (22 Secrets Chi Tiết)](#giai-đoạn-2-cấu-hình-toàn-bộ-secrets)
   - [Giai đoạn 3: Tích hợp mã nguồn vào dự án mới](#giai-đoạn-3-tích-hợp-mã-nguồn-vào-dự-án-mới)
   - [Giai đoạn 4: Thiết lập Quản trị Nhánh & Dual Approval](#giai-đoạn-4-thiết-lập-quản-trị-nhánh--dual-approval)
   - [Giai đoạn 5: Vận hành thực tế & Kiểm thử](#giai-đoạn-5-vận-hành-thực-tế--kiểm-thử)
3. [Bảng Tra Cứu Toàn Bộ 22 Secrets Chi Tiết](#3-bảng-tra-cứu-toàn-bộ-22-secrets-chi-tiết)
4. [Quy Chuẩn & Luồng Gắn Tag Phát Hành (Release Tagging Rules)](#4-quy-chuẩn--luồng-gắn-tag-phát-hành-release-tagging-rules)
5. [Sổ Tay Lệnh Hàng Ngày (Cheatsheet)](#5-sổ-tay-lệnh-hàng-ngày-cheatsheet)
6. [Xử Lý Sự Cố Thường Gặp (Troubleshooting)](#6-xử-lý-sự-cố-thường-gặp-troubleshooting)

---

## 1. Kiến Trúc Tổng Thể & Cơ Chế Hoạt Động

Hệ thống hoạt động theo mô hình **Centralized Engine (Kho Quản Trị Tập Trung)**:

```mermaid
flowchart TD
    subgraph ConsumerRepos["Các Ứng Dụng Mobile (Consumer Repos)"]
        App1["📱 App 1: RetroBox"]
        App2["📱 App 2: E-Commerce"]
        AppN["📱 App N: 100+ Mobile Apps"]
    end

    subgraph CentralAdmin["mobile-cicd-admin (Kho Quản Trị Trung Tâm)"]
        Engine["🔒 master-pipeline.yml\n+ Fastlane + DangerJS + Quality Gates"]
        Portal["🌐 OTA Web Distribution Server\n(mobile-cicd-admin.onrender.com)"]
        S3Bucket["☁️ AWS S3 Storage Bucket\n(amzn-s3-cryptovault)"]
        Bot["📢 Telegram Notification Engine\n(@ShipItCIBot)"]
    end

    App1 -->|"Gọi Reusable Workflow (15 dòng YAML)"| Engine
    App2 -->|"Gọi Reusable Workflow"| Engine
    AppN -->|"Gọi Reusable Workflow"| Engine

    Engine -->|"1. Build APK / AAB / IPA"| Portal
    Engine -->|"2. Tải bản build"| S3Bucket
    Engine -->|"3. Bắn Mobile Builder Photo Card"| Bot
```

### 3 Trụ Cột Của Hệ Thống:
1. **Central Reusable Workflow (`master-pipeline.yml`)**: Toàn bộ logic build Gradle, Fastlane, ký số Keystore/Certificates, DangerJS review nằm tập trung tại `phong-mobile/mobile-cicd-admin`. Khi nâng cấp logic, 100% các ứng dụng tự động cập nhật ngay lập tức mà không cần sửa code từng repo.
2. **OTA Distribution Portal (`mobile-cicd-admin.onrender.com`)**: Triển khai trực tiếp từ GitHub trên Render Node.js native runtime. Cung cấp Dashboard quản lý, mã QR cài đặt tức thì trên iOS (Safari `itms-services`) và Android.
3. **Telegram Mobile Builder Card (`@ShipItCIBot`)**: Tự động gửi thẻ ảnh photo card chuyên nghiệp (phân biệt rõ Android/iOS banner) với 2 nút bấm tương tác: **`[ 🌐 Link Web ]`** và **`[ 📦 Link S3 ]`**.

---

## 2. Quy Trình Triển Khai Cho Dự Án Mới

---

### Giai Đoạn 1: Cấu Hình GitHub Repository

1. **Tạo Repository mới trên GitHub**:
   - Truy cập GitHub và tạo repo mới cho ứng dụng (ví dụ: `phong-mobile/my-mobile-app`).
   - ⚠️ **Bắt buộc**: Tick chọn ô **"Add a README file"** để khởi tạo sẵn nhánh `main`. *(Nếu không có nhánh `main` ban đầu, GitHub sẽ không cho phép tạo Ruleset bảo vệ).*

2. **Cấp quyền Workflow Permissions (Bắt buộc)**:
   - Vào repo ➔ **Settings** ➔ **Actions** ➔ **General**.
   - Kéo xuống mục **Workflow permissions**:
     - Chọn: 🔘 **Read and write permissions** *(cho phép workflow tải lên Artifacts, cập nhật commit check)*.
     - Tick chọn: ☑️ **Allow GitHub Actions to create and approve pull requests**.
     - Bấm **Save**.

---

### Giai Đoạn 2: Cấu Hình Toàn Bộ Secrets

Vào **Settings** ➔ **Secrets and variables** ➔ **Actions** trên repository mới (hoặc Organization Settings nếu muốn áp dụng cho toàn bộ tổ chức).

> [!TIP]
> Bạn có thể chạy nhanh các lệnh GitHub CLI `gh secret set` được cung cấp trong [Mục 3: Bảng Tra Cứu Toàn Bộ 22 Secrets](#3-bảng-tra-cứu-toàn-bộ-22-secrets-chi-tiết) để hoàn thành việc nhập secrets chỉ trong 30 giây thay vì bấm tay trên trình duyệt.

**Thứ tự ưu tiên cấu hình:**
- **Khi làm việc nội bộ / gửi Tester (Dev/Staging)**: Chỉ cần cấu hình **Nhóm 1** (OTA & Telegram) và **Nhóm 2** (AWS S3).
- **Khi sẵn sàng phát hành Store (Production)**: Bổ sung thêm **Nhóm 3** (Google Play) và **Nhóm 4** (Apple App Store).

---

### Giai Đoạn 3: Tích Hợp Mã Nguồn Vào Dự Án Mới

#### Cách 1: Khởi Tạo Tự Động Bằng Lệnh `cicd` (Khuyên dùng - 10 giây)
Mở Terminal trên máy Mac của bạn, chuyển đến thư mục dự án mobile mới và gõ:
```bash
cd /duong/dan/toi/du-an-mobile-moi
cicd
```
Hệ thống sẽ tự động:
1. Nhận diện cấu trúc dự án (React Native CLI hoặc Expo).
2. Tạo file `.github/workflows/ci.yml`.
3. Copy toàn bộ `Makefile`, `scripts/upload-build.sh`, `scripts/notify-telegram.sh` và bộ ảnh banner chuẩn.
4. Chạy kiểm tra tự động 15 Test Cases chẩn đoán sức khỏe hệ thống.

---

#### Cách 2: Tích Hợp Thủ Công (Nếu làm trên máy mới chưa có CLI)

1. **Tạo file `.github/workflows/ci.yml`**:
   Tạo file tại đường dẫn `.github/workflows/ci.yml` với nội dung:
   ```yaml
   name: "Enterprise Mobile CI/CD"

   on:
     push:
       branches: [main, dev]
       tags: ['v*.*.*']
     pull_request:
       branches: [main, dev]
     workflow_dispatch:
       inputs:
         environment:
           description: "Môi trường deploy (staging / production)"
           required: false
           default: "staging"

   permissions:
     contents: write
     pull-requests: write
     actions: read

   jobs:
     admin-pipeline:
       uses: phong-mobile/mobile-cicd-admin/.github/workflows/master-pipeline.yml@main
       with:
         app_name: "MyMobileApp"
         environment: ${{ inputs.environment || (startsWith(github.ref, 'refs/tags/') && 'production' || 'staging') }}
       secrets: inherit
   ```

2. **Copy bộ công cụ scripts và Makefile**:
   ```bash
   # Từ kho lưu trữ mobile-cicd-admin
   cp -r /Users/phongva/Code/mobile-cicd-admin/scripts ./scripts
   cp /Users/phongva/Code/mobile-cicd-admin/configs/Makefile ./Makefile
   cp -r /Users/phongva/Code/mobile-cicd-admin/assets ./assets
   ```

3. **Tạo file cấu hình môi trường cục bộ `.env`**:
   Tạo file `.env` tại thư mục gốc dự án (file này đã được `.gitignore` bảo vệ):
   ```env
   # Telegram Configuration
   TELEGRAM_BOT_TOKEN="8986495497:AAFc7LGv1cI51u-FjRAlO-ntYXUEMrZ1DAc"
   TELEGRAM_CHAT_ID="-5477336915"
   # TELEGRAM_THREAD_ID="" # Điền nếu là forum topic

   # OTA Distribution Server
   OTA_SERVER_URL="https://mobile-cicd-admin.onrender.com"

   # AWS S3 Storage (Tự động tải lên S3 khi chạy upload cục bộ)
   AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
   AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
   AWS_S3_BUCKET="amzn-s3-cryptovault"
   AWS_REGION="ap-southeast-2"
   ```

---

### Giai Đoạn 4: Thiết Lập Quản Trị Nhánh & Dual Approval

Để đảm bảo không lập trình viên nào có thể push thẳng vào `main` hoặc tự ý release Store mà chưa qua review:

1. Chạy script thiết lập Governance từ thư mục admin:
   ```bash
   cd /Users/phongva/Code/mobile-cicd-admin
   ./setup-github-rules.sh
   ```
2. Nhập các thông tin:
   - **Organization / Owner**: `phong-mobile` (hoặc username GitHub của bạn).
   - **Repository Name**: Nhập tên repo ứng dụng mới (ví dụ: `my-mobile-app`).
   - **Xác nhận 2FA**: Gõ `CONFIRM_ADMIN`.
3. ⏱️ **Kết quả sau 15 giây**:
   - Nhánh `main` và `dev` được khóa chặt, bắt buộc phải tạo Pull Request và pass 100% CI checks.
   - Tạo sẵn 3 môi trường phát hành: `development`, `staging`, `production`.
   - Môi trường `production` được cấu hình **Dual Approval** (Bắt buộc Tech Lead hoặc Release Manager phê duyệt mới được deploy lên Google Play / App Store).

---

### Giai Đoạn 5: Vận Hành Thực Tế & Kiểm Thử

#### Luồng 1: Tự động qua Git CI/CD
1. Đẩy code lên nhánh `dev` hoặc `main`:
   ```bash
   git add .
   git commit -m "feat: initial mobile app with enterprise CI/CD"
   git push origin main
   ```
2. GitHub Actions tự động kích hoạt:
   - Chạy Lint, TypeCheck, Unit Tests.
   - Build bản Release APK/AAB hoặc IPA.
   - Tải lên AWS S3 và đăng ký vào OTA Distribution Portal.
   - Gửi thẻ Mobile Builder vào nhóm Telegram với 2 nút **`[ 🌐 Link Web ]`** và **`[ 📦 Link S3 ]`**.

#### Luồng 2: Đẩy bản build cục bộ siêu tốc (Local Fast-Track CLI)
Khi lập trình viên vừa build xong file `.apk` hoặc `.ipa` trên máy cá nhân và muốn gửi ngay cho Tester/Khách hàng:
```bash
./scripts/upload-build.sh \
  --file android/app/build/outputs/apk/release/app-release.apk \
  --name "MyMobileApp" \
  --version "1.0.0" \
  --build-num "1" \
  -m "Bản test tính năng mới cho QA"
```
Bản build sẽ được đẩy lên S3, tạo QR code trên Web Portal và gửi thông báo Telegram trong vòng chưa đầy 30 giây!

---

## 3. Bảng Tra Cứu Toàn Bộ 22 Secrets Chi Tiết

Dưới đây là bảng đặc tả chi tiết 100% toàn bộ các Secrets hỗ trợ trong hệ thống, kèm câu lệnh `gh secret set` để gán nhanh:

### Nhóm 1: OTA Distribution Portal & Telegram (Bắt buộc)
| STT | Tên Secret | Mô Tả & Cách Lấy | Giá Trị Mẫu | Lệnh Gán Nhanh CLI |
| :---: | :--- | :--- | :--- | :--- |
| 1 | `OTA_SERVER_URL` | Địa chỉ máy chủ OTA Web Portal. | `https://mobile-cicd-admin.onrender.com` | `gh secret set OTA_SERVER_URL -b "https://mobile-cicd-admin.onrender.com"` |
| 2 | `TELEGRAM_BOT_TOKEN` | Token Bot Telegram cấp quyền đăng bài. Lấy từ `@BotFather` qua lệnh `/newbot`. | `8986495497:AAFc7LGv1cI51u-FjRAlO-ntYXUEMrZ1DAc` | `gh secret set TELEGRAM_BOT_TOKEN -b "8986495497:AAFc7LGv1cI51u-FjRAlO-ntYXUEMrZ1DAc"` |
| 3 | `TELEGRAM_CHAT_ID` | ID nhóm hoặc kênh nhận thông báo build. Thêm bot `@RawDataBot` vào nhóm để xem `chat.id`. | `-5477336915` | `gh secret set TELEGRAM_CHAT_ID -b "-5477336915"` |
| 4 | `TELEGRAM_THREAD_ID` | ID Topic/Chủ đề (nếu nhóm bật Topics/Forums). Chuột phải vào topic ➔ Copy link ➔ lấy số cuối. | `1234` | `gh secret set TELEGRAM_THREAD_ID -b "1234"` |

### Nhóm 2: Lưu Trữ Đám Mây AWS S3
| STT | Tên Secret | Mô Tả & Cách Lấy | Giá Trị Mẫu | Lệnh Gán Nhanh CLI |
| :---: | :--- | :--- | :--- | :--- |
| 5 | `AWS_ACCESS_KEY_ID` | Access Key của IAM User có quyền S3 PutObject. | `AKIAIOSFODNN7EXAMPLE` | `gh secret set AWS_ACCESS_KEY_ID -b "AKIAIOSFODNN7EXAMPLE"` |
| 6 | `AWS_SECRET_ACCESS_KEY` | Secret Access Key tương ứng của IAM User. | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` | `gh secret set AWS_SECRET_ACCESS_KEY -b "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"` |
| 7 | `AWS_S3_BUCKET` | Tên Bucket S3 lưu file APK/IPA. | `amzn-s3-cryptovault` | `gh secret set AWS_S3_BUCKET -b "amzn-s3-cryptovault"` |
| 8 | `AWS_REGION` | Vùng lưu trữ của S3 Bucket. | `ap-southeast-2` | `gh secret set AWS_REGION -b "ap-southeast-2"` |

### Nhóm 3: Ký Số & Phát Hành Android Google Play
| STT | Tên Secret | Mô Tả & Cách Lấy | Giá Trị Mẫu | Lệnh Gán Nhanh CLI |
| :---: | :--- | :--- | :--- | :--- |
| 9 | `ANDROID_KEYSTORE_BASE64` | File keystore release mã hoá Base64. Chạy `base64 -i my.keystore \| tr -d '\n'`. | `MIIDvDCCAqSgAwIBAgIE...` | `gh secret set ANDROID_KEYSTORE_BASE64 -b "$(base64 -i my.keystore \| tr -d '\n')"` |
| 10 | `ANDROID_KEYSTORE_PASSWORD` | Mật khẩu mở file keystore. | `MyKeystorePass123` | `gh secret set ANDROID_KEYSTORE_PASSWORD -b "MyKeystorePass123"` |
| 11 | `ANDROID_KEY_ALIAS` | Tên alias của private key trong keystore. | `my-key-alias` | `gh secret set ANDROID_KEY_ALIAS -b "my-key-alias"` |
| 12 | `ANDROID_KEY_PASSWORD` | Mật khẩu của key alias. | `MyKeyPass123` | `gh secret set ANDROID_KEY_PASSWORD -b "MyKeyPass123"` |
| 13 | `GPLAY_SERVICE_ACCOUNT_JSON` | Nội dung JSON của Google Service Account tải từ Google Cloud Console có quyền Publish. | `{"type": "service_account", ...}` | `gh secret set GPLAY_SERVICE_ACCOUNT_JSON -b "$(cat gplay.json)"` |

### Nhóm 4: Ký Số & Phát Hành iOS Apple App Store
| STT | Tên Secret | Mô Tả & Cách Lấy | Giá Trị Mẫu | Lệnh Gán Nhanh CLI |
| :---: | :--- | :--- | :--- | :--- |
| 14 | `APP_STORE_CONNECT_API_KEY_KEY` | Nội dung file Private Key `.p8` từ App Store Connect API. | `-----BEGIN PRIVATE KEY-----\n...` | `gh secret set APP_STORE_CONNECT_API_KEY_KEY -b "$(cat AuthKey.p8)"` |
| 15 | `APP_STORE_CONNECT_API_KEY_KEY_ID` | Key ID (10 ký tự) từ App Store Connect. | `D383X7YKP4` | `gh secret set APP_STORE_CONNECT_API_KEY_KEY_ID -b "D383X7YKP4"` |
| 16 | `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | Issuer ID (UUID) từ App Store Connect. | `57246542-96fe-1a63-e053-0824d011072a` | `gh secret set APP_STORE_CONNECT_API_KEY_ISSUER_ID -b "57246542-..."` |
| 17 | `APPLE_CERTIFICATE_BASE64` | Chứng chỉ phân phối `.p12` mã hoá Base64. | `MIIKvgIBAzCCCncGCSqG...` | `gh secret set APPLE_CERTIFICATE_BASE64 -b "$(base64 -i cert.p12 \| tr -d '\n')"` |
| 18 | `APPLE_CERTIFICATE_PASSWORD` | Mật khẩu bảo vệ file chứng chỉ `.p12`. | `CertPass2026` | `gh secret set APPLE_CERTIFICATE_PASSWORD -b "CertPass2026"` |
| 19 | `PROVISIONING_PROFILE_BASE64` | File `.mobileprovision` mã hoá Base64. | `MIIUpAYJKoZIhvcNAQcC...` | `gh secret set PROVISIONING_PROFILE_BASE64 -b "$(base64 -i profile.mobileprovision \| tr -d '\n')"` |
| 20 | `MATCH_PASSWORD` | *(Tùy chọn)* Mật khẩu giải mã kho chứng chỉ Fastlane Match. | `MatchSecretPass` | `gh secret set MATCH_PASSWORD -b "MatchSecretPass"` |
| 21 | `MATCH_GIT_URL` | *(Tùy chọn)* Git URL của repo chứa chứng chỉ Match. | `git@github.com:phong-mobile/certs.git` | `gh secret set MATCH_GIT_URL -b "git@github.com:phong-mobile/certs.git"` |

### Nhóm 5: Kênh Chat Doanh Nghiệp (Tùy chọn)
| STT | Tên Secret | Mô Tả & Cách Lấy | Giá Trị Mẫu | Lệnh Gán Nhanh CLI |
| :---: | :--- | :--- | :--- | :--- |
| 22 | `SLACK_WEBHOOK_URL` | Incoming Webhook URL của kênh Slack. | `https://hooks.slack.com/services/T00/B00/XXX` | `gh secret set SLACK_WEBHOOK_URL -b "https://hooks.slack.com/..."` |
| 23 | `TEAMS_WEBHOOK_URL` | Webhook URL của kênh Microsoft Teams Workflows. | `https://phongmobile.webhook.office.com/...` | `gh secret set TEAMS_WEBHOOK_URL -b "https://phongmobile.webhook.office.com/..."` |

---

## 4. Quy Chuẩn & Luồng Gắn Tag Phát Hành (Release Tagging Rules)

Luồng gắn tag là cơ chế chính thức và duy nhất để kích hoạt quy trình **Production Store Release** (Google Play Store, Apple App Store/TestFlight, AWS S3 Production & OTA).

```mermaid
flowchart TD
    A["Dev hoàn thành tính năng trên nhánh 'dev'"] --> B["Tạo PR vào nhánh 'main'"]
    B --> C["CI Checks Pass + Review Approved ➔ Merge main"]
    C --> D["Tạo Tag chuẩn: 'make release-tag v=1.0.0'"]
    D --> E["GitHub Tag Ruleset kiểm tra quyền (Bypass: Release Mgr)"]
    E --> F["GitHub Actions bắt event: push tags 'v*.*.*'"]
    F --> G["Kích hoạt Production Pipeline: Build Signed AAB/IPA"]
    G --> H["Dual Approval (Tech Lead / Admin phê duyệt)"]
    H --> I["Deploy Store + S3 + OTA + Bắn Card Telegram"]
```

### 🏷️ 1. Quy Tắc Định Dạng Tag Chuẩn SemVer (`v*.*.*`)
Hệ thống CI/CD bắt buộc tag phải tuân theo chuẩn **Semantic Versioning (SemVer)**:
- **Cấu trúc chuẩn**: `v<MAJOR>.<MINOR>.<PATCH>` (Bắt buộc có chữ `v` viết thường ở đầu).
  - `v1.0.0`: Phiên bản phát hành chính thức đầu tiên.
  - `v1.0.1`, `v1.0.2`: Phiên bản sửa lỗi, vá hotfix nhỏ (Patch).
  - `v1.1.0`: Phiên bản bổ sung tính năng mới nhưng vẫn tương thích ngược (Minor).
  - `v2.0.0`: Phiên bản nâng cấp lớn có thay đổi kiến trúc hoặc phá vỡ tính tương thích cũ (Major).
- **Bản tiền phát hành (Pre-release)**: `v1.0.0-rc.1`, `v1.0.0-beta.1` (dùng khi thử nghiệm trước ngày ra mắt).

### 🔒 2. Quy Tắc Bảo Vệ Tag (GitHub Tag Ruleset)
Để ngăn chặn việc gắn tag bừa bãi hoặc vô tình kích hoạt release nhầm lên chợ ứng dụng:
- **Tên Ruleset**: `Protected Production Tags (SemVer)` (áp dụng cho pattern `refs/tags/v*.*.*` và `refs/tags/v*`).
- **Quy tắc thực thi**:
  - ❌ **Developers thông thường**: Bị chặn 100% các quyền tạo tag, sửa tag, hoặc xóa tag `v*` trên GitHub.
  - ✅ **Release Managers & Org Admins**: Được cấp quyền Bypass để đẩy tag lên GitHub.
  - 🔒 **Tính Bất Biến (Immutable Tags)**: Tag sau khi đã push lên GitHub sẽ không thể bị ghi đè (không thể `git push -f`).

### ⚡ 3. Cơ Chế Kích Hoạt Pipeline Khi Có Tag
Khi một tag hợp lệ được push lên GitHub:
1. File `.github/workflows/ci.yml` bắt sự kiện `on: push: tags: ['v*.*.*']`.
2. Biến môi trường tự động chuyển sang **`environment: production`** (thay vì `staging` hay `dev`).
3. Pipeline kích hoạt chuỗi tác vụ phát hành:
   - Chạy toàn bộ Unit Tests, Lint, TypeCheck.
   - Biên dịch signed AAB (Android) & IPA (iOS).
   - Tự động tải lên AWS S3 và đăng ký vào OTA Distribution Portal.
   - Nếu dự án có cấu hình **Dual Approval**: Pipeline sẽ dừng lại ở trạng thái `Waiting for review` để Tech Lead hoặc Release Manager phê duyệt trước khi đẩy lên Store.
   - Bắn thẻ **Mobile Builder Photo Card** lên Telegram với tiêu đề `# TenApp Production v1.0.0`.

### 🚀 4. Hướng Dẫn Các Bước Tạo Tag Phát Hành

#### Cách 1: Dùng Lệnh Make (Khuyên dùng - Nhanh & Tránh Lỗi)
Tại thư mục dự án (nhánh `main`):
```bash
make release-tag v=1.0.0 m="Phát hành phiên bản 1.0.0 chính thức"
```
*Lệnh này sẽ tự động kiểm tra xem bạn có đang ở nhánh `main` không, tạo Annotated Tag kèm message và đẩy thẳng lên GitHub.*

#### Cách 2: Dùng Git CLI Thủ Công
```bash
# 1. Đảm bảo đang ở nhánh main và code mới nhất
git checkout main
git pull origin main

# 2. Tạo Annotated Tag (Bắt buộc cờ -a để kèm metadata người tạo và ngày giờ)
git tag -a v1.0.0 -m "Release version 1.0.0: Tính năng mới"

# 3. Đẩy Tag lên GitHub
git push origin v1.0.0
```

#### Cách 3: Tạo Release Trực Tiếp Trên Giao Diện GitHub
1. Vào repository trên GitHub ➔ Cột bên phải mục **Releases** ➔ Bấm **Draft a new release**.
2. Bấm **Choose a tag** ➔ Gõ `v1.0.0` ➔ Bấm **Create new tag: v1.0.0 on publish**.
3. Target: Chọn nhánh **`main`**.
4. Nhập Release title (ví dụ: `v1.0.0 - Official Launch`) và mô tả Changelog.
5. Bấm **Publish release**.

### ⚠️ 5. Xử Lý Khi Gắn Nhầm Tag
Nếu lỡ tạo nhầm tag (ví dụ gõ nhầm version):
```bash
# 1. Xóa tag ở máy cục bộ
git tag -d v1.0.0

# 2. Xóa tag trên GitHub (Chỉ Release Manager hoặc Admin mới có quyền)
git push origin --delete v1.0.0
```

---

## 5. Sổ Tay Lệnh Hàng Ngày (Cheatsheet)

| Nhu Cầu | Câu Lệnh Thực Hiện |
| :--- | :--- |
| **Khởi tạo CI/CD cho dự án mới** | `cicd` *(hoặc `bash ~/.mobile-cicd-admin/init-cicd.sh .`)* |
| **Kiểm tra sức khỏe 15 Test Cases** | `make help && make type-check && make unit-test` |
| **Tạo Tag phát hành Store (SemVer)** | `make release-tag v=1.0.0 m="Mô tả phát hành"` |
| **Đẩy nhanh APK lên OTA + Telegram** | `./scripts/upload-build.sh -f path/to/app.apk -m "Ghi chú bản build"` |
| **Đẩy nhanh IPA lên OTA + Telegram** | `./scripts/upload-build.sh -f path/to/app.ipa -m "Ghi chú bản build iOS"` |
| **Thử nghiệm kết nối Telegram Bot** | `bash scripts/notify-telegram.sh --test` |
| **Đóng gói Android Bundle (AAB)** | `make appbundle` |
| **Đẩy bản vá nhanh JavaScript (OTA Hotfix)**| `make ota-hotfix -m="Vá lỗi khẩn cấp logic đăng nhập"` |
| **Thiết lập Ruleset bảo vệ nhánh** | `cd ~/Code/mobile-cicd-admin && ./setup-github-rules.sh` |

---

## 6. Xử Lý Sự Cố Thường Gặp (Troubleshooting)

### 1. Lỗi `HTTP 403: Resource not accessible by integration` khi chạy GitHub Actions
- **Nguyên nhân**: Repo chưa được cấp quyền `Read and write permissions` cho Workflow.
- **Khắc phục**: Vào repo ➔ **Settings** ➔ **Actions** ➔ **General** ➔ Mục **Workflow permissions** chọn **Read and write permissions** ➔ Tick chọn **Allow GitHub Actions to create and approve pull requests** ➔ Bấm **Save**.

### 2. Lỗi `Cannot find module 'express'` trên Render
- **Nguyên nhân**: Render build từ thư mục gốc nhưng thiếu file dependencies ở root.
- **Khắc phục**: Đã được giải quyết triệt để trong bản phát hành mới của `mobile-cicd-admin` (đồng bộ dependencies lên root `package.json` và thêm script `postinstall`).

### 3. Telegram không gửi được tin nhắn hoặc báo `Chat not found`
- **Nguyên nhân**: Bot `@ShipItCIBot` chưa được thêm vào Group hoặc chưa được cấp quyền gửi tin nhắn.
- **Khắc phục**: Mời bot `@ShipItCIBot` vào nhóm chat, sau đó chạy lệnh kiểm tra kết nối:
  ```bash
  bash scripts/notify-telegram.sh --test
  ```

### 4. Bị lỗi `Push rejected: Push cannot contain secrets` của GitHub
- **Nguyên nhân**: Bạn vừa commit file chứa AWS Access Key hoặc Private Key dạng chuỗi trực tiếp vào git.
- **Khắc phục**: Tuyệt đối không hardcode khóa bảo mật vào file mã nguồn. Luôn lưu khóa trong file `.env` (được `.gitignore`) hoặc trong GitHub Secrets. Chạy `git reset --hard HEAD~1` để xóa commit vi phạm trước khi push lại.
