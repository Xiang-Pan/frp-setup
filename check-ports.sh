#!/usr/bin/env bash
HOST="${1:-xiangpan.asuscomm.com}"
PORTS=(22 80 443 7000 7001 8080 8443 9000 10000)

echo "Checking outbound ports to $HOST..."
for port in "${PORTS[@]}"; do
  if timeout 3 bash -c ">/dev/tcp/$HOST/$port" 2>/dev/null; then
    echo "  OPEN   $port"
  else
    echo "  CLOSED $port"
  fi
done
