#!/bin/sh
set -e

# Configurar colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones para salida formateada
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar y descargar archivo OSM si es necesario
OSM_FILE="/home/ors/files/chile-latest.osm.pbf"
mkdir -p /home/ors/files

if [ ! -f "${OSM_FILE}" ] || [ "${FORCE_DOWNLOAD}" = "true" ]; then
    info "Descargando archivo OSM desde ${OSM_PBF_URL}..."
    
    if curl -v -L --retry 5 --retry-delay 10 --retry-all-errors --retry-max-time 300 "${OSM_PBF_URL}" -o "${OSM_FILE}"; then
        success "Archivo OSM descargado correctamente"
        chown ors:ors "${OSM_FILE}"
        
        # Verificar tamaño del archivo
        FILE_SIZE=$(stat -c%s "${OSM_FILE}")
        if FORMATTED_SIZE=$(numfmt --to=iec-i --suffix=B ${FILE_SIZE} 2>/dev/null); then
            SIZE_INFO="${FORMATTED_SIZE}"
        else
            SIZE_INFO="$(ls -lh ${OSM_FILE} | awk '{print $5}')"
        fi
        info "Tamaño del archivo: ${SIZE_INFO}"
    else
        error "Error al descargar archivo OSM"
        exit 1
    fi
else
    info "Archivo OSM ya existe, omitiendo descarga"
    info "Para forzar la descarga, establece FORCE_DOWNLOAD=true"
fi

# Ejecutar el comando original de ORS
exec java -jar /ors.jar
