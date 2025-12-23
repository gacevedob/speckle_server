# Speckle + MinIO + Cloudflare Tunnel (docker-compose)

Este stack ejecuta Speckle Server 2.26.8 junto a MinIO, Nginx y servicios auxiliares, detrás de un túnel de Cloudflare que apunta al Nginx del contenedor (`http://127.0.0.1:34355`). El Nginx del host está deshabilitado y no se usa.

## Ejecución rápida

```bash
docker compose up -d
docker compose ps           # todos los servicios deberían estar en running/healthy
```

Puertos: el contenedor `nginx` expone `80` hacia `0.0.0.0:34355`, manteniendo el flujo actual con cloudflared.

## Configuración de MinIO y endpoints S3 (path-style obligado)

Se fuerza `S3_FORCE_PATH_STYLE=true` y `S3_USE_SSL=false` internamente para que Nginx enrute `/speckle-server/...` correctamente. Publicamente se usa `S3_PUBLIC_USE_SSL=true`.

El punto público puede funcionar en dos modos:

### A) Subdominio dedicado (recomendado)
- Define `MINIO_PUBLIC_HOSTNAME=minio.tu-dominio` para que MinIO use ese host (`MINIO_DOMAIN`/`MINIO_SERVER_URL`).
- Establece `S3_PUBLIC_ENDPOINT=https://minio.tu-dominio` en los servicios Speckle.
- `MINIO_BROWSER_REDIRECT_URL` puede apuntar a `https://console.tu-dominio` o similar.

### B) Modo compatibilidad (dominio principal)
- No definas `MINIO_PUBLIC_HOSTNAME`. Se mantiene `S3_PUBLIC_ENDPOINT=https://datificabimcloud.dpdns.org`.
- Se conserva el comportamiento actual de URLs existentes.

### CORS y bucket
- `minio-init` es idempotente: crea el bucket `speckle-server` (o `S3_BUCKET`) si no existe, lo hace público solo cuando `MINIO_SET_PUBLIC=true` y aplica automáticamente `cors.json` (o `cors.xml` si no hay JSON).
- Variables sensibles: `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`.

### Comprobación de CORS

```bash
docker compose run --rm --entrypoint "" minio-init sh -c "\
  mc alias set myminio http://minio:9000 ${MINIO_ROOT_USER:-minioadmin} ${MINIO_ROOT_PASSWORD:-minioadmin} && \
  mc cors list myminio/${S3_BUCKET:-speckle-server}"
```

## Nginx y nombres de host

- `server_name` admite `datificabimcloud.dpdns.org` y, opcionalmente, un catch-all `_`.
- Para habilitar el catch-all solo en entornos de desarrollo, define `NGINX_ENABLE_CATCH_ALL=true` en el servicio `nginx`. Por defecto queda vacío para evitar exponer dominios no previstos en producción.
- Timeouts y buffering extendidos permanecen tal como estaban para cargas grandes.

## Resiliencia (healthchecks y depends_on)

- `speckle-server`, `minio`, `postgres`, `redis`, `fileimport-service`, `speckle-frontend-2` y `nginx` tienen healthchecks.
- `nginx` espera a que `speckle-server`, `speckle-frontend-2` y `minio` estén saludables para reducir 502 en reinicios.

## Validación recomendada

- `docker compose up -d`
- `docker compose ps` (todos healthy o en running estable; si `fileimport-service` emite advertencias por tablas, documentar antes de uso)
- `curl -I http://127.0.0.1:34355` → 302 a `/authn/login`
- `curl -I https://datificabimcloud.dpdns.org` → 302 a `/authn/login` (si se prueba desde el host con DNS válido)
- `docker compose run --rm --entrypoint "" minio-init sh -c "mc alias set myminio http://minio:9000 ${MINIO_ROOT_USER:-minioadmin} ${MINIO_ROOT_PASSWORD:-minioadmin} && mc cors list myminio/${S3_BUCKET:-speckle-server}"`
- `git ls-files --others --exclude-standard | grep -E "(minio-data|postgres-data|redis-data)"` (debe estar vacío para confirmar que los volúmenes no se trackean)

## Troubleshooting rápido

- **502 tras reinicio**: verifica `docker compose ps` y espera a que `speckle-server` y `speckle-frontend-2` estén `healthy`. `nginx` ahora depende de ellos.
- **CORS fallando**: revisa `docker compose logs minio-init` y re-aplica CORS con el comando de comprobación. Asegúrate de que `MINIO_SET_PUBLIC` sea correcto para tu despliegue.
- **WebSockets/GraphQL**: confirma que Cloudflare sigue apuntando a `http://127.0.0.1:34355` y que no hay otro Nginx en el host.

## Notas de migración y rollback

- Se actualizaron las imágenes Speckle a `2.26.8`. Para volver atrás usa `2.26.5` en los servicios Speckle (`speckle-server`, `preview-service`, `webhook-service`, `fileimport-service`) y elimina `S3_FORCE_PATH_STYLE` si prefieres virtual-host style.
- `minio-init` ahora aplica CORS automáticamente; si necesitas desactivarlo, establece `MINIO_SET_PUBLIC=false` y elimina los montajes de `cors.json`/`cors.xml`.
