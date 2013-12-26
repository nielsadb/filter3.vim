" TODO
" - Easily enter @/ as term.
" - Preview function in split windows.
" - Reuse same buffer.
" - Allow changes and propagte to original?
" - Keep 'normal' mode?

function! s:CopyContentsFromSource()
  normal! gg"_dG
  let i = 1
  for line in getbufline(b:filter_srcbufid, 1, '$')
    call append('$', printf('%4d:  %s', i, line))
    let i = i + 1
  endfor
  normal! gg"_dd
  redraw
endfunction

function! AcceptSelection()
  let line_nr = matchlist(getline('.'), '^\W*\(\d\+\)')[1]
  call CancelFilter()
  exe 'normal! '.line_nr.'Gzz'
endfunction

function! CancelFilter()
  let targetbufid = b:filter_targetbufid
  silent exe 'buffer '.b:filter_srcbufid
  silent exe 'bwipe! '.targetbufid
endfunction

function! s:PrepareFilterBuffer()
  if !exists('b:filter_terms')
    let srcbufid = bufnr('%')
    let srcft = &ft

    let srcpos = getpos('.')
    normal! H
    let top_row = line('.')
    call setpos('.', srcpos)

    enew
    let b:filter_targetbufid = bufnr('%')
    let b:filter_terms = []
    let b:filter_srcbufid = srcbufid
    setlocal buftype=nofile bufhidden=hide noswapfile winfixheight nowrap
    setlocal nocursorline nonumber
    exe 'setlocal filetype='.srcft

    call s:CopyContentsFromSource()
    exe 'normal! '.top_row.'z+'
    redraw

    nmap <buffer> f     :call StartFiltering()<CR>
    nmap <buffer> <CR>  :call AcceptSelection()<CR>:echo<CR>
    nmap <buffer> <ESC> :call CancelFilter()<CR>:echo<CR>

  else
    setlocal nocursorline nonumber noreadonly
  end
endfunction

function! StartFiltering()
  call s:PrepareFilterBuffer()

  let res = s:EditLoop()
  if res == 3
    call CancelFilter()
  else
    if line('$') == 1
      call AcceptSelection()
    else
      setlocal cursorline readonly
      normal! gg
      if type(res) == 1
        exe 'normal! '.res
      end
    end
  end
endfunction

function! s:EditLoop()
  let terms = b:filter_terms
  let selected  = 0
  let prompt = ''
  let mode = 1 " 0: 'Normal', 1: 'Insert', 2: 'STOP', 3: 'ABORT'

  while mode < 2
    if empty(terms)
        call add(terms, '+')
    end

    echon "\r" repeat(' ', len(prompt))
    let prompt = join(terms, ' ')
    echon "\r" prompt

    let ch = getchar()
    if ch == 32                                     " <Space>
      let ch = 43                                   " +
    end

    if mode == 0                                    " Normal
      if ch == 27                                   " <Esc>
        let mode = 3                                " ABORT
      elseif ch == 13                               " <CR>
        let mode = 2                                " STOP
      elseif ch == 43 || ch == 45 || ch == 124      " + - <Bar>
        let mode = 1                                " Insert
      elseif ch >= 48 && ch <= 57                   " 0 .. 9
        let selected = ch - 48
      elseif type(ch) == 1 && (ch[1:] == 'ku'
                  \ || ch[1:] == 'kd')              " <Up> <Down>
          let mode = 1
      elseif type(ch) == 1 && ch[1:] == 'kb'        " <BS>
        unlet terms[-1]
      end
    end

    if mode == 1                                    " Insert
      if ch == 43 || ch == 45 || ch == 124          " + - <Bar>
        if len(terms[-1]) == 1
          unlet terms[-1]
        end
        call add(terms, nr2char(ch))
      elseif ch == 27                               " <Esc>
        if len(terms) == 1 && len(terms[0]) == 1
          let mode = 3                              " ABORT
        else
          let mode = 0                              " Normal
        end
      elseif ch == 13                               " <CR>
        let mode = 2                                " STOP
      elseif type(ch) == 0                          " No special key
        let terms[-1] = terms[-1].nr2char(ch)
      elseif type(ch) == 1 && ch[1:] == 'ku'        " <Up>
        return 'G'
      elseif type(ch) == 1 && ch[1:] == 'kd'        " <Down>
        return 0
      elseif type(ch) == 1 && ch[1:] == 'kb'        " <BS>
        if len(terms[-1]) > 1
          let terms[-1] = terms[-1][:-2]
        else
          unlet terms[-1]
        end
      end
    end

    if mode < 2
      call MatchingLineNrs()
    end
  endwhile
  return mode
endfunction

function! MatchingLineNrs()
  let alt = []
  let and = []
  let not = []

  for term in b:filter_terms
    if len(term) > 1
      if term[0] == '|'
        call add(alt, term[1:])
      elseif term[0] == '+'
        call add(and, term[1:])
      elseif term[0] == '-'
        call add(not, term[1:])
      end
    end
  endfor

  if !empty(and)
    call add(alt, and[-1])
    unlet and[-1]
  end

  call s:CopyContentsFromSource()

  let searchreg = @/
  if !empty(alt)
    silent! exe '%v/'.join(alt, '\|').'/d'
  end
  if !empty(not)
    silent! exe '%g/'.join(not, '\|').'/d'
  end
  for and_term in and
    silent! exe '%v/'.and_term.'/d'
  endfor
  let @/ = searchreg

  redraw
endfunction

