#!/usr/bin/env bash

set -euo pipefail

echo "==> Preparing Hugo directory"
rm -rf /opt/hugo
mkdir -p /opt/hugo/site/layouts/_default
mkdir -p /opt/hugo/site/content

echo "==> Creating Hugo config"
cat <<EOF > /opt/hugo/site/hugo.toml
baseURL = "https://onwuachi.com/"
languageCode = "en-us"
title = "Onwuachi Platform"
EOF

# Build metadata
PACKER_BUILD_TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
PACKER_AMI_VERSION="phase-3-platform-autoprovision"
GIT_COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo "==> Creating Hugo content"
cat <<EOF > /opt/hugo/site/content/_index.md
---
title: "Onwuachi Platform"
---
EOF

# Default status (will update after build)
BUILD_STATUS="pending"
BUILD_BADGE_COLOR="#6c757d"

echo "==> Creating layout (template)"
cat <<EOF > /opt/hugo/site/layouts/_default/list.html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Onwuachi Platform</title>
<style>
  body {
    font-family: Arial, sans-serif;
    margin: 2rem;
    background: #f4f4f9;
    color: #333;
    transition: all 0.6s ease;
  }
  h1 { color: #007acc; }
  code { background: #eee; padding: 0.2rem 0.4rem; border-radius: 3px; }

  .badge {
    display: inline-block;
    padding: 0.3rem 0.6rem;
    border-radius: 4px;
    color: white;
    font-weight: bold;
    font-size: 0.9rem;
    margin-right: 0.5rem;
  }

  .badge-packer { background-color: #28a745; }
  .badge-commit { background-color: #007bff; }
  .badge-timestamp { background-color: #6c757d; }
  .badge-buildstatus { background-color: $BUILD_BADGE_COLOR; }

  .side-note { font-size:0.85rem; color:#666; margin-top:2rem; }
  .side-note a { color:#007acc; }

  #themeToggle {
    position: fixed;
    top: 1rem;
    right: 1rem;
    padding: 0.5rem 1rem;
    background: #007acc;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
  }
</style>

<script>
function applyTheme(night){
  document.body.style.background = night ? "#1e1e2f" : "#f4f4f9";
  document.body.style.color = night ? "#f5f5f5" : "#333";
}

function initTheme(){
  let hour = new Date().getHours();
  let night = (hour < 6 || hour >= 18);
  let saved = localStorage.getItem("theme");
  if(saved) night = saved === "night";

  applyTheme(night);

  document.getElementById("themeToggle").onclick = () => {
    night = !night;
    localStorage.setItem("theme", night ? "night" : "day");
    applyTheme(night);
  };
}

window.onload = initTheme;
</script>
</head>

<body>
<button id="themeToggle">Toggle Theme</button>

<h1>Onwuachi Platform – Live Immutable Builds</h1>

<p>Stop owning fires 🔥 and start owning modules 🚀</p>

<div>
  <span class="badge badge-packer">Packer: $PACKER_AMI_VERSION</span>
  <span class="badge badge-commit">Commit: $GIT_COMMIT_HASH</span>
  <span class="badge badge-timestamp">Built: $PACKER_BUILD_TIMESTAMP</span>
  <span class="badge badge-buildstatus">Status: $BUILD_STATUS</span>
</div>

<div class="side-note">
  <p><a href="https://github.com/Onwuachi/platform-foundation.git">Platform Repo</a></p>
</div>

<div class="side-note">
  <p>Anime & Culture</p>
  <ul>
    <li><a href="https://myanimelist.net/topanime.php">MyAnimeList</a></li>
    <li><a href="https://www.crunchyroll.com/">Crunchyroll</a></li>
  </ul>
</div>

<div class="side-note">
  <p>News</p>
  <ul>
    <li><a href="https://www.reuters.com/">Reuters</a></li>
    <li><a href="https://www.bbc.com/news">BBC</a></li>
  </ul>
</div>

</body>
</html>
EOF

echo "==> Building Hugo site (FINAL STEP)"
if docker run --rm \
     -v /opt/hugo/site:/site \
     -w /site \
     klakegg/hugo:ext \
     --destination /site/public \
     --minify; then
  BUILD_STATUS="success"
else
  BUILD_STATUS="failure"
fi

echo "==> Hugo build complete: $BUILD_STATUS"