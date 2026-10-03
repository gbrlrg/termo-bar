#!/bin/zsh
# Gera o TermoBar assinado com Developer ID, notarizado e pronto para distribuir.
# Só arm64: o app lê sensores que existem apenas no Apple Silicon.
#
# Pré-requisitos (uma vez por Mac):
#   - Certificado "Developer ID Application" do time no Keychain.
#   - Credenciais do notarytool guardadas no perfil "TermoBar":
#       xcrun notarytool store-credentials TermoBar --apple-id <apple-id> --team-id F22LFNZSAZ
#
# Resultado: build/release/TermoBar-<versão>.zip, com o app já carimbado (stapled).
set -euo pipefail

TEAM_ID=F22LFNZSAZ
PROFILE=${NOTARY_PROFILE:-TermoBar}
ROOT=${0:A:h:h}
OUT=$ROOT/build/release
APP=$OUT/Build/Products/Release/TermoBar.app

cd $ROOT
xcodegen generate --quiet

echo "==> Compilando (Release, Developer ID)"
xcodebuild -project TermoBar.xcodeproj -scheme TermoBar -configuration Release \
    -derivedDataPath $OUT -destination 'generic/platform=macOS' \
    ARCHS=arm64 \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    DEVELOPMENT_TEAM=$TEAM_ID \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    OTHER_CODE_SIGN_FLAGS=--timestamp \
    clean build -quiet

echo "==> Conferindo a assinatura"
codesign --verify --deep --strict --verbose=2 $APP
codesign -d --entitlements - $APP 2>/dev/null | grep -q get-task-allow \
    && { echo "O app ainda tem get-task-allow; a Apple recusaria."; exit 1 }

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $APP/Contents/Info.plist)
ZIP=$OUT/TermoBar-$VERSION.zip

echo "==> Enviando para notarização (pode levar alguns minutos)"
rm -f $ZIP
ditto -c -k --keepParent $APP $ZIP
xcrun notarytool submit $ZIP --keychain-profile $PROFILE --wait

echo "==> Carimbando o resultado no app"
xcrun stapler staple $APP
xcrun stapler validate $APP

echo "==> Conferindo no Gatekeeper"
spctl --assess --type execute --verbose=2 $APP

# O zip final leva o app já carimbado, para abrir mesmo sem internet.
rm -f $ZIP
ditto -c -k --keepParent $APP $ZIP
echo "==> Pronto: $ZIP"
