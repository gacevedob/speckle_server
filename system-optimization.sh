#!/bin/bash

# Script para optimizar límites del sistema para Speckle con archivos grandes
# Ejecutar como root antes de levantar el docker-compose

echo "🚀 Optimizando sistema para Speckle con archivos grandes..."

# 1. Aumentar límites de archivos abiertos
echo "📁 Configurando límites de archivos abiertos..."

# Crear configuración de límites si no existe
cat >> /etc/security/limits.conf << 'EOF'

# Límites para Speckle - archivos grandes
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
root soft nofile 65536
root hard nofile 65536
EOF

# 2. Configurar límites de systemd
echo "⚙️  Configurando límites de systemd..."
mkdir -p /etc/systemd/system.conf.d/
cat > /etc/systemd/system.conf.d/limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=65536
DefaultLimitNPROC=32768
EOF

# 3. Configurar límites para Docker
echo "🐳 Configurando límites para Docker..."
mkdir -p /etc/systemd/system/docker.service.d/
cat > /etc/systemd/system/docker.service.d/limits.conf << 'EOF'
[Service]
LimitNOFILE=65536
LimitNPROC=32768
EOF

# 4. Optimizar kernel parameters para red
echo "🌐 Optimizando parámetros de red..."
cat >> /etc/sysctl.conf << 'EOF'

# Optimizaciones para Speckle - archivos grandes
# Aumentar buffers de red
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 65536
net.core.wmem_default = 65536
net.ipv4.tcp_rmem = 4096 65536 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# Aumentar número de conexiones
net.core.somaxconn = 65536
net.ipv4.tcp_max_syn_backlog = 8192

# Optimizar reutilización de conexiones
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30

# Aumentar límites de archivos del sistema
fs.file-max = 2097152
fs.nr_open = 1048576

# Optimizar memoria virtual
vm.max_map_count = 262144
vm.swappiness = 10
EOF

# 5. Aplicar cambios de sysctl
echo "💾 Aplicando cambios de kernel..."
sysctl -p

# 6. Crear script de inicio para Docker
echo "📝 Creando script de optimización para Docker..."
cat > /usr/local/bin/optimize-speckle.sh << 'EOF'
#!/bin/bash

# Script que se ejecuta antes de levantar Speckle
echo "🔧 Aplicando optimizaciones de sistema para Speckle..."

# Verificar límites actuales
echo "📊 Límites actuales:"
echo "  - Archivos abiertos: $(ulimit -n)"
echo "  - Procesos: $(ulimit -u)"

# Aumentar límites para la sesión actual
ulimit -n 65536
ulimit -u 32768

# Optimizar parámetros de red específicos para contenedores
echo "🌐 Optimizando red para contenedores..."
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 65536 > /proc/sys/net/core/somaxconn

# Limpiar cache de DNS
echo "🧹 Limpiando cache DNS..."
systemctl flush-dns 2>/dev/null || true

echo "✅ Optimizaciones aplicadas correctamente"
EOF

chmod +x /usr/local/bin/optimize-speckle.sh

# 7. Reiniciar servicios necesarios
echo "🔄 Reiniciando servicios..."
systemctl daemon-reload
systemctl restart docker

echo ""
echo "✅ Configuración completada!"
echo ""
echo "📋 Próximos pasos:"
echo "1. Reinicia el sistema o cierra la sesión SSH y vuelve a conectarte"
echo "2. Ejecuta: /usr/local/bin/optimize-speckle.sh"
echo "3. Verifica los límites con: ulimit -n"
echo "4. Levanta Speckle con: docker-compose up -d"
echo ""
echo "🔍 Comandos útiles para debugging:"
echo "- Verificar límites: ulimit -a"
echo "- Ver archivos abiertos por contenedor: lsof -p \$(docker inspect --format '{{.State.Pid}}' CONTAINER_NAME)"
echo "- Monitorear uso de memoria: docker stats"
echo "- Ver logs de uploads: docker-compose logs -f speckle-server | grep -i upload"
echo ""
