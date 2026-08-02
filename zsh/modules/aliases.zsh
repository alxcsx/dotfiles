# ls -> eza
alias ls='eza --icons always'
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