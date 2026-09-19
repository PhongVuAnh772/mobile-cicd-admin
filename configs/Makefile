# ============================================================================
# 🚀 REACT NATIVE ENTERPRISE CI/CD & OTA APP DISTRIBUTION MAKEFILE
# ============================================================================
# Ví dụ sử dụng:
#   make distributed-ios-dev -m="Gửi bản dev cho @TE_HauTV"
#   make distributed-android-dev -m="Gửi bản dev cho @TE_HauTV"
#   make distributed-android-beta -m="Bản test thanh toán cho QA"
#   make ota-hotfix -m="Hotfix sửa lỗi màn hình ví trong 30s"
#   make appbundle
#   make internal
# ============================================================================

# Tự động trích xuất ghi chú từ cờ -m / m / M / MESSAGE hoặc commit gần nhất
MSG_INPUT := $(or $(m),$(M),$(MESSAGE),$(shell git log -1 --pretty=%B 2>/dev/null | head -n 1),Bản build React Native nội bộ)
override MESSAGE := $(MSG_INPUT)
export MESSAGE
export M := $(MSG_INPUT)

# Tự động trích xuất tác giả và nhánh git nếu chưa truyền
AUTH_INPUT := $(or $(AUTHOR),$(shell git log -1 --pretty=format:'%an' 2>/dev/null),Developer)
override AUTHOR := $(AUTH_INPUT)
export AUTHOR

BRANCH_INPUT := $(or $(REF_NAME),$(shell git rev-parse --abbrev-ref HEAD 2>/dev/null),main)
override REF_NAME := $(BRANCH_INPUT)
export REF_NAME

# Đường dẫn OTA Server (override qua biến môi trường hoặc .env)
export OTA_SERVER_URL ?= http://localhost:3000

.PHONY: help
help:
	@echo "======================================================================"
	@echo "📱 REACT NATIVE CI/CD & OTA DISTRIBUTION COMMANDS"
	@echo "======================================================================"
	@echo "  make dependencies             : Cài đặt node_modules (yarn / npm)"
	@echo "  make pod                      : Cài đặt CocoaPods (cd ios && pod install)"
	@echo "  make clean                    : Dọn dẹp cache Gradle, Pods & node_modules"
	@echo "  make unit-test                : Chạy Jest unit tests & coverage"
	@echo "  make type-check               : Kiểm tra kiểu TypeScript (tsc --noEmit)"
	@echo "--- 🍏 IOS DISTRIBUTION -----------------------------------------------"
	@echo "  make distributed-ios-dev      : Build & đẩy bản Dev iOS lên OTA"
	@echo "  make distributed-ios-beta     : Build & đẩy bản Beta iOS lên OTA"
	@echo "  make distributed-ios-prod     : Build & đẩy bản Prod iOS lên OTA"
	@echo "  make testflight               : Build & đẩy IPA lên Apple TestFlight"
	@echo "  make production-ios           : Đẩy App Store Production Review"
	@echo "--- 🤖 ANDROID DISTRIBUTION ------------------------------------------"
	@echo "  make distributed-android-dev  : Build & đẩy bản Dev Android APK lên OTA"
	@echo "  make distributed-android-beta : Build & đẩy bản Beta Android APK lên OTA"
	@echo "  make distributed-android-prod : Build & đẩy bản Prod Android APK lên OTA"
	@echo "--- ⚡ OTA HOTFIX (AWS S3 - 30 GIÂY) ---------------------------------"
	@echo "  make ota-hotfix               : Đóng gói JS Bundle đẩy lên S3 (< 30s)"
	@echo "--- 🏪 STORE & PRODUCTION --------------------------------------------"
	@echo "  make appbundle                : Build Signed AAB cho Google Play"
	@echo "  make internal                 : Tăng build number & đẩy Google Play Internal"
	@echo "  make production-android       : Tăng build number & đẩy Google Play Production"
	@echo "--- 📢 NOTIFICATIONS (TELEGRAM) --------------------------------------"
	@echo "  make test-telegram            : Kiểm tra kết nối Telegram Bot"
	@echo "  make notify-telegram m='...'  : Gửi thông báo tuỳ chỉnh lên Telegram"
	@echo "======================================================================"

.PHONY: dependencies
dependencies:
	@echo "📦 Cài đặt dependencies..."
	yarn install --frozen-lockfile || npm install

.PHONY: pod
pod:
	@echo "🍎 Cài đặt CocoaPods..."
	cd ios && pod install

.PHONY: pod-update
pod-update:
	@echo "🍎 Cập nhật CocoaPods..."
	cd ios && pod update

.PHONY: clean
clean:
	@echo "🧹 Dọn dẹp môi trường build..."
	rm -rf android/app/build ios/build ios/Pods
	cd android && ./gradlew clean || true

.PHONY: unit-test
unit-test:
	@echo "🧪 Chạy Unit Test..."
	yarn test --coverage || npm test -- --coverage

.PHONY: type-check
type-check:
	@echo "🔍 Kiểm tra TypeScript..."
	yarn tsc --noEmit || npx tsc --noEmit

### IOS __________________________
.PHONY: distributed-ios-dev
distributed-ios-dev:
	@echo "🍏 [IOS DEV] Building React Native iOS (DEV)..."
	make pod
	cd ios && BUILD_ENV="DEV" FLAVOR="dev" fastlane app_distribution || \
	(echo "⚡ Fastlane fallback: Đang upload qua CLI script..." && \
	../ota-distribution/scripts/upload-build.sh --env "dev" --flavor "dev" -m "$(MESSAGE)" -a "$(AUTHOR)" -b "$(REF_NAME)")

.PHONY: distributed-ios-beta
distributed-ios-beta:
	@echo "🍏 [IOS BETA] Building React Native iOS (BETA)..."
	make pod
	cd ios && BUILD_ENV="BETA" FLAVOR="beta" fastlane app_distribution || \
	(echo "⚡ Fastlane fallback: Đang upload qua CLI script..." && \
	../ota-distribution/scripts/upload-build.sh --env "beta" --flavor "beta" -m "$(MESSAGE)" -a "$(AUTHOR)" -b "$(REF_NAME)")

.PHONY: distributed-ios-prod
distributed-ios-prod:
	@echo "🍏 [IOS PROD] Building React Native iOS (PROD)..."
	make pod
	cd ios && BUILD_ENV="PRO" FLAVOR="pro" fastlane app_distribution || \
	(echo "⚡ Fastlane fallback: Đang upload qua CLI script..." && \
	../ota-distribution/scripts/upload-build.sh --env "prod" --flavor "pro" -m "$(MESSAGE)" -a "$(AUTHOR)" -b "$(REF_NAME)")

.PHONY: testflight
testflight:
	@echo "✈️ [IOS TESTFLIGHT] Building & Uploading to Apple TestFlight..."
	make pod
	cd ios && fastlane beta_testflight

.PHONY: production-ios
production-ios:
	@echo "👑 [IOS PRODUCTION] Building & Uploading to Apple App Store..."
	make pod
	cd ios && fastlane update_release

### ANDROID __________________________
.PHONY: distributed-android-dev
distributed-android-dev:
	@echo "🤖 [ANDROID DEV] Building React Native Android APK (DEV)..."
	cd android && ./gradlew assembleRelease --no-daemon
	cd android && BUILD_ENV="DEV" FLAVOR="dev" fastlane upload || \
	(echo "⚡ Fastlane fallback: Đang upload qua CLI script..." && \
	../ota-distribution/scripts/upload-build.sh --env "dev" --flavor "dev" -m "$(MESSAGE)" -a "$(AUTHOR)" -b "$(REF_NAME)")

.PHONY: distributed-android-beta
distributed-android-beta:
	@echo "🤖 [ANDROID BETA] Building React Native Android APK (BETA)..."
	cd android && ./gradlew assembleRelease --no-daemon
	cd android && BUILD_ENV="BETA" FLAVOR="beta" fastlane upload || \
	(echo "⚡ Fastlane fallback: Đang upload qua CLI script..." && \
	../ota-distribution/scripts/upload-build.sh --env "beta" --flavor "beta" -m "$(MESSAGE)" -a "$(AUTHOR)" -b "$(REF_NAME)")

.PHONY: distributed-android-prod
distributed-android-prod:
	@echo "🤖 [ANDROID PROD] Building React Native Android APK (PROD)..."
	cd android && ./gradlew assembleRelease --no-daemon
	cd android && BUILD_ENV="PRO" FLAVOR="pro" fastlane upload || \
	(echo "⚡ Fastlane fallback: Đang upload qua CLI script..." && \
	../ota-distribution/scripts/upload-build.sh --env "prod" --flavor "pro" -m "$(MESSAGE)" -a "$(AUTHOR)" -b "$(REF_NAME)")

### ⚡ OTA HOTFIX (METRO JS BUNDLE AWS S3 - 30S) __________________________
.PHONY: ota-hotfix
ota-hotfix:
	@echo "⚡ [OTA HOTFIX] Đóng gói Metro JS Bundle & đẩy AWS S3..."
	@if [ -f "scripts/deploy-ota-s3.py" ]; then \
		python3 scripts/deploy-ota-s3.py; \
	elif [ -f "ota-distribution/scripts/deploy-ota-s3.py" ]; then \
		python3 ota-distribution/scripts/deploy-ota-s3.py; \
	else \
		echo "❌ Không tìm thấy script deploy-ota-s3.py"; exit 1; \
	fi

.PHONY: ota-update
ota-update: ota-hotfix

### APP STORE & GOOGLE PLAY __________________________
.PHONY: certificates
certificates:
	cd ios && fastlane certificates

.PHONY: appbundle
appbundle:
	@echo "📦 Building Signed Android App Bundle (AAB)..."
	cd android && ./gradlew clean bundleRelease --no-daemon

.PHONY: internal
internal:
	cd android && fastlane set_next_build_number
	make appbundle
	cd android && fastlane upload_internal

.PHONY: production-android
production-android:
	cd android && fastlane set_next_build_number
	make appbundle
	cd android && fastlane production

### 📢 TELEGRAM NOTIFICATIONS __________________________
.PHONY: notify-telegram
notify-telegram:
	@bash scripts/notify-telegram.sh -m "$(MESSAGE)" --status "$(or $(STATUS),info)" --web-url "$(or $(WEB_URL),$(or $(URL),))" --s3-url "$(or $(S3_URL),)"

.PHONY: test-telegram
test-telegram:
	@bash scripts/notify-telegram.sh --test

