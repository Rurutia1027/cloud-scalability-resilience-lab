#!/bin/sh

docker network create lab 
docker rm -f couponservice productservice

docker run -d --name couponservice --network lab -p 9091:9091 \
  -e SPRING_DATASOURCE_URL=jdbc:mysql://host.docker.internal:3306/servicedb \
  -e SPRING_DATASOURCE_USERNAME=root \
  -e SPRING_DATASOURCE_PASSWORD= \
  couponservice:local

docker run -d --name productservice --network lab -p 9090:9090 \
  -e SPRING_DATASOURCE_URL=jdbc:mysql://host.docker.internal:3306/servicedb \
  -e SPRING_DATASOURCE_USERNAME=root \
  -e SPRING_DATASOURCE_PASSWORD= \
  -e COUPON_SERVICE_URL=http://couponservice:9091/couponapi/coupons/ \
  productservice:local

