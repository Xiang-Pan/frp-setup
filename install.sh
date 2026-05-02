#!/usr/bin/env bash
set -e

FRP_VERSION="0.68.1"
FRP_SERVER="xiangpan.asuscomm.com"
FRP_PORT="7000"
LOCAL_PORT="${LOCAL_PORT:-80}"
HOSTNAME="${HOSTNAME:-$(hostname)}"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  armv7l)  ARCH="arm" ;;
  *)       echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

# Install frpc if missing
if ! command -v frpc &>/dev/null; then
  echo "[frpc] Installing frpc v${FRP_VERSION} (${ARCH})..."
  TMP=$(mktemp -d)
  curl -fsSL "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${ARCH}.tar.gz" \
    | tar xz -C "$TMP" --strip-components=1
  sudo mv "$TMP/frpc" /usr/local/bin/frpc
  rm -rf "$TMP"
  echo "[frpc] Installed to /usr/local/bin/frpc"
fi

# Write config
sudo tee /etc/frpc.toml > /dev/null <<EOF
serverAddr = "${FRP_SERVER}"
serverPort = ${FRP_PORT}

[[proxies]]
name = "web"
type = "http"
localPort = ${LOCAL_PORT}
customDomains = ["${HOSTNAME}.xiangpan.org"]
EOF
echo "[frpc] Config: ${HOSTNAME}.xiangpan.org -> localhost:${LOCAL_PORT}"

# Install systemd service
sudo tee /etc/systemd/system/frpc.service > /dev/null <<EOF
[Unit]
Description=FRP Client
After=network.target

[Service]
ExecStart=/usr/local/bin/frpc -c /etc/frpc.toml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now frpc
echo "[frpc] Service enabled and started"
echo "[frpc] Visit: https://${HOSTNAME}.xiangpan.org"
