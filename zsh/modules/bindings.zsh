#!/bin/zsh

bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^F' _fzf_file_no_hidden
bindkey '^\' autosuggest-toggle
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down