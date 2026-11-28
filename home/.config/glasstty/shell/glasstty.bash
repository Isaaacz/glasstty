# glasstty.bash — the shell side of glasstty, for interactive bash.
#
# Fedora's ~/.bashrc sources every file in ~/.bashrc.d; install-niri.sh links
# this one there. Each part only switches on if its tool is installed, so a
# missing package just means that part stays off. Pure bash, no prompt engine:
# the colours are the terminal's 16 ANSI ones, which kitty takes from pywal,
# so the prompt follows the wallpaper with nothing to regenerate.
#
# Every part is OFF until you switch it on in Settings › System › Terminal,
# which writes the switches to ~/.local/state/glasstty/terminal.sh:
#   GT_PROMPT  the prompt below      GT_TOOLS  eza / bat / zoxide / fzf
#   GT_FETCH   the fastfetch greeting (GT_NOTIFY is kitty's, see kitty.conf)

[[ $- == *i* ]] || return 0
GT_PROMPT=0 GT_TOOLS=0 GT_FETCH=0
_gt_prefs="${XDG_STATE_HOME:-$HOME/.local/state}/glasstty/terminal.sh"
[[ -r $_gt_prefs ]] && . "$_gt_prefs"
unset _gt_prefs

# ───────────────────────── the prompt ─────────────────────────
#   ~/Projetos/glasstty   main +2 ~1   4s
#   ❯
# The folder, the git branch with what is staged (+), changed (~) and new (?),
# how long the last command took when it was 3 s or more, and the arrow in red
# with the exit code when it failed. Two lines, so long paths never squeeze
# what you type.

if [[ $GT_PROMPT == 1 ]]; then
# When the command started: PS0 is printed right before it runs, and this
# expands to nothing while storing the time in microseconds (no fork).
PS0='${PS1:$((_gt_t0=${EPOCHREALTIME/./},0)):0}'"${PS0:-}"

_gt_git() {
    local line branch="" ahead="" staged=0 changed=0 new=0 x y
    while IFS= read -r line; do
        case "$line" in
            "# branch.head "*) branch=${line#\# branch.head } ;;
            "# branch.ab "*)
                set -- ${line#\# branch.ab }
                [[ $1 != +0 ]] && ahead+=" ↑${1#+}"
                [[ $2 != -0 ]] && ahead+=" ↓${2#-}" ;;
            "? "*) ((new++)) ;;
            [12u]" "*)
                x=${line:2:1}; y=${line:3:1}
                [[ $x != . ]] && ((staged++))
                [[ $y != . ]] && ((changed++)) ;;
        esac
    done < <(git status --porcelain=v2 --branch 2>/dev/null)
    [[ -z $branch ]] && return
    [[ $branch == "(detached)" ]] && branch=$(git rev-parse --short HEAD 2>/dev/null)
    local s=" \[\e[35m\] $branch\[\e[0m\]"
    ((staged))  && s+=" \[\e[32m\]+$staged\[\e[0m\]"
    ((changed)) && s+=" \[\e[33m\]~$changed\[\e[0m\]"
    ((new))     && s+=" \[\e[90m\]?$new\[\e[0m\]"
    [[ -n $ahead ]] && s+="\[\e[36m\]$ahead\[\e[0m\]"
    printf '%s' "$s"
}

_gt_prompt() {
    local code=$? took=""
    if [[ -n ${_gt_t0:-} ]]; then
        local us=$(( ${EPOCHREALTIME/./} - _gt_t0 )) s
        s=$(( us / 1000000 ))
        if (( s >= 60 )); then took=" \[\e[90m\]$((s / 60))m$((s % 60))s\[\e[0m\]"
        elif (( s >= 3 )); then took=" \[\e[90m\]${s}s\[\e[0m\]"
        fi
        unset _gt_t0
    fi
    local dir=${PWD/#$HOME/\~}
    local arrow="\[\e[34m\]❯\[\e[0m\]"
    (( code != 0 )) && arrow="\[\e[31m\]$code ❯\[\e[0m\]"
    PS1="\n\[\e[1;34m\]$dir\[\e[0m\]$(_gt_git)$took\n$arrow "
}
PROMPT_COMMAND="_gt_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi

# ───────────────────────── better tools ─────────────────────────
if [[ $GT_TOOLS == 1 ]]; then
if command -v eza >/dev/null; then
    alias ls='eza --icons=auto --group-directories-first'
    alias ll='eza -l --icons=auto --group-directories-first --git --time-style=relative'
    alias la='eza -la --icons=auto --group-directories-first --git --time-style=relative'
    alias tree='eza --tree --icons=auto'
fi
# bat as cat: highlighting, but plain output when piped, and no pager
command -v bat >/dev/null && alias cat='bat --paging=never --style=plain'
# z proj → ~/Projetos from anywhere; zi picks among the matches with fzf
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
# Ctrl+R searches the history, Ctrl+T inserts a file, Alt+C jumps into a folder.
# Colours from the terminal's palette (the wallpaper's) instead of fzf's own.
if command -v fzf >/dev/null; then
    export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border=rounded --info=inline \
--color=16,fg+:15,bg+:-1,hl:4,hl+:4,pointer:5,marker:2,prompt:4,border:8,info:8"
    eval "$(fzf --bash 2>/dev/null)"
fi
fi

# ───────────────────────── greeting ─────────────────────────
# A compact fastfetch in a new kitty window: only when kitty itself started
# this shell (not a nested one, an editor's terminal or SSH). SHLVL cannot tell:
# kitty inherits SHLVL=1 from the session, so its shell already counts 2.
_gt_parent=""
read -r _gt_parent < /proc/$PPID/comm 2>/dev/null
if [[ $GT_FETCH == 1 && $_gt_parent == kitty && -z ${SSH_TTY:-} ]] \
   && command -v fastfetch >/dev/null; then
    fastfetch -c "${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/compact.jsonc" 2>/dev/null
fi
unset _gt_parent GT_PROMPT GT_TOOLS GT_FETCH
