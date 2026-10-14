# Configuração do dmgbuild para a janela de instalação (640x420).
# Posições batem com scripts/dmg/background.swift. Definições vindas do make-dmg.sh: app, background.
import os

app = defines["app"]
background = defines["background"]

format = "UDZO"
compression_level = 9
filesystem = "HFS+"

files = [app]
symlinks = {"Aplicativos": "/Applications"}
hide_extensions = [os.path.basename(app)]

# A altura soma os 32 pontos da barra de título aos 420 do fundo.
window_rect = ((200, 120), (640, 452))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

arrange_by = None
icon_size = 128
text_size = 13
icon_locations = {
    os.path.basename(app): (170, 206),
    "Aplicativos": (470, 206),
}
