#!/bin/sh
# Runs on the EC2, as root, after the project tree is in /opt/docker-assignment.
set -eu

cd /opt/docker-assignment
chmod +x bin/measure-baseline.sh bin/scale-watch.sh bin/k6-load.sh bin/bootstrap-remote.sh

docker compose -f docker/docker-compose.yml up -d --build

ready=0
i=0
while [ "$i" -lt 60 ]; do
  if docker run --rm --network docker-assignment_default curlimages/curl:8.11.1 \
    -fsS http://couponservice:9091/actuator/health >/dev/null \
    && docker run --rm --network docker-assignment_default curlimages/curl:8.11.1 \
    -fsS http://productservice:9090/actuator/health >/dev/null
  then
    ready=1
    break
  fi
  i=$((i + 1))
  sleep 10
done

if [ "$ready" -ne 1 ]; then
  echo "services did not become healthy" >&2
  exit 1
fi

seed() {
  code=$1
  discount=$2
  existing=$(docker run --rm --network docker-assignment_default curlimages/curl:8.11.1 \
    -fsS http://couponservice:9091/couponapi/coupons)
  if printf '%s' "$existing" | grep -q "\"code\":\"$code\""; then
    return 0
  fi
  docker run --rm --network docker-assignment_default curlimages/curl:8.11.1 \
    -fsS -X POST http://couponservice:9091/couponapi/coupons \
    -H 'Content-Type: application/json' \
    -d "{\"code\":\"$code\",\"discount\":$discount,\"expDate\":\"2026-12-31\"}"
  echo
}

seed SAVE10 10
seed SAVE20 20

cp deploy/scale-watch.service /etc/systemd/system/scale-watch.service
systemctl daemon-reload
systemctl enable --now scale-watch
