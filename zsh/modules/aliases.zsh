# ls -> eza
alias ls='eza --icons'
alias ll='eza -lh --icons --git'
alias la='eza -lah --icons --git'
alias tree='eza --tree --icons --git'
compdef eza=ls

# cat -> bat
alias cat='bat'

# core
alias grep='rg --color=auto'
alias diff='diff --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias top='btop'

alias -- -='cd -'



alias vim='nvim'

if [[ "$OSTYPE" == linux* ]]; then
  caffeinate() {
    local args=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -[dDiImsu]*) shift ;;
        *) args+=("$1"); shift ;;
      esac
    done
    [[ -t 1 ]] && setterm --blank 0 2>/dev/null
    systemd-inhibit --what="idle:sleep:handle-lid-switch" --why="caffeinate" "${args[@]:-sleep infinity}"
    [[ -t 1 ]] && setterm --blank 1 2>/dev/null
  }
fi