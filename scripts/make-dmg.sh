#!/bin/zsh
# Monta o DMG de instalação: fundo desenhado, o app à esquerda e o atalho para Aplicativos à direita.
# Uso: scripts/make-dmg.sh <TermoBar.app> <saída.dmg>
# Usa o dmgbuild, que grava a disposição da janela direto no .DS_Store, sem depender do Finder.
set -euo pipefail

APP=${1:A}
DMG=${2:A}
ROOT=${0:A:h:h}
VENV=$ROOT/build/dmgbuild
WORK=$(mktemp -d)
trap 'rm -rf $WORK' EXIT

[[ -x $VENV/bin/dmgbuild ]] || { python3 -m venv $VENV && $VENV/bin/pip install -q 'dmgbuild==1.6.7' }

# Gera background.png e background@2x.png; o dmgbuild junta os dois num TIFF para telas Retina.
swift $ROOT/scripts/dmg/background.swift $WORK

rm -f $DMG
$VENV/bin/dmgbuild -s $ROOT/scripts/dmg/settings.py \
    -D app=$APP -D background=$WORK/background.png \
    TermoBar $DMG
