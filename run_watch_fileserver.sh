#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <pasta>"
  echo "Exemplo: $0 ./public"
  exit 1
fi

TARGET_DIR="$1"

echo "[watch-runner] iniciando monitoramento de: ${TARGET_DIR}"
echo "[watch-runner] logs aparecerão no terminal abaixo"

zig run watch_fileserver.zig -- "${TARGET_DIR}"
