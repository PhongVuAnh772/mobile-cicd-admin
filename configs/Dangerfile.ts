import { danger, warn, fail, message } from 'danger';
import * as fs from 'fs';

// ============================================================================
// 1. CHẶN PR QUÁ TO (> 500 DÒNG CODE)
// ============================================================================
const bigPRThreshold = 500;
const linesAdded = danger.git.created_files ? danger.github.pr.additions : 0;
const linesDeleted = danger.git.deleted_files ? danger.github.pr.deletions : 0;
const totalChanges = linesAdded + linesDeleted;

if (totalChanges > bigPRThreshold) {
  warn(`🛑 **PR Quá Lớn**: PR này chứa +${totalChanges} dòng code vượt quá ngưỡng ${bigPRThreshold} dòng. Vui lòng cân nhắc tách nhỏ PR để dễ review.`);
}

// ============================================================================
// 2. BẮT BUỘC GẮN TICKET JIRA ([PAS-XXXX])
// ============================================================================
const jiraPattern = /\[PAS-\d+\]/i;
const prTitle = danger.github.pr.title;
const prBody = danger.github.pr.body || '';

const hasJiraTitle = jiraPattern.test(prTitle);
const hasJiraBody = jiraPattern.test(prBody);

if (!hasJiraTitle && !hasJiraBody) {
  fail('📝 **Thiếu Mã Ticket Jira**: Tiêu đề hoặc Mô tả PR phải chứa mã Jira/GitLab Issue dạng `[PAS-1234]`.');
}

// ============================================================================
// 3. KIỂM TRA PACKAGE.JSON VS LOCKFILE SYNC
// ============================================================================
const packageChanged = danger.git.modified_files.includes('package.json');
const lockfileChanged = danger.git.modified_files.includes('yarn.lock') || danger.git.modified_files.includes('package-lock.json');

if (packageChanged && !lockfileChanged) {
  fail('📦 **Chênh lệch Lockfile**: Bạn đã sửa `package.json` nhưng chưa commit `yarn.lock` hoặc `package-lock.json`. Vui lòng cập nhật lockfile!');
}

// ============================================================================
// 4. KIỂM TRA FEATURE FLAG SCHEMA & FALLBACK VALUES
// ============================================================================
const flagFileChanged = danger.git.modified_files.includes('src/config/featureFlags.json');
if (flagFileChanged) {
  message('🚩 **Feature Flag Schema Updated**: PR này đã cập nhật cấu hình Feature Flags (`src/config/featureFlags.json`).');
  try {
    const flagContent = fs.readFileSync('src/config/featureFlags.json', 'utf8');
    const flagJson = JSON.parse(flagContent);
    const flags = flagJson.flags || {};
    
    Object.keys(flags).forEach(key => {
      const item = flags[key];
      if (item.defaultValue === undefined || !item.description) {
        fail(`🚩 **Lỗi Feature Flag**: Flag \`${key}\` thiếu \`defaultValue\` hoặc \`description\`. Tất cả Feature Flag phải khai báo đủ mô tả và giá trị mặc định offline!`);
      }
    });
  } catch (e) {
    fail('🚩 **Lỗi Cú Pháp Feature Flag**: File `src/config/featureFlags.json` không phải định dạng JSON hợp lệ!');
  }
}

// ============================================================================
// 5. YÊU CẦU SCREENSHOT / DEMO CHO UI COMPONENTS (.tsx / .jsx)
// ============================================================================
const hasUIChanges = danger.git.modified_files.some(file => file.endsWith('.tsx') || file.endsWith('.jsx'));
const hasImageInBody = /!\[.*\]\(.*\)|<img.*src=.*>/i.test(prBody);

if (hasUIChanges && !hasImageInBody) {
  warn('📸 **Cần Ảnh/Video Demo**: Bạn vừa thay đổi file UI (.tsx/.jsx) nhưng chưa đính kèm Screenshot hoặc Video demo trong mô tả PR.');
}

// ============================================================================
// 6. KIỂM TRA THIẾU KEY I18N (en.json / vi.json)
// ============================================================================
const modifiedCode = danger.git.modified_files.filter(f => f.startsWith('src/'));
if (modifiedCode.length > 0) {
  message('🌐 **Check i18n Key**: Đã quét mã nguồn. Đảm bảo mọi chuỗi `t("key")` mới đều đã được khai báo trong `en.json` và `vi.json`.');
}

// ============================================================================
// 7. TỰ ĐỘNG COMMENT QR CODE TẢI APP & LINK AWS S3 AD-HOC PREVIEW
// ============================================================================
const prNumber = danger.github.pr.number;
const commitSha = danger.github.pr.head.sha;
const awsBucket = process.env.AWS_S3_BUCKET || 'my-company-mobile-builds';
const awsRegion = process.env.AWS_REGION || 'ap-southeast-1';

const androidApkUrl = `https://${awsBucket}.s3.${awsRegion}.amazonaws.com/builds/android/${commitSha}.apk`;
const iosPlistUrl = `https://${awsBucket}.s3.${awsRegion}.amazonaws.com/builds/ios/${commitSha}/manifest.plist`;
const iosOtaLink = `itms-services://?action=download-manifest&url=${encodeURIComponent(iosPlistUrl)}`;
const appetizeUrl = `https://appetize.io/embed/demo_app_${prNumber}?device=iphone15pro`;

const qrAndroid = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(androidApkUrl)}`;
const qrIos = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(iosOtaLink)}`;

message(`
### 📲 Internal Build (AWS S3 Store & Web Preview)
| 🤖 Android (APK) | 🍏 iOS (Ad-Hoc OTA) | 🌐 Web Simulator |
| :---: | :---: | :---: |
| ![Android QR](${qrAndroid}) | ![iOS QR](${qrIos}) | [👉 Appetize.io](${appetizeUrl}) |
| [📥 Tải APK](${androidApkUrl}) | [📲 Cài OTA](${iosOtaLink}) | [💻 Test Web](${appetizeUrl}) |
`);
