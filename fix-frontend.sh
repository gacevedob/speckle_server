#!/bin/bash
# Este script arregla la sección speckle-frontend-2
sed -i '/speckle-frontend-2:/a\    build:\n      context: .\n      dockerfile: Dockerfile.frontend\n    restart: always\n    mem_limit: 512m\n    environment:' docker-compose.yml
