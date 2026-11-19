#!/usr/bin/env bash
# sddm-thyx.sh — login screen with the thyx theme (SDDM) instead of GDM.
#
#   ./sddm-thyx.sh instalar [tema]
#                             install SDDM + Wayland greeter + thyx theme
#                             (optionally with a preset). Does NOT change the
#                             login screen yet.
#   ./sddm-thyx.sh tema NOME  switch preset: blush | gilded | malachite | sakura
#                             (cinder is a video this Fedora cannot decode).
#                             Changes the login AND the lock screen, and turns
#                             wallpaper sync off.
#   ./sddm-thyx.sh sincronizar
#                             login + lock follow the wallpaper: same image,
#                             heavily blurred, pywal colours (over the preset's
#                             layout). Updated at every wallpaper change.
#   ./sddm-thyx.sh ativar     unlock the oo7 keyring from SDDM (PAM, same lines
#                             as GDM) and make SDDM the login screen. Takes
#                             effect at the next boot; nothing is stopped now.
#   ./sddm-thyx.sh ajustar [niri|weston]
#                             login screen: runs the greeter on niri (visible
#                             cursor; or weston), br keyboard, Num Lock,
#                             tap-to-click, Portuguese labels.
#   ./sddm-thyx.sh layout [pocket|thyx]
#                             pocket: clock top-left, login in a bottom corner
#                             (sddm/PocketLogin.qml, same as the lock screen);
#                             thyx: the theme's own centred form.
#   ./sddm-thyx.sh voltar     back to GDM (next boot). SDDM stays installed.
#
# If the login screen ever fails to appear: Ctrl+Alt+F3, log in on the text
# console and run  ~/Projetos/glasstty/sddm-thyx.sh voltar ; reboot.
#
# GDM is NOT removed: gnome-shell depends on it, and it is the way back.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
thyx="${THYX_DIR:-$HOME/Projetos/thyx}"
pam=/etc/pam.d/sddm
say() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }

# The lock screen (LockScreen.qml) reads the installed theme.conf, or the
# clone's when SDDM is not installed, so both are kept in sync.
tema() {
    local nome="${1:-}"
    [ -f "$thyx/presets/$nome.conf" ] || { echo "Temas: $(ls "$thyx/presets" | sed 's/\.conf$//' | tr '\n' ' ')" >&2; exit 1; }
    if [ "$nome" = cinder ]; then
        echo "Aviso: 'cinder' é um vídeo H.264 que o FFmpeg deste Fedora não decodifica (fundo preto)." >&2
    fi
    rm -f "$HOME/.config/pocket-dots/login-sync"
    cp "$thyx/presets/$nome.conf" "$thyx/theme.conf"
    sed -i 's/^AutoFingerprintOnLoad=.*/AutoFingerprintOnLoad=false/' "$thyx/theme.conf"
    if [ -d /usr/share/sddm/themes/thyx ]; then
        sudo cp "$thyx/theme.conf" /usr/share/sddm/themes/thyx/theme.conf
    fi
    say "Tema: $nome (login e tela de bloqueio)"
}

sincronizar() {
    [ -d /usr/share/sddm/themes/thyx ] || { echo "rode '$0 instalar' antes" >&2; exit 1; }
    mkdir -p "$HOME/.config/pocket-dots"
    touch "$HOME/.config/pocket-dots/login-sync"
    "$HOME/.config/glasstty/scripts/login-pywal.sh" && say "Login e bloqueio seguem o wallpaper (troque o tema fixo com: $0 tema NOME)"
}

instalar() {
    [ -f "$thyx/metadata.desktop" ] || { echo "thyx não encontrado em $thyx" >&2; exit 1; }
    [ -n "${1:-}" ] && tema "$1"
    say "Pacotes: sddm + greeter Wayland (weston)"
    # sddm-wayland-generic: the greeter runs inside weston. Without it dnf
    # would pick another provider (X11 or KDE's kwin).
    sudo dnf install -y sddm sddm-wayland-generic
    say "Tema thyx (instalador do próprio thyx)"
    # It copies the theme to /usr/share/sddm/themes/thyx, the fonts to
    # /usr/local/share/fonts/thyx and sets Current=thyx in /etc/sddm.conf.
    # Its last step (systemctl enable sddm) is expected to FAIL while GDM is
    # the active display manager: that is intentional, `ativar` does it.
    bash "$thyx/scripts/install" --yes || true
    say "Pronto. O login ainda é o GDM. Teste o visual e depois rode: $0 ativar"
}

ativar() {
    [ -f "$pam" ] || { echo "$pam não existe: rode '$0 instalar' antes" >&2; exit 1; }
    [ -d /usr/share/sddm/themes/thyx ] || { echo "tema thyx não instalado" >&2; exit 1; }
    if ! grep -q "pam_oo7.so" "$pam"; then
        say "PAM: desbloquear o chaveiro (oo7) no login, igual ao GDM"
        sudo cp -n "$pam" "$pam.bak-pocket-dots"
        # Same three lines as /usr/lib/pam.d/gdm-password, in the same spots:
        # right after the gnome-keyring line of each section (auth / password /
        # session), else before its postlogin include, else at its end.
        sudo awk '
            function oo7(sec) {
                if (done[sec]) return
                done[sec] = 1
                if (sec == "auth")     print "-auth       optional      pam_oo7.so"
                if (sec == "password") print "-password   optional      pam_oo7.so use_authtok"
                if (sec == "session")  print "-session    optional      pam_oo7.so auto_start"
            }
            {
                s = $1; sub(/^-/, "", s)
                is_sec = (s == "auth" || s == "account" || s == "password" || s == "session")
                # Leaving a section without a gnome-keyring line: add at its end.
                if (is_sec && cur != "" && s != cur) oo7(cur)
                # Before that section pulls in postlogin, like GDM does.
                if (is_sec && $0 ~ /include[ \t]+postlogin/) oo7(s)
                print
                if (is_sec) cur = s
                # Right after the gnome-keyring line of the section, like GDM.
                if (is_sec && $0 ~ /pam_gnome_keyring\.so/) oo7(s)
            }
            END { if (cur != "") oo7(cur) }
        ' "$pam.bak-pocket-dots" | sudo tee "$pam" >/dev/null
        grep -n "pam_oo7" "$pam"
    fi
    ajustar
    say "Login: GDM -> SDDM (vale no próximo boot)"
    sudo systemctl enable --force sddm.service
    systemctl status display-manager.service --no-pager 2>/dev/null | head -3 || true
    say "Feito. Reinicie quando quiser. Para voltar: $0 voltar"
}

# The greeter's compositor. sddm-wayland-generic runs it in weston, but under
# weston the pointer was invisible on this laptop, so niri is used instead
# (sddm/niri-greeter.kdl: no binds, br keyboard, Num Lock, tap-to-click,
# Adwaita cursor). `ajustar weston` goes back to weston (with the same fixes).
ajustar() {
    local comp="${1:-niri}"
    sudo install -d /etc/sddm /etc/sddm.conf.d

    # weston config: also kept for `ajustar weston`.
    sudo tee /etc/sddm/weston.ini >/dev/null <<'INI'
# glasstty: weston config for the SDDM greeter (sddm-thyx.sh ajustar)
[core]
idle-time=0

[shell]
cursor-theme=Adwaita
cursor-size=24

[keyboard]
keymap_layout=br
numlock-on=true

[libinput]
enable-tap=true
tap-and-drag=true
INI
    sudo install -m 644 "$repo/sddm/niri-greeter.kdl" /etc/sddm/niri-greeter.kdl

    local cmd="niri -c /etc/sddm/niri-greeter.kdl"
    [ "$comp" = weston ] && cmd="weston --shell=kiosk --config=/etc/sddm/weston.ini"
    say "Greeter: compositor = $comp (cursor visível, toque, teclado br, Num Lock)"
    sudo tee /etc/sddm.conf.d/10-pocket-dots.conf >/dev/null <<CONF
# glasstty (sddm-thyx.sh ajustar $comp)
[Wayland]
CompositorCommand=$cmd

[Theme]
CursorTheme=Adwaita
CursorSize=24

[General]
Numlock=on
CONF

    local t=/usr/share/sddm/themes/thyx
    if [ -d "$t" ]; then
        say "Tema: textos em português e sem tentativa automática de digital"
        sudo sed -i 's/"Environment ("/"Sessão ("/' "$t/src/components/buttons/EnvironmentButton.qml"
        sudo sed -i -e 's/\["Restart", /["Reiniciar", /' -e 's/\["Sleep", /["Suspender", /' "$t/src/layouts/SystemButtonsLayout.qml"
        sudo sed -i \
            -e 's/const dayNames = \[.*\];/const dayNames = ["Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado"];/' \
            -e 's/const monthNames = \[.*\];/const monthNames = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"];/' \
            -e 's/text = dayName + ", " + monthName + " " + dayNumber;/text = dayName + ", " + dayNumber + " de " + monthName;/' \
            "$t/src/components/clock/DateLabel.qml"
        # It logged in with an EMPTY password at every boot (one "Authentication
        # failure" per boot); there is no fingerprint reader to wait for.
        sudo sed -i 's/^AutoFingerprintOnLoad=.*/AutoFingerprintOnLoad=false/' "$t/theme.conf"
    fi
    sed -i 's/^AutoFingerprintOnLoad=.*/AutoFingerprintOnLoad=false/' "$thyx/theme.conf" 2>/dev/null || true
    say "Pronto. Vale no próximo boot."
    say "Se o login não aparecer: Ctrl+Alt+F3, entre e rode: $0 ajustar weston   (ou: $0 voltar)"
}

layout() {
    local t=/usr/share/sddm/themes/thyx qual="${1:-pocket}"
    [ -d "$t" ] || { echo "rode '$0 instalar' antes" >&2; exit 1; }
    local run=""; [ -w "$t/metadata.desktop" ] || run=sudo
    if [ "$qual" = pocket ]; then
        $run install -m 644 "$repo/sddm/PocketLogin.qml" "$t/src/PocketLogin.qml"
        $run sed -i 's|^MainScript=.*|MainScript=src/PocketLogin.qml|' "$t/metadata.desktop"
    else
        $run sed -i 's|^MainScript=.*|MainScript=src/Main.qml|' "$t/metadata.desktop"
    fi
    say "Layout do login: $qual (vale no próximo login)"
}

voltar() {
    say "Login: SDDM -> GDM (vale no próximo boot)"
    sudo systemctl enable --force gdm.service
    if [ -f "$pam.bak-pocket-dots" ]; then
        sudo cp "$pam.bak-pocket-dots" "$pam"
        say "PAM do SDDM restaurado"
    fi
    say "Feito. Reinicie para voltar ao GDM."
}

case "${1:-}" in
    instalar) instalar "${2:-}" ;;
    tema)     tema "${2:-}" ;;
    ajustar)  ajustar "${2:-niri}" ;;
    sincronizar) sincronizar ;;
    layout)   layout "${2:-pocket}" ;;
    ativar)   ativar ;;
    voltar)   voltar ;;
    *) sed -n '2,34p' "$0"; exit 1 ;;
esac
