---
title: vimrc file
tags: Linux
---

---

# Linux
## vimrc file modified for my purposes

---

```sh
" All system-wide defaults are set in $VIMRUNTIME/debian.vim and sourced by 
" the call to :runtime you can find below.  If you wish to change any of those 
" settings, you should do it in this file (/etc/vim/vimrc), since debian.vim 
" will be overwritten everytime an upgrade of the vim packages is performed. 
" It is recommended to make changes after sourcing debian.vim since it alters 
" the value of the 'compatible' option. 
 
" This line should not be removed as it ensures that various options are 
" properly set to work with the Vim-related packages available in Debian. 
runtime! debian.vim 
 
" Vim will load $VIMRUNTIME/defaults.vim if the user does not have a vimrc. 
" This happens after /etc/vim/vimrc(.local) are loaded, so it will override 
" any settings in these files. 
" If you don't want that to happen, uncomment the below line to prevent 
" defaults.vim from being loaded. 
" let g:skip_defaults_vim = 1 
 
" Uncomment the next line to make Vim more Vi-compatible 
" NOTE: debian.vim sets 'nocompatible'.  Setting 'compatible' changes numerous 
" options, so any other options should be set AFTER setting 'compatible'. 
"set compatible 
 
" Vim5 and later versions support syntax highlighting. Uncommenting the next 
" line enables syntax highlighting by default. 
if has("syntax") 
  syntax on 
endif 
 
" If using a dark background within the editing area and syntax highlighting 
" turn on this option as well 
set background=dark 
 
" Uncomment the following to have Vim jump to the last position when 
" reopening a file 
"if has("autocmd") 
"  au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif 
"endif 
 
" Uncomment the following to have Vim load indentation rules and plugins 
" according to the detected filetype. 
if has("autocmd") 
  filetype plugin indent on 
endif 
 
" The following are commented out as they cause vim to behave a lot 
" differently from regular Vi. They are highly recommended though. 
set showcmd             " Show (partial) command in status line. 
set showmatch           " Show matching brackets. 
set ignorecase          " Do case insensitive matching 
set smartcase           " Do smart case matching 
set incsearch           " Incremental search 
set autowrite           " Automatically save before commands like :next and :make 
set hidden              " Hide buffers when they are abandoned 
set mouse=a             " Enable mouse usage (all modes) 
colorscheme delek 
set tabstop=4 
set softtabstop=4 
set expandtab 
set number 
set cursorline 
filetype indent on 
set wildmenu 
set lazyredraw 
set incsearch 
set hlsearch 
nnoremap <leader><space> :nohlsearch<CR> 
set foldmethod=indent 
 
 
 
" Source a global configuration file if available 
if filereadable("/etc/vim/vimrc.local") 
  source /etc/vim/vimrc.local 
endif
```

# MAC
## vimrc file modified for my purposes

- I'm using molokai color theme so [this](https://www.vim.org/scripts/script.php?script_id=2340) is needed and copy it to your local folder ***(eq. ~/.vim/colors)***.
 
```sh
syntax enable
colorscheme molokai
set syntax=on
set cursorline
set cursorcolumn
set nocompatible
set autoindent
set nomodeline
set expandtab
set tabstop=2
set softtabstop=2
set shiftwidth=4
set shiftround
set hidden
set number
set relativenumber
set nowrap
set ruler
set colorcolumn=100
set incsearch
set hlsearch
set ignorecase
set smartcase
set splitbelow
set splitright
set showcmd
set showmatch
set showmode
set autowrite
set mouse=a
set cursorline
set wildmenu
set lazyredraw
set backspace=indent,eol,start
set scrolloff=15
set history=1000
set wildmode=list:longest
set autoread
set mouse=a

inoremap jj <Esc>

nnoremap <space> :

nnoremap o o<esc>
nnoremap O O<esc>

nnoremap n nzz
nnoremap N Nzz

nnoremap Y y$


nnoremap <c-j> <c-w>j
nnoremap <c-k> <c-w>k
nnoremap <c-h> <c-w>h
nnoremap <c-l> <c-w>l

noremap <c-up> <c-w>+
noremap <c-down> <c-w>-
noremap <c-left> <c-w>>
noremap <c-right> <c-w><

nnoremap <F3> :NERDTreeToggle<cr>

let NERDTreeIgnore=['\.git$', '\.jpg$', '\.mp4$', '\.ogg$', '\.iso$', '\.pdf$', '\.pyc$', '\.odt$', '\.png$', '\.gif$', '\.db$']

set statusline=
set statusline+=\ %F\ %M\ %Y\ %R
set statusline+=%=
set statusline+=\ ascii:\ %b\ hex:\ 0x%B\ row:\ %l\ col:\ %c\ percent:\ %p%%
set laststatus=2

call plug#begin()
  Plug 'junegunn/vim-plug'
  Plug 'tpope/vim-surround'
  Plug 'tpope/vim-fugitive'
  Plug 'tpope/vim-unimpaired'
  Plug 'preservim/nerdtree'
  Plug 'rafi/awesome-vim-colorschemes'
  Plug 'itchyny/lightline.vim'
  Plug 'JamshedVesuna/vim-markdown-preview'
call plug#end()
```