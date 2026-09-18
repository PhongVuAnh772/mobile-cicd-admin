/* ==========================================================================
   Internal App Distribution Web Portal - Application Logic (app.js)
   Clean Dynamic Data Driven Version
   ========================================================================== */

let buildsData = null;
let currentAppId = "cryptovault";
let currentPlatform = "android";
let currentEnv = "production";
let currentBuildId = "";
let qrcodeInstance = null;

// Initialize Application
document.addEventListener("DOMContentLoaded", () => {
  initDrawer();
  loadData();
});

// Sidebar Drawer Collapse / Expand & Search
function initDrawer() {
  const toggleBtn = document.getElementById("toggleDrawerBtn");
  const sidebar = document.getElementById("sidebar");

  if (toggleBtn && sidebar) {
    toggleBtn.addEventListener("click", () => {
      sidebar.classList.toggle("collapsed");
    });
  }

  const searchInput = document.getElementById("searchInput");
  if (searchInput) {
    searchInput.addEventListener("input", (e) => {
      filterTreeView(e.target.value.toLowerCase());
    });
  }
}

// Load Real Data from builds.json
async function loadData() {
  try {
    const res = await fetch(`builds.json?v=${Date.now()}`);
    if (!res.ok) throw new Error("Could not load builds.json");
    buildsData = await res.json();
  } catch (e) {
    console.error("Error loading builds.json:", e);
    document.getElementById("treeView").innerHTML = `
      <div style="padding: 20px; color: #9CA3AF; font-size: 0.85rem; text-align: center;">
        Chưa có dữ liệu bản build.<br>Hệ thống CI/CD sẽ tự động cập nhật.
      </div>
    `;
    return;
  }

  renderTreeView();

  // Find first available app and build
  if (buildsData && buildsData.apps && buildsData.apps.length > 0) {
    const firstApp = buildsData.apps[0];
    currentAppId = firstApp.id;

    // Find first platform with builds
    const platforms = ["android", "ios"];
    const envs = ["production", "staging", "development"];
    let foundBuild = false;

    for (const p of platforms) {
      if (firstApp.platforms && firstApp.platforms[p]) {
        for (const e of envs) {
          const list = firstApp.platforms[p].environments[e] || [];
          if (list.length > 0) {
            currentPlatform = p;
            currentEnv = e;
            currentBuildId = list[0].id;
            foundBuild = true;
            break;
          }
        }
      }
      if (foundBuild) break;
    }

    selectBuild(currentAppId, currentPlatform, currentEnv, currentBuildId);
  }
}

// Render 4-Level Dynamic Tree View in Drawer
function renderTreeView() {
  const container = document.getElementById("treeView");
  container.innerHTML = "";

  if (!buildsData || !buildsData.apps || buildsData.apps.length === 0) {
    container.innerHTML = `<div style="padding: 16px; color: #9CA3AF; font-size: 0.84rem;">Chưa có bản build nào.</div>`;
    return;
  }

  const rootUl = document.createElement("ul");
  rootUl.className = "tree-root";

  buildsData.apps.forEach((app) => {
    const appLi = document.createElement("li");
    appLi.className = "tree-node";

    const appContent = document.createElement("div");
    appContent.className = "tree-content";
    appContent.innerHTML = `
      <span class="tree-toggle expanded">▶</span>
      <span class="tree-icon">📁</span>
      <span style="font-weight: 600;">${app.name}</span>
    `;

    const appChildrenUl = document.createElement("ul");
    appChildrenUl.className = "tree-children open";

    appContent.querySelector(".tree-toggle").addEventListener("click", (e) => {
      e.stopPropagation();
      appChildrenUl.classList.toggle("open");
      e.target.classList.toggle("expanded");
    });

    if (app.platforms) {
      Object.keys(app.platforms).forEach((platformKey) => {
        const platformObj = app.platforms[platformKey];
        const platformLi = document.createElement("li");
        platformLi.className = "tree-node";

        const osIcon = platformKey === "android" ? "🤖" : "";
        const osLabel = platformKey === "android" ? "Android" : "iOS";

        const platformContent = document.createElement("div");
        platformContent.className = "tree-content";
        platformContent.innerHTML = `
          <span class="tree-toggle expanded">▶</span>
          <span class="tree-icon">${osIcon}</span>
          <span>${osLabel}</span>
        `;

        const platformChildrenUl = document.createElement("ul");
        platformChildrenUl.className = "tree-children open";

        platformContent.querySelector(".tree-toggle").addEventListener("click", (e) => {
          e.stopPropagation();
          platformChildrenUl.classList.toggle("open");
          e.target.classList.toggle("expanded");
        });

        if (platformObj.environments) {
          Object.keys(platformObj.environments).forEach((envKey) => {
            const buildsList = platformObj.environments[envKey] || [];

            const envLi = document.createElement("li");
            envLi.className = "tree-node";

            const envLabel = envKey.charAt(0).toUpperCase() + envKey.slice(1);
            const envIcon = envKey === "production" ? "🚀" : envKey === "staging" ? "🧪" : "🛠️";

            const envContent = document.createElement("div");
            envContent.className = "tree-content";
            envContent.innerHTML = `
              <span class="tree-toggle expanded">▶</span>
              <span class="tree-icon">${envIcon}</span>
              <span>${envLabel}</span>
              <span class="node-badge">${buildsList.length}</span>
            `;

            const envChildrenUl = document.createElement("ul");
            envChildrenUl.className = "tree-children open";

            envContent.querySelector(".tree-toggle").addEventListener("click", (e) => {
              e.stopPropagation();
              envChildrenUl.classList.toggle("open");
              e.target.classList.toggle("expanded");
            });

            if (buildsList.length > 0) {
              buildsList.forEach((build) => {
                const versionLi = document.createElement("li");
                versionLi.className = "tree-node";

                const versionContent = document.createElement("div");
                versionContent.className = "tree-content";
                versionContent.id = `tree-node-${build.id}`;
                versionContent.innerHTML = `
                  <span class="tree-icon">📄</span>
                  <span>v${build.version} (${build.buildNumber})</span>
                `;

                versionContent.addEventListener("click", () => {
                  selectBuild(app.id, platformKey, envKey, build.id);
                });

                versionLi.appendChild(versionContent);
                envChildrenUl.appendChild(versionLi);
              });
            } else {
              const emptyLi = document.createElement("li");
              emptyLi.className = "tree-node";
              emptyLi.innerHTML = `
                <div class="tree-content" style="color: #9CA3AF; font-size: 0.8rem; cursor: default;">
                  <span class="tree-icon">•</span>
                  <span>Trống</span>
                </div>
              `;
              envChildrenUl.appendChild(emptyLi);
            }

            envLi.appendChild(envContent);
            envLi.appendChild(envChildrenUl);
            platformChildrenUl.appendChild(envLi);
          });
        }

        platformLi.appendChild(platformContent);
        platformLi.appendChild(platformChildrenUl);
        appChildrenUl.appendChild(platformLi);
      });
    }

    appLi.appendChild(appContent);
    appLi.appendChild(appChildrenUl);
    rootUl.appendChild(appLi);
  });

  container.appendChild(rootUl);
}

// Select Build & Update Main Hero + History (Dynamic Only)
function selectBuild(appId, platform, env, buildId) {
  currentAppId = appId;
  currentPlatform = platform;
  currentEnv = env;

  const app = buildsData.apps.find((a) => a.id === appId);
  if (!app) return;

  const envBuilds = app.platforms[platform]?.environments[env] || [];
  let build = envBuilds.find((b) => b.id === buildId);
  if (!build && envBuilds.length > 0) {
    build = envBuilds[0];
  }

  // Update Active Node Highlight
  document.querySelectorAll(".tree-content").forEach((el) => el.classList.remove("active"));
  if (build) {
    const activeNode = document.getElementById(`tree-node-${build.id}`);
    if (activeNode) activeNode.classList.add("active");
  }

  // Update Breadcrumbs
  const osLabel = platform === "android" ? "🤖 Android" : " iOS";
  const envLabel = env.charAt(0).toUpperCase() + env.slice(1);
  document.getElementById("breadcrumbs").innerHTML = `
    <span>${app.name}</span> / ${osLabel} / ${envLabel} ${build ? `/ v${build.version}` : ""}
  `;

  const heroContainer = document.getElementById("heroCard");
  const historyList = document.getElementById("historyList");

  if (!build) {
    // Empty State for platform/env with no builds
    document.getElementById("heroAppIcon").src = app.icon || "assets/images/icon_app.png";
    document.getElementById("heroAppTitle").textContent = app.name.toUpperCase();
    document.getElementById("heroMetaPill").textContent = `${envLabel} - Chưa có bản build nào`;
    document.getElementById("heroUploadDate").innerHTML = `${osLabel} Upload Date: N/A`;

    document.getElementById("qrcodeCanvas").innerHTML = `
      <div style="width: 150px; height: 150px; display: flex; align-items: center; justify-content: center; background: #F3F4F6; border-radius: 8px; color: #9CA3AF; font-size: 0.8rem;">
        No QR Code
      </div>
    `;

    const downloadBtn = document.getElementById("heroDownloadBtn");
    downloadBtn.href = "#";
    downloadBtn.style.opacity = "0.5";
    downloadBtn.style.pointerEvents = "none";
    downloadBtn.textContent = "Chưa có bản build";

    historyList.innerHTML = `<div style="text-align: center; padding: 30px; color: #9CA3AF; font-size: 0.88rem;">Chưa có lịch sử bản build nào cho môi trường này.</div>`;
    document.getElementById("historyCountBadge").textContent = "0 bản build";
    return;
  }

  currentBuildId = build.id;

  // Render Hero Area
  document.getElementById("heroAppIcon").src = app.icon || "assets/images/icon_app.png";
  document.getElementById("heroAppTitle").textContent = app.name.toUpperCase();
  document.getElementById("heroMetaPill").textContent = `${build.stage || envLabel} - ${build.version}(Build ${build.buildNumber}) - ${build.fileSize}`;

  const osSymbol = platform === "android" ? "🤖" : "";
  document.getElementById("heroUploadDate").innerHTML = `
    ${osSymbol} Upload Date: ${build.timeAgo} | ${build.formattedDate}
    <span class="delete-link" onclick="handleDeleteBuild('${build.id}')">Delete</span>
  `;

  // Generate Dynamic QR Code
  generateQRCode(build, platform);

  // Set Download CTA Button
  const downloadBtn = document.getElementById("heroDownloadBtn");
  downloadBtn.style.opacity = "1";
  downloadBtn.style.pointerEvents = "auto";
  downloadBtn.textContent = "Download and Install";

  if (platform === "ios" && build.manifestUrl) {
    downloadBtn.href = `itms-services://?action=download-manifest&url=${encodeURIComponent(build.manifestUrl)}`;
  } else {
    downloadBtn.href = build.downloadUrl || "#";
  }

  // Render Build History List
  renderHistoryList(envBuilds, app, platform);
}

// Generate Dynamic QR Code Box
function generateQRCode(build, platform) {
  const qrContainer = document.getElementById("qrcodeCanvas");
  qrContainer.innerHTML = "";

  let targetUrl = build.downloadUrl || window.location.href;
  if (platform === "ios" && build.manifestUrl) {
    targetUrl = `itms-services://?action=download-manifest&url=${encodeURIComponent(build.manifestUrl)}`;
  }

  if (typeof QRCode !== "undefined") {
    qrcodeInstance = new QRCode(qrContainer, {
      text: targetUrl,
      width: 150,
      height: 150,
      colorDark: "#000000",
      colorLight: "#ffffff",
      correctLevel: QRCode.CorrectLevel.M
    });
  } else {
    qrContainer.innerHTML = `<img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(targetUrl)}" alt="QR Code">`;
  }
}

// Render History Items
function renderHistoryList(builds, app, platform) {
  const historyList = document.getElementById("historyList");
  historyList.innerHTML = "";

  document.getElementById("historyCountBadge").textContent = `${builds.length} bản build`;

  const osSymbol = platform === "android" ? "🤖" : "";

  builds.forEach((build) => {
    const isSelected = build.id === currentBuildId;

    const item = document.createElement("div");
    item.className = `history-item ${isSelected ? "selected" : ""}`;

    item.innerHTML = `
      <div class="history-item-left">
        <img src="${app.icon || 'assets/images/icon_app.png'}" class="history-app-icon" alt="icon">
        <div class="history-info">
          <div class="history-title-row">
            <span class="history-os-icon">${osSymbol}</span>
            <span>${app.name}</span>
          </div>
          <div class="history-subtext">
            ${build.version}(Build ${build.buildNumber})
          </div>
          <div class="history-subtext">
            Upload Date: ${build.timeAgo} | ${build.formattedDate}
          </div>
        </div>
      </div>

      <div class="history-item-right">
        <input type="checkbox" class="checkbox-select" ${isSelected ? "checked" : ""}>
        <a href="${build.downloadUrl}" class="btn-icon-download" title="Tải xuống bản build này" target="_blank" onclick="event.stopPropagation()">
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
        </a>
      </div>
    `;

    item.addEventListener("click", () => {
      selectBuild(app.id, platform, currentEnv, build.id);
    });

    historyList.appendChild(item);
  });
}

// Delete Build Handler
function handleDeleteBuild(buildId) {
  if (confirm(`Bạn có chắc chắn muốn xóa bản build ID: ${buildId} khỏi hệ thống không?`)) {
    showToast(`Đã gửi yêu cầu xóa bản build ${buildId}.`);
  }
}

// Search Filter in Tree View
function filterTreeView(query) {
  const nodes = document.querySelectorAll("#treeView .tree-content");
  nodes.forEach((node) => {
    const text = node.textContent.toLowerCase();
    if (text.includes(query)) {
      node.style.display = "flex";
    } else {
      node.style.display = query === "" ? "flex" : "none";
    }
  });
}

// Toast Notification
function showToast(message) {
  const toast = document.getElementById("toast");
  toast.textContent = message;
  toast.classList.add("show");
  setTimeout(() => toast.classList.remove("show"), 3500);
}
