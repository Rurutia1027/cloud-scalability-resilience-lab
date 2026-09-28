#!/bin/sh

cd ../couponservice && mvn -DskipTests package && docker build -t couponservice:local .
cd ../productservice && mvn -DskipTests package && docker build -t productservice:local .


