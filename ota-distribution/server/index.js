const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { nanoid } = require('nanoid');
const QRCode = require('qrcode');
const plist = require('plist');
const cors = require('cors');
const dotenv = require('dotenv');
const { S3Client, PutObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { Upload } = require('@aws-sdk/lib-storage');
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");

// Load environment variables
dotenv.config();

const PORT = process.env.PORT || 3000;
let BASE_URL = process.env.BASE_URL || process.env.RENDER_EXTERNAL_URL || `http://localhost:${PORT}`;
if (BASE_URL.includes('ota-distribution-v1.onrender.com')) {
  BASE_URL = process.env.RENDER_EXTERNAL_URL || 'https://mobile-cicd-admin.onrender.com';
}

console.log("==========================================================================");
console.log("🚀 MOBILE OTA & MULTI-ENVIRONMENT DISTRIBUTION SERVER");
console.log("==========================================================================");
console.log("PORT:          ", PORT);
console.log("BASE_URL:      ", BASE_URL);
console.log("S3 Configured: ", {
    bucket: !!process.env.AWS_S3_BUCKET,
    accessKey: !!process.env.AWS_ACCESS_KEY_ID,
    secretKey: !!process.env.AWS_SECRET_ACCESS_KEY,
    region: process.env.AWS_REGION || "ap-southeast-2"
});
console.log("==========================================================================");

const app = express();

// AWS S3 Configuration
const s3Client = new S3Client({
  region: process.env.AWS_REGION || 'ap-southeast-2',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
});

const BUCKET_NAME = process.env.AWS_S3_BUCKET || 'amzn-s3-cryptovault';

/**
 * Upload to S3 Helper
 */
async function uploadToS3(file) {
  const fileKey = `ota/${Date.now()}-${file.originalname}`;
  const fileStream = fs.createReadStream(file.path);
  
  let contentType = 'application/octet-stream';
  const ext = path.extname(file.originalname).toLowerCase();
  if (ext === '.apk') contentType = 'application/vnd.android.package-archive';
  else if (ext === '.ipa') contentType = 'application/octet-stream';
  else if (ext === '.aab') contentType = 'application/octet-stream';
  else if (ext === '.zip') contentType = 'application/zip';

  const upload = new Upload({
    client: s3Client,
    params: {
      Bucket: BUCKET_NAME,
      Key: fileKey,
      Body: fileStream,
      ContentType: contentType,
    },
  });

  await upload.done();
  // Xóa file tạm sau khi upload lên S3 thành công
  try {
    fs.unlinkSync(file.path);
  } catch (e) {
    console.warn("⚠️ Warning deleting temp file:", e.message);
  }
  
  return `https://${BUCKET_NAME}.s3.${process.env.AWS_REGION || 'ap-southeast-2'}.amazonaws.com/${fileKey}`;
}

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.use(express.static(path.join(__dirname, '../web/public')));

// Simple persistent DB
const DB_PATH = path.join(__dirname, 'db.json');
const UPLOADS_PATH = path.join(__dirname, 'uploads');

if (!fs.existsSync(DB_PATH)) {
  fs.writeFileSync(DB_PATH, JSON.stringify({ apps: {} }, null, 2));
}

if (!fs.existsSync(UPLOADS_PATH)) {
  fs.mkdirSync(UPLOADS_PATH, { recursive: true });
}

function getDB() {
  try {
    return JSON.parse(fs.readFileSync(DB_PATH, 'utf-8'));
  } catch (e) {
    return { apps: {} };
  }
}

function updateDB(data) {
  fs.writeFileSync(DB_PATH, JSON.stringify(data, null, 2), 'utf-8');
}

// Multer Configuration - Hỗ trợ .ipa, .apk, .aab, .zip
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOADS_PATH),
  filename: (req, file, cb) => cb(null, `${nanoid()}${path.extname(file.originalname)}`)
});

const upload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    const allowedExts = ['.ipa', '.apk', '.aab', '.zip'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (!allowedExts.includes(ext)) {
      return cb(new Error(`Chỉ chấp nhận các file cài đặt mobile (${allowedExts.join(', ')}). Nhận được: ${ext}`));
    }
    cb(null, true);
  },
  limits: { fileSize: 1024 * 1024 * 1024 } // 1GB limit
});

/**
 * Chuẩn hóa biến Environment (DEV / BETA / PROD)
 */
function normalizeEnvironment(rawEnv) {
  if (!rawEnv) return 'dev';
  const val = String(rawEnv).trim().toLowerCase();
  if (val.startsWith('pro')) return 'prod';
  if (val === 'beta' || val === 'staging') return 'beta';
  if (val === 'dev' || val === 'development' || val === 'debug') return 'dev';
  return val;
}

/**
 * Chuẩn hóa Flavor (dev / beta / pro)
 */
function normalizeFlavor(rawFlavor, env) {
  if (rawFlavor) {
    const val = String(rawFlavor).trim().toLowerCase();
    if (val.startsWith('pro')) return 'pro';
    if (val === 'beta') return 'beta';
    if (val === 'dev') return 'dev';
    return val;
  }
  if (env === 'prod') return 'pro';
  if (env === 'beta') return 'beta';
  return 'dev';
}

/**
 * Upload API
 * POST /api/ota/upload
 * Hỗ trợ upload từ Web UI, Curl, Fastlane hoặc Makefile
 */
app.post('/api/ota/upload', upload.any(), async (req, res) => {
  try {
    const file = req.files && req.files.length > 0 ? req.files[0] : null;
    if (!file) {
      return res.status(400).json({ error: 'Vui lòng chọn file build (.ipa, .apk, .aab) để upload' });
    }

    const ext = path.extname(file.originalname).toLowerCase();
    const isIos = ext === '.ipa';
    const isAndroid = ext === '.apk' || ext === '.aab';
    const platform = req.body.platform || (isIos ? 'ios' : 'android');
    const fileType = ext.replace('.', '');

    // Metadata extraction
    const rawEnv = req.body.environment || req.body.env || req.body.BUILD_ENV || 'dev';
    const environment = normalizeEnvironment(rawEnv);
    const flavor = normalizeFlavor(req.body.flavor, environment);

    const appName = req.body.appName || req.body.app_name || (isIos ? 'iOS App' : 'Android App');
    const version = req.body.version || '1.0.0';
    const buildNumber = req.body.buildNumber || req.body.build_number || req.body.BUILD_NUMBER || '1';
    const bundleId = req.body.bundleId || req.body.bundle_id || req.body.package_name || 'com.app';
    
    // Ghi chú bản vá: hỗ trợ flag -m="Gửi bản dev cho @TE_HauTV"
    const message = req.body.message || req.body.m || req.body.MESSAGE || 'Bản build nội bộ mới';
    const author = req.body.author || req.body.AUTHOR || '';
    const branch = req.body.branch || req.body.refName || req.body.REF_NAME || 'main';

    const id = nanoid(10);
    let fileUrl;

    if (process.env.AWS_ACCESS_KEY_ID && process.env.AWS_S3_BUCKET) {
      // Upload trực tiếp lên S3
      fileUrl = await uploadToS3(file);
    } else {
      // Lưu local server
      fileUrl = `${BASE_URL}/uploads/${file.filename}`;
    }

    let plistUrl = '';
    let installUrl = fileUrl;

    if (isIos) {
      plistUrl = `${BASE_URL}/api/ota/plist/${id}.plist`;
      installUrl = `itms-services://?action=download-manifest&url=${encodeURIComponent(plistUrl)}`;
    }

    // Tạo QR Code
    // Đối với iOS: quét là mở link itms-services để Safari tự động cài
    // Đối với Android: quét là mở trang install hoặc link download trực tiếp
    const webInstallUrl = `${BASE_URL}/ota/${id}`;
    const qrTargetUrl = isIos ? installUrl : webInstallUrl;
    const qrCode = await QRCode.toDataURL(qrTargetUrl);

    // Tính kích thước file
    const sizeBytes = file.size || 0;
    const sizeMb = (sizeBytes / (1024 * 1024)).toFixed(2) + ' MB';

    const appData = {
      id,
      appName,
      version,
      buildNumber,
      bundleId,
      platform,
      fileType,
      environment, // 'dev' | 'beta' | 'prod'
      flavor,      // 'dev' | 'beta' | 'pro'
      message,     // ví dụ: "Gửi bản dev cho @TE_HauTV"
      author,      // ví dụ: "@TE_HauTV"
      branch,      // ví dụ: "develop"
      fileUrl,
      plistUrl,
      installUrl,
      webInstallUrl,
      qrCode,
      sizeBytes,
      sizeMb,
      createdAt: new Date().toISOString()
    };

    const db = getDB();
    db.apps[id] = appData;
    updateDB(db);

    console.log(`✅ [OTA UPLOAD] ${appName} v${version} (${environment.toUpperCase()} / ${platform.toUpperCase()}) - ${message}`);

    res.json({
      success: true,
      data: appData
    });
  } catch (err) {
    console.error("❌ [OTA UPLOAD ERROR]:", err);
    res.status(500).json({ error: err.message });
  }
});

/**
 * Generate manifest.plist cho iOS
 * GET /api/ota/plist/:id.plist
 */
app.get('/api/ota/plist/:id.plist', (req, res) => {
  const { id } = req.params;
  const db = getDB();
  const appData = db.apps[id];

  if (!appData) {
    return res.status(404).send('Không tìm thấy ứng dụng');
  }

  const manifest = {
    items: [
      {
        assets: [
          {
            kind: 'software-package',
            url: appData.fileUrl || appData.ipaUrl
          }
        ],
        metadata: {
          'bundle-identifier': appData.bundleId,
          'bundle-version': appData.version,
          kind: 'software',
          title: appData.appName
        }
      }
    ]
  };

  const xml = plist.build(manifest);
  res.set('Content-Type', 'application/xml');
  res.send(xml);
});

/**
 * Get All Apps List (Hỗ trợ lọc theo environment & platform)
 * GET /api/ota/list?env=dev&platform=ios
 */
app.get('/api/ota/list', (req, res) => {
  const db = getDB();
  let apps = Object.values(db.apps || {}).sort((a, b) => 
    new Date(b.createdAt) - new Date(a.createdAt)
  );

  const { env, platform, flavor } = req.query;
  if (env && env !== 'all') {
    const norm = normalizeEnvironment(env);
    apps = apps.filter(a => a.environment === norm);
  }
  if (platform && platform !== 'all') {
    apps = apps.filter(a => a.platform === platform.toLowerCase());
  }
  if (flavor && flavor !== 'all') {
    apps = apps.filter(a => a.flavor === flavor.toLowerCase());
  }

  res.json(apps);
});

/**
 * Get App Details
 * GET /api/ota/details/:id
 */
app.get('/api/ota/details/:id', (req, res) => {
  const { id } = req.params;
  const db = getDB();
  const appData = db.apps[id];

  if (!appData) {
    return res.status(404).json({ error: 'Không tìm thấy bản build' });
  }

  res.json(appData);
});

/**
 * Delete App
 * DELETE /api/ota/delete/:id
 */
app.delete('/api/ota/delete/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDB();
    const appData = db.apps[id];

    if (!appData) {
      return res.status(404).json({ error: 'Không tìm thấy bản build' });
    }

    const targetUrl = appData.fileUrl || appData.ipaUrl || '';

    // 1. Delete from S3 if applicable
    if (targetUrl.includes('amazonaws.com')) {
      const urlParts = targetUrl.split('.com/');
      const key = urlParts[1];
      if (key) {
        const command = new DeleteObjectCommand({
          Bucket: BUCKET_NAME,
          Key: key,
        });
        await s3Client.send(command).catch(e => console.warn("S3 delete warn:", e.message));
      }
    } else if (targetUrl.includes('/uploads/')) {
      // 2. Delete from local storage if applicable
      const fileName = path.basename(targetUrl);
      const filePath = path.join(UPLOADS_PATH, fileName);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    }

    // 3. Remove from DB
    delete db.apps[id];
    updateDB(db);

    console.log(`🗑️ [OTA DELETE] Đã xóa build: ${id} (${appData.appName})`);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * Serve Dashboard (Upload & Distribution Portal)
 * GET /
 */
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '../web/public/index.html'));
});

/**
 * Serve Mobile Install Landing Page
 * GET /ota/:id
 */
app.get('/ota/:id', (req, res) => {
  res.sendFile(path.join(__dirname, '../web/public/install.html'));
});

app.listen(PORT, () => {
  console.log(`✨ Server OTA đang hoạt động tại: ${BASE_URL}`);
  console.log(`👉 Truy cập Dashboard: ${BASE_URL}`);
});
