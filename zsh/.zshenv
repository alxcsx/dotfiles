# ------ Directories ------
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
#-------Editor------
export VISUAL="emacs -nw"
export EDITOR="emacs -nw"
#------ PATH-------
typeset -U path # nested shells don't stack duplicate entries
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"
#------ PAGER ------
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"
# ---------- Starship ----------
export STARSHIP_CONFIG="$ZDOTDIR/modules/starship.toml"
# ----------- MISC  ----------
export WINEPREFIX="$XDG_DATA_HOME/wineprefixes/default"

export GNUPGHOME="$XDG_DATA_HOME/gnupg"
[[ -d "$GNUPGHOME" ]] || install -dm700 "$GNUPGHOME"
