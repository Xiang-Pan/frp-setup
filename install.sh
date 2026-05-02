#!/usr/bin/env bash
set -e

FRP_VERSION="0.68.1"
FRP_SERVER="xiangpan.asuscomm.com"
FRP_PORT="7000"
SHORT_HOST=$(hostname | cut -d. -f1)
CONFIG=~/.config/frp/frpc.toml

# Reuse existing ports if config already exists
if [[ -f "$CONFIG" ]]; then
  LOCAL_PORT=$(grep -A2 'name = "web"' "$CONFIG" | grep localPort | grep -o '[0-9]*' || true)
  SSH_PORT=$(grep -A2 'name = "ssh"' "$CONFIG" | grep remotePort | grep -o '[0-9]*' || true)
fi
LOCAL_PORT="${LOCAL_PORT:-$((RANDOM % 55535 + 10000))}"
SSH_PORT="${SSH_PORT:-$((RANDOM % 10000 + 20000))}"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  armv7l)  ARCH="arm" ;;
  *)       echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

# Install frpc if missing
FRPC=$(command -v frpc 2>/dev/null || echo "")
if [[ -z "$FRPC" ]]; then
  FRPC=~/.local/bin/frpc
  if [[ ! -f "$FRPC" ]]; then
    echo "[frpc] Installing frpc v${FRP_VERSION} (${ARCH})..."
    mkdir -p ~/.local/bin
    TMP=$(mktemp -d)
    curl -fsSL "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${ARCH}.tar.gz" \
      | tar xz -C "$TMP" --strip-components=1
    mv "$TMP/frpc" "$FRPC"
    rm -rf "$TMP"
    echo "[frpc] Installed to $FRPC"
  fi
fi
echo "[frpc] Using $FRPC"

# Write config
mkdir -p ~/.config/frp
cat > "$CONFIG" <<EOF
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

# Run in background
pkill -f "frpc -c $HOME/.config/frp/frpc.toml" 2>/dev/null || true
nohup "$FRPC" -c "$CONFIG" > ~/.config/frp/frpc.log 2>&1 &
sleep 1

echo ""
echo "  Web : https://${SHORT_HOST}.xiangpan.org  (local port ${LOCAL_PORT})"
echo "  SSH : ssh -p ${SSH_PORT} ${USER}@${FRP_SERVER}"
echo "  Log : ~/.config/frp/frpc.log"
echo ""
