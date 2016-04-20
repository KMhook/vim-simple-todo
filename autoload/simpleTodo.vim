let s:buf_name = '__todo__'
let s:todo_info = []
let s:todo_type = ['todo', 'fixme', 'note']
let s:todo_patterns = ["TODO[^a-zA-Z]", "FIXME[^a-zA-Z]"]

let s:tag_arg_pattern = '\v\:(\"[^\"]+\"|[^\ ]+)'

let s:tag_pattern = '\v\@[^\ ]+(\ ' . strpart(s:tag_arg_pattern, 2) . ')?'
let s:sort_comp = 's:LineComparator'
let s:help_view = 0


" TODO MappingKeys
function! s:MappingKeys() abort
  nnoremap <script> <silent> <buffer> sp :call <SID>SetSortByPriority()<CR> :call <SID>UpdateWindow()<CR>
  nnoremap <script> <silent> <buffer> st :call <SID>SetSortByType()<CR> :call <SID>UpdateWindow()<CR>
  nnoremap <script> <silent> <buffer> r :call <SID>UpdateWindow()<CR>
  nnoremap <script> <silent> <buffer> <CR> :call <SID>MoveToActiveLabel()<CR>
  nnoremap <script> <silent> <buffer> q :call <SID>CloseWindow()<CR>
endfunction

function! s:goto_win(winnr, ...) abort
    let cmd = type(a:winnr) == type(0) ? a:winnr . 'wincmd w'
                \ : 'wincmd ' . a:winnr
    let noauto = a:0 > 0 ? a:1 : 0

    echom cmd
    if noauto
        noautocmd execute cmd
    else 
        echom "hello world" . cmd
        execute cmd
        "wincmd p
    endif
endfunction

" Create string describing label
function! s:GetInfoStr(todo_item)
  let result = '[' . a:todo_item.type . ']' . a:todo_item.text

  if len(a:todo_item.tags) > 0
    let result .= " "
    for tag in a:todo_item.tags
      if !has_key(tag, 'arg') || tag.arg == ''
        let result .= tag.name . " "
      else
        let result .= tag.name . " " . tag.arg . " "
      endif
    endfor
  endif

  return s:StrTrim(result)
endfunction


" Functions for sorting labels
function! s:TypeComparator(lval, rval)
  return a:lval.type == a:rval.line ? 0 : a:lval.line > a:rval.line ? 1 : -1
endfunction

function! s:LineComparator(lval, rval)
  return a:lval.line == a:rval.line ? 0 : a:lval.line > a:rval.line ? 1 : -1
endfunction

" TODO: PriorityComparator & AuthorComparator

function! s:PriorityComparator(lval, rval)
  return 0
endfunction

function! s:AuthorComparator(lval, rval)
  return 0
endfunction

function! s:SetSortByType()
  let s:sort_comp = 's:TypeComparator'
endfunction

function! s:SetSortByPriority()
  let s:sort_comp = 's:PriorityComparator'
endfunction

function! s:SetSortByLine()
  let s:sort_comp = 's:LineComparator'
endfunction

function! s:SetSortByAuthor()
  let s:sort_comp = 's:AuthorComparator'
endfunction



" TODO InitWindow
function! s:InitWindow() abort
  setlocal filetype=todo
  setlocal readonly
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal nobuflisted
  setlocal nomodifiable
  setlocal nolist
  setlocal wrap
  setlocal textwidth=0
  setlocal nospell
  setlocal nonumber

  call s:MappingKeys()

  if exists('g:todo_winheight')
      execute 'resize ' . g:todo_winheight . '<CR>;
  endif
endfunction

" TODO OpenWindow
function! s:OpenWindow()
    let todowinnr = bufwinnr(s:buf_name)

    if todowinnr == -1
        call s:OpenWinAndStay()
        call s:goto_win("p")
    endif
endfunction

" TODO CloseWindow
function! s:CloseWindow()
    let todowinnr = bufwinnr(s:buf_name)

    if todowinnr != -1
        call s:goto_win(todowinnr)
        q!
        "close
        call s:goto_win("p")
    endif
endfunction

" TODO s:ToggleWindow
function! s:ToggleWindow() 
    let todowinnr = bufwinnr(s:buf_name)
    if todowinnr == -1
        call s:OpenWindow()
    else 
        call s:CloseWindow()
    endif
endfunction

" TODO UpdateWindow
" update content in window
function! s:UpdateWindow() 
  if s:help_view == 1
    return
  endif

  let cursor_pos = getcurpos()

  setlocal modifiable
  setlocal noreadonly
  execute "normal! ggdG"

  if len(s:todo_info) == 0
    silent 0put = '\" Nothing yet('
  else 
    silent 0put = '\" Press ? for help'
    silent put _

    let s:todo_info = sort(s:todo_info, s:sort_comp)
    for item in s:todo_info
      silent put = s:GetInfoStr(item)
    endfor
  endif

  " Erase last space string
  execute "normal! Gdd"
  setlocal nomodifiable
  setlocal readonly

  call setpos('.', cursor_pos)
endfunction

function! s:OpenWinAndStay() abort
    let todowinnr = bufwinnr(s:buf_name)

    if todowinnr == -1
        call s:ToDoUpdate()

        execute 'silent keepalt topleft split '.s:buf_name

        call s:InitWindow()
        call s:UpdateWindow()
        call setpos('.', [0,0,0,0])
    endif
endfunction

function! s:GetLabelByCursorPos()
  let label_info_line_inx = 3

  if bufname('%') != s:buf_name
    return {}
  endif

  "range of string indexes with info about labels
  let avail_range = [label_info_line_inx, label_info_line_inx + (len(s:todo_info)-1)]

  let cur_line = line('.')
  if cur_line < avail_range[0] || cur_line - avail_range[1]
    return {}
  endif

  return get(s:todo_info, cur_line - avail_range[0], {})
endfunction

function! s:ViewActiveLabel()
  let label_info = s:GetLabelByCursorPos()

  if label_info == {}
    return
  endif


  call s:goto_win('p')
  call setpos('.', [0,label_info.line,0,0])
  normal! zz
  "normal! dd
  "call s:goto_win(bufwinnr(s:buf_name))
endfunction

function! s:MoveToActiveLabel()
  call s:ViewActiveLabel()
  "call s:CloseWindow()
endfunction

" TODO: GetMatch
" get the matched string from text
function! s:GetMatch(text, pattern, start)
  let result = ""

  let find_inx_end = matchend(a:text, a:pattern, a:start)
  let find_inx_begin = match(a:text, a:pattern, a:start)

  if find_inx_end == -1
    return ""
  endif

  let result = strpart(a:text, find_inx_begin, find_inx_end - find_inx_begin)
  return result
endfunction

" TODO: GetAllMatches
function! s:GetAllMatches(text, pattern)
  let result = []

  let offset = 0
  while offset != -1
    let find_inx_end = matchend(a:text, a:pattern, offset)
    let find_inx_begin = match(a:text, a:pattern, offset)

    if find_inx_end != -1 && find_inx_begin != -1
      let match = strpart(a:text, find_inx_begin, find_inx_end - find_inx_begin)
      call add(result, match)
    endif

    let offset = find_inx_end
  endwhile

  return result
endfunction

" TODO: StrTrim
function! s:StrTrim(str, ... )
  let re = '\s+'

  if a:0 > 0
    let re = a:1
  endif
  
  let result = substitute(a:str, '\v^'.re, '', '')
  let result = substitute(result, '\v'.re.'$', '', '')

  return result
endfunction

" TOD: ParseTag
function! s:ParseTag(text)
  let tag = {}

  let tag.arg = s:StrTrim(s:GetMatch(a:text, s:tag_arg_pattern, 0))
  let tag.name = s:StrTrim(strpart(a:text, 0, strlen(a:text) - strlen(tag.arg)))

  if strlen(tag.arg) != 0
    let tag.arg = strpart(tag.arg, 1)
  endif

  let tag.arg = s:StrTrim(tag.arg, '\"')

  return tag
endfunction


" TODO: ParseToDoLine
function! s:ParseToDoLine(text, pattern)
  let result = {}

  let result.patt = s:GetMatch(a:text, a:pattern, 0)
  let tags = s:GetAllMatches(a:text, s:tag_pattern)
  let result.tags = []

  for tag_text in tags
    call add(result.tags, s:ParseTag(tag_text))
  endfor

  let result.text = strpart(a:text, matchend(a:text, result.patt))
  let result.text = s:StrTrim(substitute(result.text, s:tag_pattern, '', 'g'))

  return result
endfunction


function! s:ToDoUpdate()
  let result = []
  let cur_pos = getcurpos()

  call setpos('.', [0,0,0,0])

  for inx in range(len(s:todo_patterns))
    let search_pat = s:todo_patterns[inx]
    let pat_type = s:todo_type[inx]
    let find_inx = searchpos(search_pat, 'cn')

    let line_text = getline(find_inx[0])
    while find_inx != [0,0]
      let line_text = getline(find_inx[0])
      let info = s:ParseToDoLine(line_text, search_pat)
      let info.type = pat_type
      let info.line = find_inx[0]

      call add(result, info)
      call setpos(".", [0, find_inx[0]+1, 0, 0])

      if find_inx[0] == line("$")
        break
      endif

      let find_inx = searchpos(search_pat, 'cn', line("$"))
    endwhile

  endfor

  call setpos(".", cur_pos)
  let s:todo_info = result
endfunction

function! simpleTodo#ToggleWindow() abort
  call s:ToggleWindow()
endfunction

function! s:BuildAutoCmds() abort
  augroup TODOAutoCmds
    autocmd!
      if g:todo_autopreview
        execute 'autocmd CursorMoved ' . s:buf_name . ' nested call s:ViewActiveLabel()'
      endif
  augroup END
endfunction
        
function! s:Init() abort    
  call s:BuildAutoCmds()
endfunction

"call s:Init()
