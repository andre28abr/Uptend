#!/bin/bash
#
# Roda a suíte de testes automatizados usando o toolchain do Xcode
# (o Command Line Tools sozinho não traz XCTest/Swift Testing).
#
set -euo pipefail
cd "$(dirname "$0")"

XCODE_DIR="/Applications/Xcode.app/Contents/Developer"

if [[ -d "${XCODE_DIR}" ]]; then
    exec env DEVELOPER_DIR="${XCODE_DIR}" swift test "$@"
else
    # Se o xcode-select já apontar para um Xcode completo, roda direto.
    exec swift test "$@"
fi
