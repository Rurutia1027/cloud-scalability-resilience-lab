#!/bin/sh
# Every 15 seconds, compare each service's average CPU with the peaks in
# scale/thresholds.env. Above the peak, add at most 2 replicas, stop at 4.
# Below the peak for 120 seconds, remove one, stop at 1.
# If free memory cannot hold another 512MiB reservation, leave it unstarted.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
COMPOSE="$ROOT/docker/docker-compose.yml"
THRESHOLDS="$ROOT/scale/thresholds.env"
PAUSE="$ROOT/scale/pause"
STATE="$ROOT/scale/state"
PROJECT=docker-assignment
MIN=1
MAX=4
STEP=2
INTERVAL=15
SCALE_DOWN_SECONDS=120
RESERVE_MIB=512

if [ "$(id -u)" -eq 0 ]; then
  DOCKER=docker
else
  DOCKER="sudo docker"
fi

mkdir -p "$ROOT/scale"
touch "$STATE"

below_since() {
  awk -F= -v key="$1" '$1 == key { print $2 }' "$STATE" | tail -1
}

set_below_since() {
  tmp=$(mktemp)
  awk -F= -v key="$1" '$1 != key { print }' "$STATE" >"$tmp"
  if [ -n "${2:-}" ]; then
    printf '%s=%s\n' "$1" "$2" >>"$tmp"
  fi
  mv "$tmp" "$STATE"
}

replica_count() {
  $DOCKER stats --no-stream --format '{{.Name}}' \
    | awk -v prefix="${PROJECT}-$1-" 'index($0, prefix) == 1 { n++ } END { print n + 0 }'
}

average_cpu() {
  $DOCKER stats --no-stream --format '{{.Name}} {{.CPUPerc}} {{.MemUsage}}' \
    | awk -v prefix="${PROJECT}-$1-" '
        index($1, prefix) != 1 { next }
        cpu = $2
        gsub(/%/, "", cpu)
        mem = $3
        unit = mem
        gsub(/[0-9.]/, "", unit)
        value = mem
        gsub(/[^0-9.]/, "", value)
        mib = value + 0
        if (unit ~ /GiB/) mib = value * 1024
        if (unit ~ /KiB/) mib = value / 1024
        if ((cpu + 0) == 0 && mib < 50) next
        n++
        sum += cpu
        END { if (n > 0) printf "%.2f", sum / n }
      '
}

available_mib() {
  awk '/MemAvailable/ { printf "%d", $2 / 1024 }' /proc/meminfo
}

scale_to() {
  # shellcheck disable=SC2086
  $DOCKER compose -f "$COMPOSE" up -d --no-recreate --no-build \
    --scale "productservice=$1" \
    --scale "couponservice=$2"
}

while true; do
  if [ -f "$PAUSE" ] || [ ! -f "$THRESHOLDS" ]; then
    sleep "$INTERVAL"
    continue
  fi

  # shellcheck disable=SC1090
  . "$THRESHOLDS"
  if [ -z "${PRODUCT_CPU_PERCENT:-}" ] || [ -z "${COUPON_CPU_PERCENT:-}" ]; then
    sleep "$INTERVAL"
    continue
  fi

  product_count=$(replica_count productservice)
  coupon_count=$(replica_count couponservice)
  now=$(date +%s)
  free=$(available_mib)
  next_product=$product_count
  next_coupon=$coupon_count

  decide() {
    name=$1
    count=$2
    threshold=$3
    key=$4
    cpu=$(average_cpu "$name" || true)
    if [ -z "$cpu" ]; then
      return 0
    fi
    since=$(below_since "$key" || true)
    if awk -v cpu="$cpu" -v threshold="$threshold" 'BEGIN { exit !(cpu > threshold) }'; then
      set_below_since "$key" ""
      if [ "$count" -ge "$MAX" ]; then
        return 0
      fi
      want=$((count + STEP))
      if [ "$want" -gt "$MAX" ]; then
        want=$MAX
      fi
      need=$(((want - count) * RESERVE_MIB))
      if [ "$free" -lt "$need" ]; then
        echo "$name cpu ${cpu}% > ${threshold}% but ${free}MiB free, next replica stays unstarted"
        return 0
      fi
      echo "$name cpu ${cpu}% > ${threshold}%, scale $count -> $want"
      if [ "$name" = "productservice" ]; then
        next_product=$want
      else
        next_coupon=$want
      fi
      free=$((free - need))
      return 0
    fi
    if [ -z "$since" ]; then
      set_below_since "$key" "$now"
      return 0
    fi
    if [ $((now - since)) -ge "$SCALE_DOWN_SECONDS" ] && [ "$count" -gt "$MIN" ]; then
      echo "$name cpu ${cpu}% <= ${threshold}% for ${SCALE_DOWN_SECONDS}s, scale $count -> $((count - 1))"
      if [ "$name" = "productservice" ]; then
        next_product=$((count - 1))
      else
        next_coupon=$((count - 1))
      fi
      set_below_since "$key" "$now"
    fi
  }

  decide productservice "$product_count" "$PRODUCT_CPU_PERCENT" product_below
  decide couponservice "$coupon_count" "$COUPON_CPU_PERCENT" coupon_below

  if [ "$next_product" != "$product_count" ] || [ "$next_coupon" != "$coupon_count" ]; then
    scale_to "$next_product" "$next_coupon"
  fi

  sleep "$INTERVAL"
done
