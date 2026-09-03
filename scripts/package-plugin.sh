#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_DIR="$ROOT_DIR/plugin"
RELEASE_DIR="$ROOT_DIR/release"

mkdir -p "$RELEASE_DIR"

echo "Empacotando plugin Foco DS..."
cd "$PLUGIN_DIR"
zip -r "$RELEASE_DIR/foco-ds-super-productivity.zip" manifest.json plugin.js

echo "Plugin criado com sucesso em: $RELEASE_DIR/foco-ds-super-productivity.zip"
