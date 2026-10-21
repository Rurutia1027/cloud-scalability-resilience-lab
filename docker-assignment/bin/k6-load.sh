#!/bin/sh
# Usage: bin/k6-load.sh http://<ec2-public-ip>:9090
if [ -z "$1" ]; then
  echo "usage: bin/k6-load.sh http://<ec2-public-ip>:9090" >&2
  exit 1
fi

cd "$(dirname "$0")/.." || exit 1
exec k6 run -e BASE_URL="$1" k6/product.js
