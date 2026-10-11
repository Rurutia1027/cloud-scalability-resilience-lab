#!/bin/sh
# Usage: bin/k6-load.sh http://<node-public-ip>:30090
if [ -z "$1" ]; then
  echo "usage: bin/k6-load.sh http://63.34.7.142:30090" >&2
  exit 1
fi

# curl -sS "http://63.34.7.142:30090/productapi/products"

cd "$(dirname "$0")/.." || exit 1
exec k6 run -e BASE_URL="$1" k6/product.js
