#!/bin/bash
#
# Empacota o Uptend.app num DMG (arrastar para Aplicativos).
#
# IMPORTANTE: o DMG gerado é apenas assinado ad-hoc (não notarizado). Em outro Mac,
# o Gatekeeper vai avisar que o app é de "desenvolvedor não identificado". Para
# distribuir de verdade, é preciso assinar com Developer ID e notarizar na Apple
# (veja README.md > Distribuição).
#
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Uptend"
APP_DIR="build/${APP_NAME}.app"
DMG_PATH="build/${APP_NAME}.dmg"
STAGING="build/dmg-staging"

echo "==> Compilando o app..."
./build-app.sh --no-open

echo "==> Montando o DMG..."
rm -rf "${STAGING}" "${DMG_PATH}"
mkdir -p "${STAGING}"
cp -R "${APP_DIR}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING}" \
    -ov -format UDZO \
    "${DMG_PATH}" >/dev/null

rm -rf "${STAGING}"
echo "OK: ${DMG_PATH}"
