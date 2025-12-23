#!/bin/bash

echo "🔍 DIAGNÓSTICO SIMPLIFICADO SPECKLE S3"
echo "======================================"

# 1. Verificar que todos los contenedores estén corriendo
echo "1. Estado de contenedores:"
docker-compose ps --format table

echo ""
echo "2. Verificando conectividad MinIO externa:"
curl -v -I https://datificabimcloud.dpdns.org/minio/ 2>&1 | grep -E "(HTTP|< |> )"

echo ""
echo "3. Logs de MinIO (últimas 10 líneas):"
docker-compose logs --tail=10 minio

echo ""
echo "4. Logs de create-bucket (configuración CORS):"
docker-compose logs create-bucket | grep -E "(CORS|ERROR|cors)"

echo ""
echo "5. Variables S3 en Speckle Server:"
docker-compose exec -T speckle-server /bin/sh -c 'env | grep S3' 2>/dev/null || echo "Error accediendo al contenedor"

echo ""
echo "6. Test CORS directo:"
curl -v -X OPTIONS \
  -H "Origin: https://datificabimcloud.dpdns.org" \
  -H "Access-Control-Request-Method: PUT" \
  https://datificabimcloud.dpdns.org/minio/speckle-server/ 2>&1 | grep -E "(Access-Control|< |> )"

echo ""
echo "7. Verificar archivo cors.json:"
if [ -f "cors.json" ]; then
    echo "✅ cors.json existe"
    cat cors.json | head -5
else
    echo "❌ cors.json NO EXISTE - CRÍTICO"
fi

echo ""
echo "8. Test básico bucket público:"
curl -s -I https://datificabimcloud.dpdns.org/minio/speckle-server/ | head -3
