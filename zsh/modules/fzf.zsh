export FZF_DEFAULT_COMMAND='fd --type f --hidden --strip-cwd-prefix'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS="
--height 60%
--layout=reverse
--border
"
# file preview only where entries are files (not Ctrl-R history / Alt-C dirs)
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always {}'"

_fzf_file_no_hidden() {
	local result
	result=$(fd --type f --strip-cwd-prefix | fzf --preview 'bat --style=numbers --color=always {}') && LBUFFER+="${(q)result}"
	zle reset-prompt
}

zle -N _fzf_file_no_hidden