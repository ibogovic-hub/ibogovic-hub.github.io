---
title: .bashrc/.zshrc file
tags: Linux-and-Mac
---

---
# Linux
## .bashrc file

---

```sh
# ~/.bashrc: executed by bash(1) for non-login shells. 
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc) 
# for examples 
 
# If not running interactively, don't do anything 
case $- in 
    *i*) ;; 
      *) return;; 
esac 
 
# don't put duplicate lines or lines starting with space in the history. 
# See bash(1) for more options 
HISTCONTROL=ignoreboth 
 
# append to the history file, don't overwrite it 
shopt -s histappend 
 
# for setting history length see HISTSIZE and HISTFILESIZE in bash(1) 
HISTSIZE=1000 
HISTFILESIZE=2000 
 
# check the window size after each command and, if necessary, 
# update the values of LINES and COLUMNS. 
shopt -s checkwinsize 
 
# If set, the pattern "**" used in a pathname expansion context will 
# match all files and zero or more directories and subdirectories. 
#shopt -s globstar 
 
# make less more friendly for non-text input files, see lesspipe(1) 
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)" 
 
# set variable identifying the chroot you work in (used in the prompt below) 
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then 
    debian_chroot=$(cat /etc/debian_chroot) 
fi 
 
# set a fancy prompt (non-color, unless we know we "want" color) 
case "$TERM" in 
    xterm-color|*-256color) color_prompt=yes;; 
esac 
 
# uncomment for a colored prompt, if the terminal has the capability; turned 
# off by default to not distract the user: the focus in a terminal window 
# should be on the output of commands, not on the prompt 
force_color_prompt=yes 
 
if [ -n "$force_color_prompt" ]; then 
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then 
        # We have color support; assume it's compliant with Ecma-48 
        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such 
        # a case would tend to support setf rather than setaf.) 
        color_prompt=yes 
    else 
        color_prompt= 
    fi 
fi 
 
if [ "$color_prompt" = yes ]; then 
    prompt_color='\[\033[;32m\]' 
    info_color='\[\033[1;34m\]' 
    prompt_symbol=㉿ 
    if [ "$EUID" -eq 0 ]; then # Change prompt colors for root user 
        prompt_color='\[\033[;94m\]' 
        info_color='\[\033[1;31m\]' 
        prompt_symbol= 
    fi 
    PS1=$prompt_color'┌──${debian_chroot:+($debian_chroot)──}('$info_color'\u${prompt_symbol}\h'$prompt_color')-[\[\033[0;1m\]\w'$prompt_color']\n'$prompt_color'└─'$info_color'\$\[\033[0m\] ' 
    # BackTrack red prompt 
    #PS1='${debian_chroot:+($debian_chroot)}\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ ' 
else 
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ ' 
fi 
unset color_prompt force_color_prompt 
 
# If this is an xterm set the title to user@host:dir 
case "$TERM" in 
xterm*|rxvt*) 
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1" 
    ;; 
*) 
    ;; 
esac 
 
# enable color support of ls, less and man, and also add handy aliases 
if [ -x /usr/bin/dircolors ]; then 
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)" 
    alias ls='ls --color=auto' 
    #alias dir='dir --color=auto' 
    #alias vdir='vdir --color=auto' 
 
    alias grep='grep --color=auto' 
    alias fgrep='fgrep --color=auto' 
    alias egrep='egrep --color=auto' 
    alias diff='diff --color=auto' 
    alias ip='ip --color=auto' 
# some more ls aliases 
    alias ll='ls -alhF --color=auto' 
    alias la='ls -A' 
    alias l='ls -CF' 
    alias cdu='sudo apt -y update; sudo apt -y full-upgrade; sudo apt -y upgrade; sudo apt -y dist-upgrade; sudo apt -f install; sudo apt -y autoremove; sudo apt -y autoclean; sudo apt -y clean' 
    alias inst='sudo apt install' 
    alias myip='curl ifconfig.me'
    alias c='clear'
    alias webm-convert='for i in *.webm; do ffmpeg -i "$i" -vn -ar 48000 -ac 2 -ab 320k -f mp3 "${i%.*}.mp3"; done' 
    alias mkv-convert='for i in *.mkv; do ffmpeg -i "$i" -vn -ar 48000 -ac 2 -ab 320k -f mp3 "${i%.*}.mp3"; done' 
    alias mp4-convert='for i in *.mp4; do ffmpeg -i "$i" -vn -ar 48000 -ac 2 -ab 320k -f mp3 "${i%.*}.mp3"; done'  
    alias m4a-convert='for i in *.m4a; do ffmpeg -i "$i" -vn -ar 48000 -ac 2 -ab 320k -f mp3 "${i%.*}.mp3"; done' 
     
    export LESS_TERMCAP_mb=$'\E[1;31m'     # begin blink 
    export LESS_TERMCAP_md=$'\E[1;36m'     # begin bold 
    export LESS_TERMCAP_me=$'\E[0m'        # reset bold/blink 
    export LESS_TERMCAP_so=$'\E[01;33m'    # begin reverse video 
    export LESS_TERMCAP_se=$'\E[0m'        # reset reverse video 
    export LESS_TERMCAP_us=$'\E[1;32m'     # begin underline 
    export LESS_TERMCAP_ue=$'\E[0m'        # reset underline 
fi
```

# MAC

## .zshrc file

```sh
setopt nobeep autocd

# PROMPT="%F{cyan}%U%~%u%f$ %F{green}%B"
# preexec () { print -Pn "%b%f" }
# RPROMPT="%(?..%F{red}%?🚫%f)"
# printf "\033]0;`date "+%a %d %b %Y %I:%M %p"`\007"

# tema
fpath+=~/pure
autoload -Uz promptinit
promptinit
prompt fade

# optionally define some options
PURE_CMD_MAX_EXEC_TIME=10

# change the path color
zstyle :prompt:pure:path color white

# change the color for both `prompt:success` and `prompt:error`
zstyle ':prompt:pure:prompt:*' color cyan

# turn on git stash status
zstyle :prompt:pure:git:stash show yes

prompt pure


autoload -Uz compinit
fpath+=~/.zshfn
compinit
zstyle ':completion:ls:*' menu yes select
zstyle ':completion:*:default' list-colors \
    "di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"

alias l='ls -Fhl' ll='ls -aFhl' dir='ls -aFhl'
alias grep='grep --color=auto'
alias darkmode="osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode'"
alias -- -='cd -' ...='cd ../..'
alias -s {md,yaml,yml}='open /Applications/Visual\ Studio\ Code.app'
alias -s log='tail -n10'
alias -g 2clip='| pbcopy'
alias -g clip2='pbpaste |'
alias text='open -a textedit'
alias ll="ls -lthra"
alias up="softwareupdate -ira; brew update; brew upgrade; brew cleanup"
alias c="clear"
alias pi=''
alias proxmox=''
alias ubu=''
alias master=''
alias python3="/usr/local/bin/python3.10"
alias yt-dlp-n='yt-dlp -f bestvideo+bestaudio'
alias yt-dlp-p="yt-dlp -f bestvideo+bestaudio -o '%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s'"


# https://www.mybyways.com/blog/macos-zsh-configuration"
eval $(/opt/homebrew/bin/brew shellenv)

source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
```

## pure file
- I'm using this for as themes in zshrc file
- you can copy paste the code below (create pure file localy) or go to the site to download it  
--> source [HERE](https://github.com/sindresorhus/pure)
- adjust the ***path*** for pure in .zshrc file

to install plugins in vim
```sh
curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
```

Enter vim and :PlugUpdate
Molokai - [molokai.vim](https://www.vim.org/scripts/download_script.php?src_id=9750)

Install pure - brew install pure

