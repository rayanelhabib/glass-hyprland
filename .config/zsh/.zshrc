# ==============================================================================
# Cyber Security & Dev Edition Zsh Setup
# ==============================================================================
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
ZSH_CUSTOM="$ZSH/custom"

# Install Oh-My-Zsh if it doesn't exist
if [ ! -d "$ZSH" ]; then
  git clone https://github.com/ohmyzsh/ohmyzsh.git "$ZSH" >/dev/null 2>&1
fi

plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

[ -f "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"

# ==============================================================================
# History & Options
# ==============================================================================
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

setopt HIST_IGNORE_ALL_DUPS
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

alias fetch='fastfetch -c ~/.config/fastfetch/cyber-fetch.jsonc'

# Execute Cyber Fastfetch on interactive launch
if [[ -z "$FASTFETCH_RUN" ]]; then
    export FASTFETCH_RUN=1
    fastfetch -c ~/.config/fastfetch/cyber-fetch.jsonc 2>/dev/null
fi
