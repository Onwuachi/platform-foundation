#!/bin/bash
set -euo pipefail

./scripts/ensure-sso.sh

cd apps/hugo/service
hugo --minify --gc
docker build -t hugo .
docker tag hugo 046685909731.dkr.ecr.us-east-1.amazonaws.com/hugo:latest
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 046685909731.dkr.ecr.us-east-1.amazonaws.com
docker push 046685909731.dkr.ecr.us-east-1.amazonaws.com/hugo:latest

cd ../../..
platform refresh hugo
