# lang.sh — the language of the Hyprland scripts' notifications (es, en, and
# in this fork pt, through lang-pt.tsv).
#
# It is not executed: the other scripts load it with `source`.
#
#   . "$HOME/.config/glasstty/scripts/lang.sh" 2>/dev/null || tr_() { printf '%s' "$1"; }
#   notify-send "$(tr_ 'Luz nocturna' 'Night light')" "$(tr_ 'Activada' 'On')"
#
# Spanish is the original and ALWAYS goes first; if the language file is
# missing, if the line is not there or if it says anything else, Spanish comes
# out. That is the failure mode we want: never extra text, and never, ever
# blank text.
#
# The source of truth is ~/.config/glasstty/language.conf, the SAME file hyprlock
# loads, so the lock screen and these notifications do not drift apart.
# $RICE_LANG in the environment wins, which is handy for testing without
# touching anything:
#   RICE_LANG=en ~/.config/glasstty/scripts/night-light.sh

if [ -z "${RICE_LANG:-}" ]; then
    RICE_LANG=es
    _rice_lang_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/language.conf"
    if [ -r "$_rice_lang_conf" ]; then
        # No grep or sed: the file is two lines long, and this is loaded by
        # scripts fired from a key press.
        while IFS= read -r _rice_lang_line || [ -n "$_rice_lang_line" ]; do
            case "$_rice_lang_line" in
                '$uiLang'*=*)
                    _rice_lang_value="${_rice_lang_line#*=}"
                    _rice_lang_value="${_rice_lang_value// /}"
                    _rice_lang_value="${_rice_lang_value//$'\t'/}"
                    [ -n "$_rice_lang_value" ] && RICE_LANG="$_rice_lang_value"
                    ;;
            esac
        done < "$_rice_lang_conf"
    fi
    # This fork: no language.conf (that is hyprlock's, Hyprland only), so the
    # shell's own setting decides (quickshell-rice.json, "language").
    if [ ! -r "$_rice_lang_conf" ] && [ -r "$HOME/.config/quickshell-rice.json" ]; then
        while IFS= read -r _rice_lang_line; do
            case "$_rice_lang_line" in
                *'"language"'*:*)
                    _rice_lang_value="${_rice_lang_line#*:}"
                    _rice_lang_value="${_rice_lang_value//[\" ,]/}"
                    [ -n "$_rice_lang_value" ] && RICE_LANG="$_rice_lang_value"
                    break ;;
            esac
        done < "$HOME/.config/quickshell-rice.json"
    fi
    unset _rice_lang_conf _rice_lang_line _rice_lang_value
fi

# Portuguese (this fork): looked up by the Spanish text in lang-pt.tsv, loaded
# once per script. A string missing from the table stays in Spanish.
_rice_pt_loaded=0
declare -A _RICE_PT 2>/dev/null || true
_rice_pt_load() {
    _rice_pt_loaded=1
    local f="${BASH_SOURCE[0]%/*}/lang-pt.tsv" es pt
    [ -r "$f" ] || return 0
    while IFS=$'\t' read -r es pt; do
        case "$es" in ''|'#'*) continue ;; esac
        [ -n "$pt" ] && _RICE_PT["$es"]="$pt"
    done < "$f"
}

# tr_ SPANISH ENGLISH
tr_() {
    case "$RICE_LANG" in
        en) printf '%s' "$2" ;;
        pt) [ "$_rice_pt_loaded" = 1 ] || _rice_pt_load
            printf '%s' "${_RICE_PT[$1]:-$1}" ;;
        *)  printf '%s' "$1" ;;
    esac
}
