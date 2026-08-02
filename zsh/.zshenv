# ------ Directories ------
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
#-------Editor------
export VISUAL="emacsclient"
export EDITOR="emacsclient"
#------ GPG -------
export GPG_TTY=$(tty)
#------ PATH-------
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"
#------ PAGER ------
export MANPAGER="bat -l man -p"
# ---------- Starship ----------
export STARSHIP_CONFIG="$ZDOTDIR/modules/starship.toml"
# ----------- MISC  ----------
export WINEPREFIX="$XDG_DATA_HOME/wineprefixes/default"

export GNUPGHOME="$XDG_DATA_HOME/gnupg"
mkdir -p "$HOME/.local/share/gnupg" && chmod 700 "$HOME/.local/share/gnupg"