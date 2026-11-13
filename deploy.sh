#!/usr/bin/env bash
# ==============================================================================
# 🚀 Telso World Automated Server Deployment Script
# Usage: ./deploy.sh
# ==============================================================================
set -e

SERVER_IP="66.116.246.135"
SERVER_USER="root"
SERVER_PASS="Aditya@1992"
REMOTE_APP_DIR="/var/www/telsoworld/app"
LOCAL_SERVER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/server" && pwd)"

echo "---------------------------------------------------------"
echo "🚀 Telso World Deployer: Syncing local 'server/' to $SERVER_IP"
echo "---------------------------------------------------------"

if [ ! -d "$LOCAL_SERVER_DIR" ]; then
  echo "❌ Error: server directory not found at $LOCAL_SERVER_DIR"
  exit 1
fi

# Ensure expect is installed
if ! command -v expect >/dev/null 2>&1; then
  echo "❌ Error: expect tool is required for automated deployment."
  exit 1
fi

echo "📦 1. Packing local server files (excluding node_modules, .env, uploads)..."
TMP_TAR="/tmp/telsoworld_server_deploy.tar.gz"
rm -f "$TMP_TAR"

tar -czf "$TMP_TAR" \
  --exclude="node_modules" \
  --exclude=".env" \
  --exclude=".env.*" \
  --exclude="uploads" \
  --exclude=".DS_Store" \
  -C "$LOCAL_SERVER_DIR" .

echo "📤 2. Uploading archive to server ($SERVER_IP)..."
/usr/bin/expect <<EOF
set timeout 60
spawn scp -o StrictHostKeyChecking=no "$TMP_TAR" ${SERVER_USER}@${SERVER_IP}:/tmp/telsoworld_server_deploy.tar.gz
expect {
  "password:" {
    send "${SERVER_PASS}\r"
    exp_continue
  }
  eof
}
EOF

echo "⚙️  3. Extracting and restarting Telso World backend on server..."
/usr/bin/expect <<EOF
set timeout 90
spawn ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${SERVER_IP} "bash -c '
  set -e
  echo \"Extracting payload to ${REMOTE_APP_DIR}...\"
  mkdir -p ${REMOTE_APP_DIR}/uploads/videos ${REMOTE_APP_DIR}/uploads/thumbnails
  tar -xzf /tmp/telsoworld_server_deploy.tar.gz -C ${REMOTE_APP_DIR}
  rm -f /tmp/telsoworld_server_deploy.tar.gz

  cd ${REMOTE_APP_DIR}
  echo \"Checking npm dependencies...\"
  npm install --production --silent

  echo \"Reloading PM2 process...\"
  pm2 reload telsoworld || pm2 start server.js --name telsoworld
  pm2 save

  echo \"Verifying health...\"
  sleep 2
  curl -s http://127.0.0.1:5050/api/health || true
'"
expect {
  "password:" {
    send "${SERVER_PASS}\r"
    exp_continue
  }
  eof
}
EOF

rm -f "$TMP_TAR"

echo ""
echo "---------------------------------------------------------"
echo "✅ Server deployment complete!"
echo "🌐 Production API: https://telsoworld.com/api/health"
echo "---------------------------------------------------------"

