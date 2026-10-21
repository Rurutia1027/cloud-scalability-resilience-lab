#!/bin/sh
# Sample the single replica of each service for the length of a k6 run,
# then write scale/thresholds.env. bin/scale-watch.sh treats those CPU
# peaks as the scale-up lines.
#
# On the instance:
#   bin/measure-baseline.sh
# From the laptop, during that window:
#   bin/k6-load.sh http://<public-ip>:9090
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
DURATION=${1:-110}
PAUSE="$ROOT/scale/pause"
OUT="$ROOT/scale/thresholds.env"
PROJECT=docker-assignment
log=$(mktemp)

if [ "$(id -u)" -eq 0 ]; then
  DOCKER=docker
else
  DOCKER="sudo docker"
fi

mkdir -p "$ROOT/scale"
trap 'rm -f "$PAUSE" "$log"' EXIT INT TERM
: >"$PAUSE"

echo "Scaling is paused. Sampling for ${DURATION}s."
echo "From the laptop, run: bin/k6-load.sh http://<public-ip>:9090"

end=$(( $(date +%s) + DURATION ))
while [ "$(date +%s)" -lt "$end" ]; do
  $DOCKER stats --no-stream --format '{{.Name}} {{.CPUPerc}} {{.MemUsage}}' \
    | awk -v project="$PROJECT" '
        index($1, project "-") != 1 { next }
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
        printf "%s %.2f %.0f\n", $1, cpu, mib
      ' >>"$log" || true
  sleep 5
done

tmp=$(mktemp)
if awk -v project="$PROJECT" '
  index($1, project "-productservice-") == 1 {
    if ($2 > product_cpu) product_cpu = $2
    if ($3 > product_mem) product_mem = $3
    product_n++
  }
  index($1, project "-couponservice-") == 1 {
    if ($2 > coupon_cpu) coupon_cpu = $2
    if ($3 > coupon_mem) coupon_mem = $3
    coupon_n++
  }
  END {
    if (product_n == 0 || coupon_n == 0) exit 1
    printf "PRODUCT_CPU_PERCENT=%.2f\n", product_cpu
    printf "PRODUCT_MEMORY_MIB=%.0f\n", product_mem
    printf "COUPON_CPU_PERCENT=%.2f\n", coupon_cpu
    printf "COUPON_MEMORY_MIB=%.0f\n", coupon_mem
  }
' "$log" >"$tmp"; then
  mv "$tmp" "$OUT"
else
  rm -f "$tmp"
  echo "No running productservice or couponservice samples. Start the compose stack first." >&2
  exit 1
fi

echo "Wrote $OUT"
cat "$OUT"
