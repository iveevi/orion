### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit
### End of Zinit's installer chunk

# Zinit plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions

# Enable longer history
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

PROMPT='%B%F{8}%m %F{5}○%f %F{15}%1~%f%b '

autoload -Uz add-zsh-hook
_prompt_spacer() { [[ -n $_prompt_spaced ]] && print; _prompt_spaced=1 }
add-zsh-hook precmd _prompt_spacer
clear() { command clear; unset _prompt_spaced }

# Enable home and end keys
bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line

# Aliases
alias ls='ls --color'
alias wqrenderdoc='WAYLAND_DISPLAY= XDG_SESSION_TYPE=x11 qrenderdoc'

# Expand path
export PATH=$PATH:~/.local/bin/
export PATH="$HOME/.npm-global/bin:$PATH"

export SYSTEMD_EDITOR="nvim"

export GOPATH="$HOME/.local/share/go"

# Ongoing research projects
alias pew='uv run --project ~/tools/pew pew'
alias jkl='uv run --project ~/tools/jkl jkl'
alias code='FONTCONFIG_FILE=~/.config/fontconfig/vscode.conf code'
