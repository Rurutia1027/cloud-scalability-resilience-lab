#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
# Same tag CodeBuild uses: first 7 characters of the commit.
IMAGE_TAG=$(git -C "$ROOT" rev-parse HEAD | cut -c 1-7)

cd "$ROOT/couponservice"
mvn -B -DskipTests package
docker build \
  -t "couponservice:${IMAGE_TAG}" \
  -t couponservice:local \
  .

cd "$ROOT/productservice"
mvn -B -DskipTests package
docker build \
  -t "productservice:${IMAGE_TAG}" \
  -t productservice:local \
  .

echo "couponservice:${IMAGE_TAG}"
echo "productservice:${IMAGE_TAG}"
