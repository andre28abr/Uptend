#!/bin/bash
#
# Compila o Uptend e monta um Uptend.app para rodar localmente.
# NÃO gera DMG — apenas o .app, que você pode abrir com duplo-clique.
#
# Uso:
#   ./build-app.sh            # compila em release e abre o app (de build/)
#   ./build-app.sh --debug    # compila em debug (mais rápido)
#   ./build-app.sh --install  # além de compilar, atualiza /Applications/Uptend.app
#
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="release"
OPEN_APP=1
INSTALL=0
for arg in "$@"; do
    case "$arg" in
        --debug) CONFIG="debug" ;;
        --no-open) OPEN_APP=0 ;;
        --install) INSTALL=1 ;;
    esac
done

APP_NAME="Uptend"
APP_DIR="build/${APP_NAME}.app"

echo "==> Compilando (${CONFIG})..."
swift build -c "${CONFIG}"

BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)/${APP_NAME}"

echo "==> Montando ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Ícone do app. Preferência: o formato novo (.icon / Liquid Glass, macOS 26+),
# compilado pelo actool — nele a aparência escura é derivada do NOSSO fundo azul,
# em vez do preto genérico que o sistema aplica a ícones .icns legados no tema
# escuro. O actool também gera o Uptend.icns de fallback para macOS anteriores.
# Sem actool/Xcode 26, cai no .icns legado do repositório.
ICON_ASSETS=0
if [[ -d "Resources/${APP_NAME}.icon" ]] && xcrun --find actool >/dev/null 2>&1; then
    echo "==> Compilando o ícone (Liquid Glass)..."
    if xcrun actool "Resources/${APP_NAME}.icon" --compile "${APP_DIR}/Contents/Resources" \
        --platform macosx --minimum-deployment-target 14.0 \
        --app-icon "${APP_NAME}" --output-partial-info-plist /dev/null >/dev/null 2>&1 \
        && [[ -f "${APP_DIR}/Contents/Resources/Assets.car" ]]; then
        ICON_ASSETS=1
    else
        echo "    (actool falhou — usando o .icns legado)"
    fi
fi
if [[ "${ICON_ASSETS}" == "0" && -f "Resources/${APP_NAME}.icns" ]]; then
    cp "Resources/${APP_NAME}.icns" "${APP_DIR}/Contents/Resources/${APP_NAME}.icns"
fi

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>pt-BR</string>
    <key>CFBundleLocalizations</key>
    <array><string>pt-BR</string><string>pt</string></array>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>com.andresouza.uptend</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundleIconFile</key><string>${APP_NAME}</string>
$( [[ "${ICON_ASSETS}" == "1" ]] && printf '    <key>CFBundleIconName</key><string>%s</string>' "${APP_NAME}" )
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSLocationUsageDescription</key><string>O Uptend usa a localização apenas para exibir o nome (SSID) da rede Wi-Fi, uma exigência do macOS. Nenhum dado de localização é coletado ou enviado.</string>
    <key>NSLocationWhenInUseUsageDescription</key><string>O Uptend usa a localização apenas para exibir o nome (SSID) da rede Wi-Fi, uma exigência do macOS. Nenhum dado de localização é coletado ou enviado.</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <!-- Permite que o painel embutido (WebView) carregue serviços self-hosted na rede
             local por http (ex.: Metabase, Dozzle). Não libera http arbitrário da internet. -->
        <key>NSAllowsLocalNetworking</key><true/>
    </dict>
</dict>
</plist>
PLIST

# Assinatura ESTÁVEL: se existir o certificado local "Uptend Dev", assina com ele
# (a assinatura fica igual entre builds → o "Sempre Permitir" do Keychain gruda e o
# app para de pedir a senha toda vez). Sem o certificado, cai no ad-hoc de sempre.
SIGN_ID="Uptend Dev"
if security find-identity -p codesigning 2>/dev/null | grep -q "$SIGN_ID"; then
    echo "==> Assinando com o certificado '${SIGN_ID}' (estável)..."
    codesign --force --deep --sign "$SIGN_ID" "${APP_DIR}" >/dev/null 2>&1 || true
else
    echo "==> Assinando localmente (ad-hoc)..."
    codesign --force --sign - "${APP_DIR}" >/dev/null 2>&1 || true
fi

# Instalação: /Applications é o ÚNICO lugar "instalado"; build/ é só saída de
# compilação. Fecha o app se estiver rodando antes de trocar o bundle.
if [[ "${INSTALL}" == "1" ]]; then
    echo "==> Instalando em /Applications/${APP_NAME}.app..."
    osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
    sleep 1
    rm -rf "/Applications/${APP_NAME}.app"
    ditto "${APP_DIR}" "/Applications/${APP_NAME}.app"
fi

if [[ "${OPEN_APP}" == "1" ]]; then
    echo "==> Abrindo ${APP_NAME}..."
    if [[ "${INSTALL}" == "1" ]]; then
        open "/Applications/${APP_NAME}.app"
    else
        open "${APP_DIR}"
    fi
fi

if [[ "${INSTALL}" == "1" ]]; then
    echo "OK: /Applications/${APP_NAME}.app"
else
    echo "OK: ${APP_DIR}"
fi
