#!/bin/zsh
# Gera o TermoBar assinado com Developer ID, notarizado e pronto para distribuir.
# Só arm64: o app lê sensores que existem apenas no Apple Silicon.
#
# Pré-requisitos (uma vez por Mac):
#   - Certificado "Developer ID Application" do time no Keychain.
#   - Credenciais do notarytool guardadas no perfil "TermoBar":
#       xcrun notarytool store-credentials TermoBar --apple-id <apple-id> --team-id F22LFNZSAZ
#   - Chave privada do Sparkle no Keychain, na conta br.com.gbrlrg.termobar (veja docs/DEVELOPMENT.md).
#
# Resultado em build/release/, com o app já carimbado (stapled):
#   - TermoBar-<versão>.dmg: janela com fundo, o app e uma seta para Aplicativos (o jeito de instalar).
#   - TermoBar-<versão>.zip: o mesmo app compactado; é o arquivo que o Sparkle baixa.
#   - appcast.xml: a versão nova para o Sparkle, assinada com a chave EdDSA.
set -euo pipefail

TEAM_ID=F22LFNZSAZ
PROFILE=${NOTARY_PROFILE:-TermoBar}
SPARKLE_ACCOUNT=br.com.gbrlrg.termobar
REPO=https://github.com/gbrlrg/termo-bar
ROOT=${0:A:h:h}
OUT=$ROOT/build/release
APP=$OUT/Build/Products/Release/TermoBar.app
IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | grep "($TEAM_ID)" | head -1 | awk '{print $2}')

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

# O Xcode assina o Sparkle.framework, mas os auxiliares dentro dele continuam com a assinatura ad hoc
# do pacote; a notarização exige o Developer ID em cada executável. Do mais interno para o app.
echo "==> Reassinando o Sparkle com o Developer ID"
SPARKLE=$APP/Contents/Frameworks/Sparkle.framework/Versions/B
for item in $SPARKLE/XPCServices/Installer.xpc $SPARKLE/XPCServices/Downloader.xpc \
    $SPARKLE/Autoupdate $SPARKLE/Updater.app $SPARKLE/../..; do
    codesign --force --sign $IDENTITY --options runtime --timestamp --preserve-metadata=entitlements $item
done
codesign --force --sign $IDENTITY --options runtime --timestamp --preserve-metadata=entitlements $APP

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

echo "==> Montando o DMG"
DMG=$OUT/TermoBar-$VERSION.dmg
$ROOT/scripts/make-dmg.sh $APP $DMG

codesign --sign $IDENTITY --timestamp $DMG

echo "==> Notarizando o DMG"
xcrun notarytool submit $DMG --keychain-profile $PROFILE --wait
xcrun stapler staple $DMG
spctl --assess --type open --context context:primary-signature --verbose=2 $DMG

echo "==> Gerando o appcast do Sparkle"
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" $APP/Contents/Info.plist)
# Imprime `sparkle:edSignature="…" length="…"`, que vai direto no enclosure.
SIGNATURE=$($OUT/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update --account $SPARKLE_ACCOUNT $ZIP)
cat > $OUT/appcast.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>TermoBar</title>
    <item>
      <title>TermoBar $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>$REPO/releases/tag/v$VERSION</sparkle:fullReleaseNotesLink>
      <enclosure url="$REPO/releases/download/v$VERSION/TermoBar-$VERSION.zip" type="application/octet-stream" $SIGNATURE/>
    </item>
  </channel>
</rss>
EOF

echo "==> Pronto (anexe os três à versão v$VERSION no GitHub):"
echo "    $DMG"
echo "    $ZIP"
echo "    $OUT/appcast.xml"
