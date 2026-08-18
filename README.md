# 🔒 Centralized Mobile CI/CD Admin Repository

> **PRIVATE ADMIN REPOSITORY** dành riêng cho Organization Admins & Release Managers (`phong-mobile`).
> Tất cả file config nhạy cảm, script bảo mật, Fastlane, và quy tắc CI/CD được tập trung quản lý tại đây.
> **Lập trình viên (Developers) trên các repo ứng dụng KHÔNG THỂ XEM hoặc SỬA ĐỔI các file này.**

---

## 📂 Cấu trúc Repository Admin

```text
mobile-cicd-admin/
├── README.md                           # 📖 Hướng dẫn cho Admin
├── setup-github-rules.sh               # 🔒 Script tạo Teams & Rulesets (Cần quyền Org Admin)
├── .github/
│   ├── actions/
│   │   └── notify/action.yml           📢 Reusable Notification Action cho Slack/Teams
│   └── workflows/
│       └── master-pipeline.yml         🔒 Central Reusable Workflow (workflow_call)
└── configs/                            🔒 BỘ FILE CONFIG BẢO MẬT (ẨN VỚI DEVELOPERS)
    ├── .gitleaks.toml                  # Quét lộ secret
    ├── Dangerfile.ts                   # Quy tắc review PR
    ├── release.config.js               # Semantic Release
    ├── setup.sh                        # Script setup local
    ├── ios/
    │   ├── PrivacyInfo.xcprivacy       # Apple Privacy Manifest
    │   └── fastlane/Fastfile           # Fastlane iOS (match, release, adhoc)
    ├── android/
    │   └── fastlane/Fastfile           # Fastlane Android (release, mapping)
    └── src/
        ├── featureFlags.js             # Core Feature Flag Manager (DJB2 Hash)
        └── config/featureFlags.json    # Feature Flag Schema
```

---

## ⚡ Cách cấu hình trên Repo Ứng dụng của Lập trình viên (`your-rn-app`)

Trong repo của Developer, **XOÁ HẾT** các file `Fastfile`, `.gitleaks.toml`, `Dangerfile.ts`, `setup-github-rules.sh`.
Chỉ tạo **duy nhất 1 file trỏ 5 dòng** tại `.github/workflows/ci.yml`:

```yaml
name: "Enterprise Mobile CI/CD"

on:
  push:
    branches: [main, dev]
    tags: ['v*.*.*']
  pull_request:
    branches: [main, dev]
  workflow_dispatch:

jobs:
  admin-pipeline:
    uses: phong-mobile/mobile-cicd-admin/.github/workflows/master-pipeline.yml@main
    secrets: inherit
```

---

## 🔒 Lợi ích Bảo mật

1. **Hidden 100%**: Developer không thể xem nội dung Fastlane, chứng chỉ ký số, script bảo mật hay quy tắc review code.
2. **Centralized Governance**: Admin chỉnh sửa config 1 chỗ tại repo này ➔ 100+ ứng dụng mobile trong Organization tự động cập nhật theo ngay lập tức.
