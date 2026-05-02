#!/usr/bin/env bash
set -e

FRP_VERSION="0.68.1"
FRP_SERVER="xiangpan.asuscomm.com"
FRP_PORT="7000"
LOCAL_PORT="${LOCAL_PORT:-$((RANDOM % 55535 + 10000))}"
SSH_PORT=$((RANDOM % 10000 + 20000))
SHORT_HOST=$(hostname | cut -d. -f1)

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
  mkdir -p ~/.local/bin
  TMP=$(mktemp -d)
  curl -fsSL "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${ARCH}.tar.gz" \
    | tar xz -C "$TMP" --strip-components=1
  mv "$TMP/frpc" ~/.local/bin/frpc
  rm -rf "$TMP"
  echo "[frpc] Installed to ~/.local/bin/frpc"
fi

# Write config
mkdir -p ~/.config/frp
cat > ~/.config/frp/frpc.toml <<EOF
serverAddr = "${FRP_SERVER}"
serverPort = ${FRP_PORT}

[[proxies]]
name = "web"
type = "http"
localPort = ${LOCAL_PORT}
customDomains = ["${SHORT_HOST}.xiangpan.org"]

[[proxies]]
name = "ssh"
type = "tcp"
localPort = 22
remotePort = ${SSH_PORT}
EOF
echo "[frpc] HTTP: ${SHORT_HOST}.xiangpan.org -> localhost:${LOCAL_PORT}"
echo "[frpc] SSH:  ssh -p ${SSH_PORT} \$USER@${FRP_SERVER}"

# Run in background
pkill -f "frpc -c $HOME/.config/frp/frpc.toml" 2>/dev/null || true
nohup ~/.local/bin/frpc -c ~/.config/frp/frpc.toml > ~/.config/frp/frpc.log 2>&1 &
echo "[frpc] Started (PID $!), log: ~/.config/frp/frpc.log"
echo "[frpc] Visit: https://${SHORT_HOST}.xiangpan.org"
echo "[frpc] Local port: ${LOCAL_PORT}"
