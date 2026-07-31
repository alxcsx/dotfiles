# ---- HISTORY
HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=10000
SAVEHIST=10000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS

# ---- SHELL

setopt AUTOCD
setopt NOBEEP
setopt NUMERIC_GLOB_SORT

# --- ZOXIDE 
eval "$(zoxide init zsh)"
# --- MISE
eval "$(mise activate zsh)"

# --- AUTOCOMPLETE

autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# --- FZF
if [[ -f /usr/share/fzf/key-bindings.zsh ]]; then
	source /usr/share/fzf/key-bindings.zsh
	source /usr/share/fzf/completion.zsh
fi


# --- MODULES

source "$ZDOTDIR/modules/fzf.zsh"
source "$ZDOTDIR/modules/aliases.zsh"
source "$ZDOTDIR/modules/bindings.zsh"
source "$ZDOTDIR/modules/plugins.zsh"
source "$ZDOTDIR/modules/prompt.zsh"