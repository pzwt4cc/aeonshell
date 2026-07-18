# ==========================================
# ZSH CONFIGURATION
# ==========================================


# Print system info immediately
# Fastfetch in random img (check fastfetch cfg)
local last_img=$(cat /tmp/fastfetch_last 2>/dev/null)
local random_img=$(find $HOME/.config/fastfetch/img/ -type f ! -name "$last_img" | shuf -n 1)
echo "$(basename "$random_img")" > /tmp/fastfetch_last
fastfetch --logo "$random_img"


# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Silence P10k warnings caused by Fastfetch output
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet


# ENVIRONMENT VARIABLES
export LANG=ru_RU.UTF-8
export LC_ALL=ru_RU.UTF-8
export EDITOR="codium"


# COLORS & UI
# Apply Pywal colors if they exist
[ -f ~/.cache/wal/colors.sh ] && source ~/.cache/wal/colors.sh


# HISTORY SETTINGS
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000

setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS


# PLUGINS & COMPLETIONS
source /usr/share/zsh-antidote/antidote.zsh
fpath=(~/.local/share/antidote/zsh-users/zsh-completions $fpath)
autoload -Uz compinit && compinit -i

# Load plugins via Antidote
antidote bundle < ~/.zsh_plugins.txt > ~/.zsh_plugins.zsh
source ~/.zsh_plugins.zsh


# PLUGIN CONFIGURATION
# Autosuggestions settings
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#565f89'
bindkey '^ ' autosuggest-accept

# Fzf-tab visual settings
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':fzf-tab:*' fzf-flags --height=40% --layout=reverse --border


# ALIASES
alias ls="ls --color=auto"
alias update="yay -Syu"
alias cp="cp -i"
alias mv="mv -i"
alias rm="rm -i"
alias clock="tty-clock -c -b -C 5 -D"
alias cw="hyprctl dispatch setfloating active && hyprctl dispatch centerwindow active"


# FUNCTIONS
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    command yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
    command rm -f -- "$tmp"
}


# THEME
# Load Powerlevel10k configuration
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh