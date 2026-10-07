#!/bin/sh 

curl -sS http://localhost:9091/actuator/health

curl -sS http://localhost:9090/actuator/health

curl -sS -X POST http://localhost:9091/couponapi/coupons \
  -H 'Content-Type: application/json' \
  -d '{"code":"SAVE10","discount":10,"expDate":"2026-12-31"}'

curl -sS -X POST http://localhost:9091/couponapi/coupons \
  -H 'Content-Type: application/json' \
  -d '{"code":"SAVE20","discount":20,"expDate":"2026-12-31"}'

curl -sS http://localhost:9091/couponapi/coupons/SAVE10

curl -sS -X POST http://localhost:9090/productapi/products \
  -H 'Content-Type: application/json' \
  -d '{"name":"notebook","description":"lab item","price":100,"couponCode":"SAVE10"}'

curl -sS -X POST http://localhost:9090/productapi/products \
  -H 'Content-Type: application/json' \
  -d '{"name":"mouse","description":"lab item","price":50,"couponCode":"SAVE20"}'

curl -sS http://localhost:9091/couponapi/coupons

curl -sS http://localhost:9090/productapi/products
