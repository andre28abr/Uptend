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
TMP_DMG="build/${APP_NAME}-tmp.dmg"
MOUNT="/Volumes/${APP_NAME}"
rm -rf "${STAGING}" "${DMG_PATH}" "${TMP_DMG}"
mkdir -p "${STAGING}"
cp -R "${APP_DIR}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"

# Ícone do próprio volume (o DMG no Finder).
if [[ -f "Resources/${APP_NAME}.icns" ]]; then
    cp "Resources/${APP_NAME}.icns" "${STAGING}/.VolumeIcon.icns"
fi

# Cria como read-write, marca o atributo de ícone customizado e converte para comprimido.
hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGING}" -ov -format UDRW "${TMP_DMG}" >/dev/null
DEV="$(hdiutil attach "${TMP_DMG}" -nobrowse -noautoopen | grep '/Volumes/' | awk '{print $1}')"
if command -v SetFile >/dev/null 2>&1; then
    SetFile -a C "${MOUNT}" 2>/dev/null || true
fi
hdiutil detach "${DEV}" >/dev/null 2>&1 || true
hdiutil convert "${TMP_DMG}" -format UDZO -o "${DMG_PATH}" >/dev/null
rm -f "${TMP_DMG}"
rm -rf "${STAGING}"
echo "OK: ${DMG_PATH}"
