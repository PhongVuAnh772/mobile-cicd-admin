# 🔒 Centralized Mobile CI/CD & Governance Engine

[![Organization: phong-mobile](https://img.shields.io/badge/Organization-phong--mobile-blue.svg)](https://github.com/phong-mobile)
[![CI Engine: GitHub Actions](https://img.shields.io/badge/CI%2FCD-Reusable_Workflows-2088FF.svg?logo=github-actions)](.github/workflows/master-pipeline.yml)
[![Fastlane: iOS & Android](https://img.shields.io/badge/Fastlane-Automated_Release-00F376.svg?logo=fastlane)](configs/)
[![Quality Gate: Jest 80% & Gitleaks](https://img.shields.io/badge/Quality_Gates-Jest_%E2%89%A580%25_%7C_Gitleaks-brightgreen.svg)](configs/Dangerfile.ts)
[![License: Private/Internal](https://img.shields.io/badge/Access-Private_Admin_Only-red.svg)](#)

> **Kho Quản Trị CI/CD Tập Trung Chuẩn Enterprise** dành riêng cho Organization Admins & Release Managers thuộc tổ chức **`phong-mobile`**.
> Toàn bộ logic nhạy cảm (Fastlane, ký số Keystore/Certificates, Dangerfile, Secrets, Rulesets) được cô lập tại đây. **Lập trình viên trên các repo ứng dụng (Consumer Repos) không thể xem, sửa đổi hay làm rò rỉ mã nguồn phát hành.**

---

## 📑 Mục lục
1. [Tại sao cần mô hình Centralized CI/CD?](#-tại-sao-cần-mô-hình-centralized-cicd)
2. [Cấu trúc Repository](#-cấu-trúc-repository)
3. [Chuẩn bị trước khi triển khai (Làm 1 lần duy nhất)](#-chuẩn-bị-trước-khi-triển-khai-làm-1-lần-duy-nhất)
4. [Hướng dẫn tích hợp vào một dự án mới (Onboarding Checklist)](#-hướng-dẫn-tích-hợp-vào-một-dự-án-mới-onboarding-checklist)
5. [Checklist Đẩy Google Play Store (Android Release)](#-checklist-đẩy-google-play-store-android-release)
6. [Checklist Đẩy App Store & TestFlight (iOS Release)](#-checklist-đẩy-app-store--testflight-ios-release)
7. [Checklist Phân phối OTA Web Distribution](#-checklist-phân-phối-ota-web-distribution)
8. [Chi tiết các công cụ & Script cốt lõi](#-chi-tiết-các-công-cụ--script-cốt-lõi)
   - [`setup-github-rules.sh` — Tự động hoá Governance & Teams](#1-setup-github-rulessh--tự-động-hoá-governance--teams)
   - [`init-cicd.sh` — Interactive CLI & 70 Test Cases Health Check](#2-init-cicdsh--interactive-cli--70-test-cases-health-check)
   - [`configs/Dangerfile.ts` — Trọng tài Review Pull Request](#3-dangerfilets--trọng-tài-review-pr-tự-động)
   - [`src/featureFlags.js` — DJB2 Deterministic User Bucketing](#4-featureflagsjs--rollout-theo-tỷ-lệ--kill-switch)
9. [Các câu hỏi thường gặp (FAQ)](#-các-câu-hỏi-thường-gặp-faq)

---

## 🌟 Tại sao cần mô hình Centralized CI/CD?

Trong các mô hình truyền thống, mỗi dự án mobile tự quản lý file `.github/workflows/`, `Fastfile`, script ký số và tokens. Điều này dẫn đến các rủi ro:
* **Lộ lọt thông tin**: Developers có thể vô tình xem hoặc để lộ Keystore, API Keys, Certificate password.
* **Phân mảnh (Config Drift)**: 20 repo thì có 20 phiên bản CI/CD khác nhau, khi Apple/Google cập nhật policy bắt buộc thì phải sửa 20 nơi.
* **Khó kiểm soát chất lượng**: Không thể bắt buộc 100% repo tuân thủ Test coverage, Gitleaks scan hay chuẩn PR nếu không có quyền admin can thiệp.

### Giải pháp của `mobile-cicd-admin`:
```mermaid
graph TD
    A[Organization phong-mobile] --> B[mobile-cicd-admin]
    B -->|Bảo mật 100%| C(Master Pipeline + Fastlane + DangerJS)
    
    D[Repo App 1: CryptoVault] -->|chỉ gọi .github/workflows/ci.yml| B
    E[Repo App 2: E-Commerce App] -->|chỉ gọi .github/workflows/ci.yml| B
    F[Repo App N: 100+ Mobile Apps] -->|chỉ gọi .github/workflows/ci.yml| B
    
    style B fill:#1e293b,stroke:#3b82f6,stroke-width:2px,color:#fff
    style C fill:#0f172a,stroke:#10b981,stroke-width:2px,color:#fff
```

1. **Zero-Touch Updates**: Admin sửa logic 1 chỗ ➔ 100+ dự án tự động cập nhật ngay lập tức.
2. **Hidden 100%**: Developers không có quyền truy cập repo admin ➔ Không thể thấy hoặc can thiệp vào quy trình release.
3. **Role-Based Governance (RBAC)**: Tự động phân quyền theo Team (`Developers`, `Tech Leads`, `Release Managers`), không bao giờ phải cấp quyền cho từng cá nhân.

---

## 📂 Cấu trúc Repository

```text
mobile-cicd-admin/
├── README.md                           # 📖 Tài liệu hướng dẫn kiến trúc & vận hành
├── setup-github-rules.sh               # 🔒 Script tạo Teams, Dual Approval Environments & Rulesets
├── init-cicd.sh                        # 🚀 CLI tương tác, chẩn đoán 70 Test Cases & theo dõi live log
├── setup.sh                            # 🛠️ Script scaffold/template cho các dự án cần config nội bộ
│
├── .github/
│   ├── actions/
│   │   └── notify/action.yml           # 📢 Composite Action gửi Rich Card lên Slack & Teams
│   └── workflows/
│       ├── master-pipeline.yml         # 🔒 Central Reusable Workflow chính (workflow_call)
│       └── cicd-init-healthcheck.yml   # 🏥 Bộ kiểm thử Health Check 70 Test Cases chuẩn hoá
│
└── configs/                            # 🔒 BỘ FILE CẤU HÌNH GỐC (BẢO MẬT TUYỆT ĐỐI)
    ├── Dangerfile.ts                   # Quy chuẩn review PR (Jira ticket, Lockfile, QR build...)
    ├── release.config.js               # Semantic Release tự động sinh version & Changelog
    ├── Makefile                        # Bộ lệnh make cho React Native (Android + iOS)
    ├── android/
    │   └── fastlane/Fastfile           # Fastlane Android (Auto APK/AAB naming, Google Play)
    ├── ios/
    │   ├── PrivacyInfo.xcprivacy       # Apple Privacy Manifest
    │   └── fastlane/Fastfile           # Fastlane iOS (Match signing, TestFlight, Phased Rollout)
    └── src/
        ├── featureFlags.js             # Engine Feature Flags (DJB2 Deterministic Hash & Kill-Switch)
        ├── config/featureFlags.json    # Schema Feature Flags mặc định offline
        └── __tests__/featureFlags.test.js
```

---

## ⚙️ Chuẩn bị trước khi triển khai (Làm 1 lần duy nhất)

- [ ] **Bước 1: Bật quyền Reusable Workflow cho Organization (hoặc để Public nếu là Personal Account)**
  - Cho phép các repo ứng dụng gọi được workflow từ repo này:
    - [ ] Mở repo **`mobile-cicd-admin`** trên trình duyệt.
    - [ ] Vào **Settings** ➔ **Actions** ➔ **General**.
    - [ ] Cuộn xuống mục **Access** ở cuối trang, chọn: ☑️ **"Accessible from repositories in the 'phong-mobile' organization"** (hoặc để repo chế độ **Public** nếu dùng tài khoản cá nhân).
    - [ ] Bấm **Save**.

- [ ] **Bước 2: Cấu hình Organization Secrets (hoặc Repository Secrets)**
  - Vào **Organization Settings** ➔ **Secrets and variables** ➔ **Actions** (hoặc Settings của repo ứng dụng):
    - [ ] `SLACK_WEBHOOK_URL`: Webhook nhận thông báo kết quả build và link tải.
    - [ ] `TEAMS_WEBHOOK_URL`: Webhook nhận thẻ Microsoft Teams (tuỳ chọn).
    - [ ] `TELEGRAM_BOT_TOKEN`: Token của Telegram Bot lấy từ `@BotFather` (tuỳ chọn).
    - [ ] `TELEGRAM_CHAT_ID`: ID của Chat cá nhân, Group hoặc Kênh Telegram (tuỳ chọn).
    - [ ] `TELEGRAM_THREAD_ID`: ID của Topic / Message Thread nếu nhóm bật Forums/Topics (tuỳ chọn).
    - [ ] `AWS_ACCESS_KEY_ID` & `AWS_SECRET_ACCESS_KEY`: Tài khoản AWS IAM để tải bản build lên S3.
    - [ ] `AWS_S3_BUCKET` & `AWS_REGION`: Tên bucket và region S3 lưu trữ bản build.
    - [ ] `ANDROID_KEYSTORE_BASE64`: Keystore ký số file AAB/APK.
    - [ ] `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`: Mật khẩu Keystore.
    - [ ] `GPLAY_SERVICE_ACCOUNT_JSON`: Service Account JSON của Google Cloud Console để đẩy Google Play Store.
    - [ ] `APP_STORE_CONNECT_API_KEY_KEY`: Chuỗi Private Key `.p8` từ App Store Connect.
    - [ ] `APP_STORE_CONNECT_API_KEY_KEY_ID`: Key ID của App Store Connect API.
    - [ ] `APP_STORE_CONNECT_API_KEY_ISSUER_ID`: Issuer ID dạng UUID của App Store Connect API.
    - [ ] `APPLE_CERTIFICATE_BASE64` & `APPLE_CERTIFICATE_PASSWORD`: Distribution Certificate `.p12` mã hoá Base64 & mật khẩu.
    - [ ] `PROVISIONING_PROFILE_BASE64`: Mobile Provisioning Profile mã hoá Base64.
    - [ ] `OTA_SERVER_URL`: Địa chỉ máy chủ OTA Web Portal (VD: `https://ota-distribution-v1.onrender.com`).
    - [ ] **Repository access**: Chọn **"All repositories"**.

- [ ] **Bước 3: Hướng dẫn nhanh lấy Telegram Bot Token & Chat ID (1 Phút)**
  - 1. Mở Telegram, tìm kiếm **`@BotFather`** ➔ Gõ `/newbot` ➔ Đặt tên và username cho bot ➔ Copy mã **Token** (`123456789:ABC...`) lưu vào secret `TELEGRAM_BOT_TOKEN`.
  - 2. Lấy **Chat ID**:
    - **Gửi tin nhắn riêng**: Tìm **`@userinfobot`** và bấm `/start` ➔ Copy ID của bạn.
    - **Gửi vào Group**: Thêm Bot vừa tạo vào nhóm ➔ Thêm bot **`@RawDataBot`** vào nhóm để xem `chat.id` (thường bắt đầu bằng `-100...`) ➔ Lưu vào secret `TELEGRAM_CHAT_ID`.
  - 3. *(Tuỳ chọn)* Nếu nhóm bật chế độ **Topics (Forum)**: Chuột phải vào Topic ➔ Copy Link Topic ➔ Số cuối cùng trên link chính là `message_thread_id` ➔ Lưu vào `TELEGRAM_THREAD_ID`.

- [ ] **Bước 4: Chuẩn bị GitHub CLI trên máy Admin**
  - [ ] Đảm bảo máy của bạn đã cài đặt GitHub CLI (`gh`):
    ```bash
    # Đăng nhập
    gh auth login

    # Cấp đủ quyền quản trị Org (admin:org, repo)
    gh auth refresh -s admin:org,repo
    ```

---

## 🚀 Hướng dẫn tích hợp vào một dự án mới (Onboarding Checklist)

Quy trình chuẩn từng bước khi gắn CI/CD vào một ứng dụng mới (ví dụ: `game_platform` hoặc `my-awesome-app`):

- [ ] **Bước 1: Tạo repo trên GitHub**
  - [ ] Vào GitHub ➔ Tạo repo mới.
  - [ ] ⚠️ **Lưu ý**: Tích chọn **"Add a README file"** để tạo sẵn nhánh `main` *(Bắt buộc phải có nhánh `main` trước thì mới tạo được Ruleset bảo vệ)*.

- [ ] **Bước 2: Cài đặt quyền Workflow Permissions (Bắt buộc — Làm trên GitHub)**
  - [ ] Vào repo ➔ **Settings** ➔ **Actions** ➔ **General**.
  - [ ] Kéo xuống mục **Workflow permissions**:
    - [ ] Chọn: 🔘 **Read and write permissions** *(để workflow có quyền upload Artifacts APK/AAB, cập nhật commit status)*.
    - [ ] Tích chọn: ☑️ **Allow GitHub Actions to create and approve pull requests**.
  - [ ] Bấm **Save**.

- [ ] **Bước 3: Khai báo Secrets cho dự án**
  - [ ] Vào **Settings** ➔ **Secrets and variables** ➔ **Actions** trên repo con (nếu chưa cấu hình ở cấp Organization).
  - [ ] Thêm các Secrets cần thiết theo nhu cầu tính năng (Slack, AWS, Keystore, Google Play).

- [ ] **Bước 4: Thiết lập Rulesets & Dual Approval (Admin)**
  - [ ] Tại thư mục repo `mobile-cicd-admin`, chạy:
    ```bash
    ./setup-github-rules.sh
    ```
    - [ ] **Organization / Owner**: Nhập `phong-mobile` hoặc `username` cá nhân của bạn.
    - [ ] **Repository**: Nhập tên repo ứng dụng (ví dụ: `game_platform`).
    - [ ] **Xác nhận 2FA**: Gõ `CONFIRM_ADMIN`.
  - [ ] ⏱️ **Sau 15 giây**: Repo mới đã có đầy đủ 3 Teams, Environments có Dual Approval và Branch/Tag Protection.

- [ ] **Bước 5: Thêm file `.github/workflows/ci.yml` vào repo ứng dụng**
  - [ ] Tạo duy nhất 1 file tại đường dẫn: `.github/workflows/ci.yml`:
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

    jobs:
      admin-pipeline:
        uses: phong-mobile/mobile-cicd-admin/.github/workflows/master-pipeline.yml@main
        secrets: inherit
    ```

- [ ] **Bước 6: Thêm `Makefile` & Fastlane lanes cho React Native**
  - [ ] Copy `configs/Makefile` vào gốc dự án ứng dụng (`Makefile`).
  - [ ] Copy `configs/android/fastlane/Fastfile` vào `android/fastlane/Fastfile`.
  - [ ] Copy `configs/ios/fastlane/Fastfile` vào `ios/fastlane/Fastfile`.
  - [ ] Copy `ota-distribution/scripts/upload-build.sh` vào `scripts/upload-build.sh`.

- [ ] **Bước 7: Chạy kiểm tra nhanh nội bộ (Local Health Check)**
  - [ ] Kiểm tra lệnh trợ giúp: `make help`
  - [ ] Kiểm tra TypeScript: `make type-check`
  - [ ] Chạy Unit Test: `make unit-test`
  - [ ] Kiểm tra nhanh 15 TCs bằng lệnh: `./init-cicd.sh /path/to/project`

- [ ] **Bước 8: Push code lên GitHub để kích hoạt Pipeline**
  - [ ] Commit toàn bộ cấu hình:
    ```bash
    git add .
    git commit -m "ci: integrate centralized mobile CI/CD pipeline"
    git push origin main
    ```
  - [ ] Mở tab **Actions** trên GitHub để theo dõi pipeline chạy tự động.

---

## 🏪 Checklist Đẩy Google Play Store (Android Release)

- [ ] **1. Kiểm tra cấu hình Android**:
  - [ ] `applicationId` và `versionCode` đã được khai báo chuẩn trong `android/app/build.gradle`.
  - [ ] Keystore Release đã được tạo và chuyển đổi thành chuỗi Base64 (`ANDROID_KEYSTORE_BASE64`).
- [ ] **2. Biên dịch Signed AAB cục bộ**:
  - [ ] Chạy lệnh `make appbundle` để kiểm tra quá trình build `bundleRelease`.
  - [ ] Kiểm tra file AAB tại: `android/app/build/outputs/bundle/release/app-release.aab`.
- [ ] **3. Đăng ký & Upload thủ công lần đầu trên Google Play Console**:
  - [ ] Đăng nhập [Google Play Console](https://play.google.com/console).
  - [ ] Tạo ứng dụng mới và tải file `.aab` lên **Internal Testing** hoặc **Production**.
  - [ ] Hoàn thành 100% các bảng khai báo bắt buộc:
    - [ ] App Access (Tài khoản demo đăng nhập).
    - [ ] Ads (Có hiển thị quảng cáo hay không).
    - [ ] Content Rating (Xếp hạng độ tuổi IARC).
    - [ ] Target Audience & Content (Độ tuổi mục tiêu).
    - [ ] Data Safety Form (Khai báo thu thập dữ liệu).
    - [ ] Privacy Policy URL (Chính sách bảo mật).
- [ ] **4. Tự động hoá các lần cập nhật tiếp theo qua CI/CD**:
  - [ ] Tạo Google Cloud Service Account với quyền **Release Manager** trên Play Console.
  - [ ] Thêm nội dung JSON key vào GitHub Secret: `GPLAY_SERVICE_ACCOUNT_JSON`.
  - [ ] Kích hoạt phát hành tự động:
    - [ ] Đẩy lên Internal Testing: `make internal`
    - [ ] Đẩy lên Production Draft: `make production-android` hoặc push tag `v1.0.0`.

---

## 🍏 Checklist Đẩy App Store & TestFlight (iOS Release)

- [ ] **1. Kiểm tra cấu hình iOS Native**:
  - [ ] Bundle Identifier (`bundle_id`) đã được đăng ký trên [Apple Developer Portal](https://developer.apple.com).
  - [ ] Thư mục `ios/` đã cấu hình CocoaPods (`pod install` chạy thành công không có lỗi).
  - [ ] `PrivacyInfo.xcprivacy` (Apple Privacy Manifest bắt buộc) đã được thêm vào Xcode target.
  - [ ] Xcode Scheme và Workspace tồn tại hợp lệ (`*.xcworkspace` và `*.xcodeproj`).

- [ ] **2. Cấu hình Signing Certificates & Profiles**:
  - [ ] **Cách 1 (Khuyên dùng - Fastlane Match)**:
    - [ ] `MATCH_GIT_URL`: URL kho git chứa chứng chỉ (repo private an toàn).
    - [ ] `MATCH_PASSWORD`: Mật khẩu mã hoá Certificates repo.
  - [ ] **Cách 2 (Import trực tiếp qua GitHub Secrets)**:
    - [ ] `APPLE_CERTIFICATE_BASE64`: File chứng chỉ Distribution `.p12` được mã hoá Base64 (`base64 -i cert.p12 | pbcopy`).
    - [ ] `APPLE_CERTIFICATE_PASSWORD`: Mật khẩu bảo vệ file `.p12`.
    - [ ] `PROVISIONING_PROFILE_BASE64`: File Distribution Mobile Provision profile mã hoá Base64.

- [ ] **3. Cấu hình App Store Connect API Key (Bắt buộc để upload tự động)**:
  - [ ] Tạo API Key tại **App Store Connect** ➔ **Users and Access** ➔ **Integrations** ➔ **App Store Connect API** (Role: *App Manager* hoặc *Admin*).
  - [ ] Tải file `AuthKey_XXXXXX.p8`.
  - [ ] Thêm vào GitHub Secrets:
    - [ ] `APP_STORE_CONNECT_API_KEY_KEY`: Toàn bộ nội dung chuỗi bí mật của file `.p8` (bắt đầu bằng `-----BEGIN PRIVATE KEY-----`).
    - [ ] `APP_STORE_CONNECT_API_KEY_KEY_ID`: Key ID (10 ký tự, ví dụ `2X9R427N34`).
    - [ ] `APP_STORE_CONNECT_API_KEY_ISSUER_ID`: Issuer ID dạng UUID (ví dụ `69a6de70-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).

- [ ] **4. Phân phối TestFlight (Testing & QA)**:
  - [ ] Chạy lệnh cục bộ:
    ```bash
    make testflight m="Bản test Sprint 12 cho Internal Testers"
    ```
  - [ ] Hoặc kích hoạt qua GitHub Actions:
    - [ ] Vào tab **Actions** ➔ Chọn **Enterprise Mobile CI/CD**.
    - [ ] Nhấn **Run workflow** ➔ Tích chọn `build_ios: true` (hoặc push tag `v*.*.*`).
  - [ ] File IPA được tự động đóng gói, mã hoá signing và tải lên Apple TestFlight trong vòng 10-15 phút.

- [ ] **5. Phát hành App Store Chính thức (Production Release)**:
  - [ ] **Lần đầu tiên phát hành**:
    - [ ] Chạy `cd ios && fastlane first_release` (hoặc tải IPA từ GitHub Artifacts).
    - [ ] Vào App Store Connect hoàn tất mô tả, từ khoá, ảnh chụp màn hình đa thiết bị (6.7" và 6.5" iPhone display).
    - [ ] Khai báo App Privacy (Dữ liệu thu thập, mục đích sử dụng tương ứng với `PrivacyInfo.xcprivacy`).
    - [ ] Bấm **Submit for Review** thủ công trên App Store Connect UI.
  - [ ] **Các lần cập nhật tiếp theo (Update Releases)**:
    - [ ] Chạy lệnh `make production-ios` hoặc gắn Git Tag chuẩn Semantic Version:
      ```bash
      git tag -a v1.0.0 -m "Release version 1.0.0"
      git push origin v1.0.0
      ```
    - [ ] Fastlane tự động kích hoạt **Phased Rollout**:
      - Ngày 1: 1% người dùng nhận update
      - Ngày 2: 2%
      - Ngày 3: 5%
      - Ngày 4: 10%
      - Ngày 5: 20%
      - Ngày 6: 50%
      - Ngày 7: 100% (Phát hành toàn bộ)
    - [ ] Nếu phát hiện lỗi nghiêm trọng, Release Manager có thể Pause Phased Rollout ngay lập tức trên App Store Connect.

---

## 📲 Checklist Phân phối OTA Web Distribution

- [ ] **1. Máy chủ OTA Portal**:
  - [ ] Khởi chạy máy chủ: `node ota-distribution/server/index.js` (hoặc qua Docker / Render).
  - [ ] Truy cập Dashboard tại `http://localhost:3000` hoặc domain cấu hình.
- [ ] **2. Phân phối bản build kèm Metadata**:
  - [ ] Bản Dev: `make distributed-android-dev m="Gửi bản dev cho @TE_HauTV"`
  - [ ] Bản Beta: `make distributed-android-beta m="Bản test tính năng thanh toán cho QA"`
  - [ ] Bản Prod: `make distributed-android-prod m="Bản phát hành chính thức"`
- [ ] **3. Cài đặt & Quét mã QR**:
  - [ ] Mở camera điện thoại quét mã QR hiển thị trên màn hình popup.
  - [ ] Đối với iOS: Mở Safari truy cập trang `install.html` và xác nhận cài đặt Enterprise Certificate.
  - [ ] Đối với Android: Tải trực tiếp file `.apk` và cài đặt.

---


## 🛠️ Chi tiết các công cụ & Script cốt lõi

### 1. `setup-github-rules.sh` — Tự động hoá Governance & Teams
Script đảm bảo tính tuân thủ và bảo mật thông qua 5 lớp phòng vệ:

1. **Security Gate**: Kiểm tra quyền thực thi; chỉ tài khoản **Owner/Admin** của `phong-mobile` mới được chạy. Ghi nhật ký vào file `github-rules-audit.log`.
2. **Quản lý Teams**:
   * `mobile-developers`: Quyền `Write` (Push code, tạo branch, mở PR).
   * `mobile-tech-leads`: Quyền `Maintain` (Review code, quản trị issues).
   * `release-managers`: Quyền `Maintain` + đặc quyền tạo release.
3. **Environments & Dual Approval**:
   * Môi trường `production` kích hoạt `prevent_self_approval: true` (người tạo build không được tự duyệt).
   * Bắt buộc có chữ ký phê duyệt đồng thời từ **cả Tech Lead và Release Manager**.
   * Thời gian đệm an toàn (`wait_timer`): 5 phút.
4. **Branch Ruleset (`main`)**:
   * Bắt buộc qua Pull Request (tối thiểu 1 approval từ Code Owner).
   * Hủy review khi có commit mới (`dismiss_stale_reviews_on_push: true`).
   * Phải giải quyết 100% thảo luận (`required_review_thread_resolution: true`).
   * Chặn hoàn toàn Force Push và Xoá nhánh.
   * **Status Checks bắt buộc**: `ESLint & TypeScript Checks`, `Jest Unit Tests (≥ 80%)`, `Gitleaks Secret Scanning`.
5. **Tag Ruleset (`v*.*.*`)**:
   * Khóa toàn bộ các tag phiên bản. Chỉ thành viên team `release-managers` mới có quyền gắn tag release.

---

### 2. `init-cicd.sh` — Interactive CLI & 70 Test Cases Health Check
Dành cho lập trình viên và DevOps kiểm tra nhanh sức khỏe dự án:

```bash
# Thiết lập alias (chỉ làm 1 lần trên máy cá nhân)
echo 'alias init-mobile-cicd='\''bash -c "t=\$(mktemp -d); git clone --depth=1 --quiet https://github.com/phong-mobile/mobile-cicd-admin.git \"\$t\" && \"\$t/init-cicd.sh\" \"\$PWD\"; rm -rf \"\$t\""'\''' >> ~/.zshrc && source ~/.zshrc

# Sử dụng: cd vào thư mục bất kỳ dự án mobile và chạy
init-mobile-cicd
```

**Tính năng chính:**
* **Tự động phát hiện kiến trúc**: Nhận diện Expo Managed, Expo Dev Client, Expo Prebuild hay React Native CLI thuần. Liệt kê các thư viện native nhạy cảm (`Firebase`, `Notifee`, `Reanimated`, `WalletConnect`, `Camera`...).
* **Bộ chẩn đoán 70 Test Cases**: Quét cấu hình `package.json`, TypeScript, Babel/Metro, .gitignore che chắn `.env` & keystore, kiểm tra không hardcode khóa AWS bí mật.
* **Điều khiển trực tiếp qua Terminal**: Cho phép kích hoạt pipeline, theo dõi live build logs từ GitHub runner (`gh run watch`), kích hoạt build Production AAB hoặc bắn bản vá OTA Hotfix lên S3 chỉ trong 30 giây.

---

### 3. `Dangerfile.ts` — Trọng tài Review PR Tự Động
Được kích hoạt tự động ở mỗi Pull Request để giữ chuẩn code:
* 🛑 **Chặn PR quá lớn**: Cảnh báo nếu PR vượt quá 500 dòng code.
* 📝 **Bắt buộc Ticket Jira**: Tiêu đề hoặc mô tả PR phải chứa mã ticket hợp lệ (dạng `[PAS-1234]`).
* 📦 **Đồng bộ Lockfile**: Báo lỗi nếu sửa `package.json` mà quên commit `yarn.lock`/`package-lock.json`.
* 📸 **Bắt buộc hình ảnh UI**: Nếu PR có sửa đổi file `.tsx`/`.jsx`, yêu cầu phải đính kèm ảnh chụp màn hình hoặc video demo.
* 📲 **Tự sinh QR Code tải bản test**: Tự động bình luận vào PR bảng tải app nội bộ từ AWS S3 (file APK cho Android, OTA Plist cho iOS, và link chạy thử tức thì trên Appetize.io).

---

### 4. `featureFlags.js` — Rollout theo Tỷ lệ & Kill-Switch
Engine quản lý tính năng động cho mobile app không phụ thuộc vào bên thứ ba:
* **DJB2 Deterministic User Bucketing**: Băm chuỗi `userId + flagKey` thành bucket từ `0 - 99`. Đảm bảo người dùng A luôn luôn nhận cùng một trạng thái tính năng, không bị giật giao diện giữa các lần mở app.
* **Instant Kill-Switch**: Cho phép vô hiệu hoá ngay lập tức tính năng gặp sự cố nghiêm trọng mà không cần nộp lại bản cập nhật lên App Store / Google Play.
* **Offline Fallback Safe**: Khi mất mạng, hệ thống tự động quay về giá trị an toàn trong `featureFlags.json`.

---

## ❓ Các câu hỏi thường gặp (FAQ)

#### Q1: Tôi có cần tạo rule riêng cho từng thành viên mới không?
> **Không.** Toàn bộ quy trình phân quyền dựa trên **GitHub Teams** (`mobile-developers`, `mobile-tech-leads`, `release-managers`) đối với Organization, hoặc dựa trên quyền Collaborator của repo đối với tài khoản cá nhân. Khi có nhân sự mới, bạn chỉ cần gán vào đúng vai trò. Mọi quyền hạn, hạn chế push code và quyền duyệt release sẽ tự động áp dụng.

#### Q2: Bắt buộc các dự án phải nằm trong Organization `phong-mobile` không?
> **Không bắt buộc! Hệ thống hỗ trợ Dual-Mode (Cả Organization lẫn Personal User Account):**
> 1. **Chế độ Organization (`phong-mobile`)**: Phù hợp cho công ty/doanh nghiệp. Hỗ trợ phân quyền qua 3 Teams (`developers`, `tech-leads`, `release-managers`), Dual Approval và chia sẻ Secrets tập trung cấp Org.
> 2. **Chế độ Personal Account (`username-cua-ban`)**: Phù hợp cho dự án cá nhân hoặc Solo Dev. Vì repo `mobile-cicd-admin` là **Public**, bất kỳ repo cá nhân nào cũng có thể gọi pipeline. Script `./setup-github-rules.sh` sẽ tự động nhận diện tài khoản cá nhân để thiết lập Ruleset bảo vệ nhánh `main` và tag release mà không cần tạo Teams. Secrets được lưu tại **Repository Secrets** của chính repo đó.

#### Q3: Lập trình viên có thể sửa đổi cấu hình Fastlane hoặc bỏ qua bước test không?
> **Không thể.** Toàn bộ file cấu hình `Fastfile`, `Dangerfile.ts` và script test nằm trong repo admin này. Repo của lập trình viên chỉ chứa file `ci.yml` trỏ link sang đây. Bất kỳ nỗ lực can thiệp nào vào pipeline sẽ bị chặn bởi các status checks bắt buộc của Branch Protection Ruleset.

---

### 👨‍💻 Tác giả & Quản trị hệ thống
* **Organization**: [`phong-mobile`](https://github.com/phong-mobile)
* **Lead Admin / Maintainer**: [PhongVuAnh772](https://github.com/PhongVuAnh772)
* **Liên hệ hỗ trợ**: `vuanhphong1701@gmail.com`
