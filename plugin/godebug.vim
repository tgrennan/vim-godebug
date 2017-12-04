" vim-godebug.vim - Go debugging for Vim
" Maintainer:    Luca Guidi <https://lucaguidi.com>
" Version:       0.1

if !has("nvim")
  echom "vim-godebug: vim is not yet supported, try it with neovim"
  finish
endif

if exists("g:godebug_loaded_install")
  finish
endif
let g:godebug_loaded_install = 1

if !executable("dlv")
  echom "vim-godebug: can't find dlv"
  finish
endif
let s:dlv = exepath("dlv")

if !exists("g:godebug_breakpoint_sign")
    let g:godebug_breakpoint_sign = ">>"
endif

if !exists("g:godebug_breakpoint_sign_highlight")
    let g:godebug_breakpoint_sign_highlight = "SignColumn"
endif

exe "sign define gobreakpoint text=". g:godebug_breakpoint_sign ." texthl=".
	\ g:godebug_breakpoint_sign_highlight

let s:seq = 0
let s:breakpoints = {}
let s:jobid = -1

function! g:GodebugToggleBreakpoint() abort
  let fn = expand('%:p')
  let line = line('.')
  let k = fn .':'. line
  if has_key(s:breakpoints, k)
    call jobsend(s:jobid, ['clear '. s:breakpoints[k], ""])
    unlet s:breakpoints[k]
    exe "sign unplace ". line ." file=". fn
  else
    let s:seq += 1
    let s:breakpoints[k] = 'godebug' . s:seq
    call jobsend(s:jobid, ['break '. s:breakpoints[k] .' '. k, ""])
    exe "sign place ". line ." line=". line ." name=gobreakpoint file=". fn
  endif
endfunction

nnoremap <silent> <Plug>(godebug-toggle-breakpoint)
	\ :<C-U>call g:GodebugToggleBreakpoint()<CR>

function! g:GodebugClearBreakpoints() abort
  if len(s:breakpoints) > 0
    for [key, value] in items(s:breakpoints)
      let [fn, line] = split(key, ':')
      exe "sign unplace ". line ." file=". fn
      unlet s:breakpoints[key]
    endfor
    call jobsend(s:jobid, ['clearall', ""])
  endif
endfunction

nnoremap <silent> <Plug>(godebug-clear-breakpoints)
	\ :<C-U>call g:GodebugClearBreakpoints()<CR>

function! s:godebug(bang, ...) abort
  if a:0 > 0
    if a:1 == "sudo"
      if a:0 > 1
	let cmd = [ "sudo", s:dlv ] + a:000[1:-1]
      else
	let cmd = [ "sudo", s:dlv, "debug" ]
      endif
    else
      let cmd = [ "dlv" ] + a:000
    endif
  else
    let cmd = [ "dlv", "debug" ]
  endif
  let s:jobid = go#term#new(a:bang, cmd)
  return s:jobid
endfunction

function! s:complete(ArgLead, CmdLine, CursorPos) abort
  return filter([ "sudo",
	\ "attach", "connect", "core", "debug", "exec", "test", "trace" ],
	\ 'v:val =~ a:ArgLead')
	\ + split(glob(a:ArgLead . "*"))
endfunction

command! -nargs=* -bang -complete=customlist,s:complete GoDebug
	\ call s:godebug(<bang>0, <f-args>)
