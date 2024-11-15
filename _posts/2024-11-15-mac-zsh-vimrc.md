---
title: zsh & vimrc file
tags: Mac
---
---
# MAC

## ~/.vimrc file

- I'm using molokai color theme so [this](https://www.vim.org/scripts/download_script.php?src_id=9750) is needed and copy it to your local folder ***(eq. ~/.vim/colors)***.

do a 
```sh
curl -o ~/.vim/colors/molokai.vim https://www.vim.org/scripts/download_script.php?src_id=9750 && mkdir -p ~/.vim/colors
# or
mkdir -p ~/.vim/colors && wget -O ~/.vim/colors/molokai.vim https://www.vim.org/scripts/download_script.php?src_id=9750
```

```sh
set nocompatible
syntax on
colorscheme molokai
filetype off
filetype plugin indent on
set backspace=indent,eol,start
set colorcolumn=100
set cursorcolumn
set shiftwidth=2
set autoindent
set smartindent
set cursorline
set expandtab
set hidden
set history=1000
set hlsearch
set ignorecase
set incsearch
set mouse=a
set nofoldenable
set nowrap
set number
set ruler
set showmatch
set smartcase
set softtabstop=2
set tabstop=2
set title
set wildmenu
set wildmode=list:longest

nnoremap <space> :

nnoremap <F3> :NERDTreeToggle<cr>
let NERDTreeIgnore=['\.git$', '\.jpg$', '\.mp4$', '\.ogg$', '\.iso$', '\.pdf$', '\.pyc$', '\.odt$', '\.png$', '\.gif$', '\.db$']
let g:vim_markdown_conceal = 2
let g:vim_markdown_conceal_code_blocks = 0
let g:vim_markdown_math = 1
let g:vim_markdown_toml_frontmatter = 1
let g:vim_markdown_frontmatter = 1
let g:vim_markdown_strikethrough = 1
let g:vim_markdown_autowrite = 1
let g:vim_markdown_edit_url_in = 'tab'
let g:vim_markdown_follow_anchor = 1
set statusline=
set statusline+=\ %F\ %M\ %Y\ %R
set statusline+=%=
set statusline+=\ ascii:\ %b\ hex:\ 0x%B\ row:\ %l\ col:\ %c\ percent:\ %p%%
set laststatus=2

call plug#begin()
Plug 'junegunn/vim-plug'
Plug 'tpope/vim-surround'
Plug 'junegunn/fzf'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-unimpaired'
Plug 'preservim/nerdtree'
Plug 'rafi/awesome-vim-colorschemes'
Plug 'itchyny/lightline.vim'
Plug 'godlygeek/tabular'
Plug 'plasticboy/vim-markdown'
call plug#end()
set nomodeline
```
install:
```sh
curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
```
and update plugins with:
```sh
:PlugInstall
```
