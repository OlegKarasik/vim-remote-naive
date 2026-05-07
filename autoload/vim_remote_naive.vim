let s:root_config_directory_name = 'vim-remote-naive'
let s:root_config_filename = 'config.json'
let s:root_config_remotes_key = 'remotes'
let s:root_config_current_key = 'current'
let s:remote_required_fields = ['source', 'destination', 'connection']
let s:message_prefix = '[vim-remote-naive] '
let s:remote_list_popup_states = {}
let s:remote_pull_active = 0
let s:remote_pull_active_job = v:null
let s:remote_pull_active_buffer_number = -1
let s:remote_pull_terminal_name = ''
let s:remote_pull_started_at = []
let s:remote_pull_progress_timer_id = -1
let s:remote_pull_previous_statusline = v:null
let s:remote_pull_cancel_requested = 0
let s:remote_pull_statusline_highlight = 'WarningMsg'

function! s:notify(message) abort
  echom s:message_prefix . a:message
endfunction

function! s:notify_error(message) abort
  echohl ErrorMsg
  echom s:message_prefix . a:message
  echohl None
endfunction

function! s:to_string_or_empty(value) abort
  return type(a:value) == v:t_string ? a:value : string(a:value)
endfunction

function! s:elapsed_seconds_since(started_at) abort
  if type(a:started_at) != v:t_list || empty(a:started_at)
    return 0
  endif

  let l:elapsed_text = reltimestr(reltime(a:started_at))
  let l:seconds_text = matchstr(l:elapsed_text, '^\s*\zs\d\+')
  if empty(l:seconds_text)
    return 0
  endif

  return str2nr(l:seconds_text)
endfunction

function! s:format_elapsed_clock(elapsed_seconds) abort
  let l:elapsed_seconds = type(a:elapsed_seconds) == v:t_number
        \ ? a:elapsed_seconds
        \ : str2nr(s:to_string_or_empty(a:elapsed_seconds))
  let l:elapsed_seconds = max([0, l:elapsed_seconds])
  let l:hours = l:elapsed_seconds / 3600
  let l:minutes = (l:elapsed_seconds % 3600) / 60
  let l:seconds = l:elapsed_seconds % 60
  return printf('%02d:%02d:%02d', l:hours, l:minutes, l:seconds)
endfunction

function! s:format_elapsed_runtime(elapsed_seconds) abort
  return '[' . s:format_elapsed_clock(a:elapsed_seconds) . ']'
endfunction

function! s:statusline_escape_text(text) abort
  return substitute(s:to_string_or_empty(a:text), '%', '%%', 'g')
endfunction

function! s:set_global_statusline(message, highlight_group) abort
  let l:message = s:statusline_escape_text(a:message)
  if empty(l:message)
    return
  endif

  let l:highlight_group = trim(s:to_string_or_empty(a:highlight_group))
  if empty(l:highlight_group)
    let &g:statusline = l:message
  else
    let &g:statusline = '%#' . l:highlight_group . '#' . l:message . '%=%*'
  endif

  silent! redrawstatus
endfunction

function! s:remember_global_statusline_for_remote_pull() abort
  let s:remote_pull_previous_statusline = &g:statusline
endfunction

function! s:restore_global_statusline_from_remote_pull() abort
  if s:remote_pull_previous_statusline is v:null
    return
  endif

  let &g:statusline = s:to_string_or_empty(s:remote_pull_previous_statusline)
  let s:remote_pull_previous_statusline = v:null
  silent! redrawstatus
endfunction

function! s:remote_pull_progress_message(elapsed_seconds, terminal_name) abort
  let l:terminal_name = trim(s:to_string_or_empty(a:terminal_name))
  if empty(l:terminal_name)
    return ''
  endif

  return l:terminal_name . ' ' . s:format_elapsed_runtime(a:elapsed_seconds)
endfunction

function! s:write_remote_pull_progress() abort
  if !s:remote_pull_active
    return
  endif

  let l:message = s:remote_pull_progress_message(
        \ s:elapsed_seconds_since(s:remote_pull_started_at),
        \ s:remote_pull_terminal_name)
  if empty(l:message)
    return
  endif

  call s:set_global_statusline(l:message, s:remote_pull_statusline_highlight)
endfunction

function! s:on_remote_pull_progress_tick(timer_id) abort
  if !s:remote_pull_active || s:remote_pull_progress_timer_id != a:timer_id
    if exists('*timer_stop')
      call timer_stop(a:timer_id)
    endif
    return
  endif

  call s:write_remote_pull_progress()
endfunction

function! s:start_remote_pull_progress() abort
  call s:stop_remote_pull_progress()
  call s:remember_global_statusline_for_remote_pull()
  call s:write_remote_pull_progress()

  if exists('*timer_start')
    let l:timer_id = timer_start(
          \ 1000,
          \ function('s:on_remote_pull_progress_tick'),
          \ {'repeat': -1})
    if type(l:timer_id) == v:t_number && l:timer_id > 0
      let s:remote_pull_progress_timer_id = l:timer_id
    endif
  endif
endfunction

function! s:stop_remote_pull_progress() abort
  if exists('*timer_stop')
        \ && type(s:remote_pull_progress_timer_id) == v:t_number
        \ && s:remote_pull_progress_timer_id > 0
    call timer_stop(s:remote_pull_progress_timer_id)
  endif
  let s:remote_pull_progress_timer_id = -1
  call s:restore_global_statusline_from_remote_pull()
endfunction

function! s:write_remote_pull_completion(terminal_name, elapsed_seconds, exit_code) abort
  let l:terminal_name = trim(s:to_string_or_empty(a:terminal_name))
  if empty(l:terminal_name)
    let l:terminal_name = 'vim-remote-naive:RemotePull'
  endif
  let l:elapsed_runtime = s:format_elapsed_runtime(a:elapsed_seconds)

  if a:exit_code == 0
    call s:notify(l:terminal_name . ' ' . l:elapsed_runtime . ' [Success].')
    return
  endif

  call s:notify_error(
        \ l:terminal_name
        \ . ' '
        \ . l:elapsed_runtime
        \ . ' [Error] (exit code '
        \ . a:exit_code
        \ . ').')
endfunction

function! s:clear_remote_pull_active_state() abort
  call s:stop_remote_pull_progress()
  let s:remote_pull_active = 0
  let s:remote_pull_active_job = v:null
  let s:remote_pull_active_buffer_number = -1
  let s:remote_pull_terminal_name = ''
  let s:remote_pull_started_at = []
  let s:remote_pull_cancel_requested = 0
endfunction

function! s:is_terminal_buffer_job_running(buffer_number) abort
  if a:buffer_number <= 0
        \ || !bufexists(a:buffer_number)
        \ || getbufvar(a:buffer_number, '&buftype', '') !=# 'terminal'
        \ || !exists('*term_getstatus')
    return 0
  endif

  return stridx(term_getstatus(a:buffer_number), 'running') >= 0
endfunction

function! s:is_active_remote_pull_running() abort
  if !s:remote_pull_active
    return 0
  endif

  if s:is_terminal_buffer_job_running(s:remote_pull_active_buffer_number)
    return 1
  endif

  let l:job = s:remote_pull_active_job
  if exists('*term_getjob')
        \ && s:remote_pull_active_buffer_number > 0
        \ && bufexists(s:remote_pull_active_buffer_number)
    let l:job = term_getjob(s:remote_pull_active_buffer_number)
  endif
  let l:exit_code = s:terminal_job_exit_code(l:job, v:null)
  if s:remote_pull_cancel_requested && l:exit_code == 0
    let l:exit_code = -1
  endif
  let l:elapsed_seconds = s:elapsed_seconds_since(s:remote_pull_started_at)
  let l:terminal_name = s:remote_pull_terminal_name
  call s:clear_remote_pull_active_state()
  call s:write_remote_pull_completion(l:terminal_name, l:elapsed_seconds, l:exit_code)
  return 0
endfunction

function! s:set_remote_pull_active_state(job, buffer_number, terminal_name, started_at) abort
  let s:remote_pull_active = 1
  let s:remote_pull_active_job = a:job
  let s:remote_pull_active_buffer_number = a:buffer_number
  let s:remote_pull_terminal_name = a:terminal_name
  let s:remote_pull_started_at = a:started_at
  let s:remote_pull_cancel_requested = 0
  call s:start_remote_pull_progress()
endfunction

function! s:stop_terminal_buffer_job(buffer_number) abort
  if a:buffer_number <= 0
        \ || !bufexists(a:buffer_number)
        \ || getbufvar(a:buffer_number, '&buftype', '') !=# 'terminal'
    return
  endif

  if exists('*term_setkill')
    call term_setkill(a:buffer_number, 'kill')
  endif
  if exists('*term_getjob') && exists('*job_stop')
    let l:job = term_getjob(a:buffer_number)
    if type(l:job) == v:t_number
          \ || (exists('v:t_job') && type(l:job) == v:t_job)
      call job_stop(l:job, 'kill')
    endif
  endif
  if exists('*term_wait')
    call term_wait(a:buffer_number, 50)
  endif
endfunction

function! s:terminal_job_exit_code(job, status) abort
  if type(a:status) == v:t_number
    return a:status
  endif

  let l:status_text = trim(s:to_string_or_empty(a:status))
  if l:status_text =~# '^-\\?\d\+$'
    return str2nr(l:status_text)
  endif

  if !exists('*job_info')
    return 0
  endif

  try
    let l:job_info = job_info(a:job)
  catch
    return 0
  endtry

  if type(l:job_info) == v:t_dict && has_key(l:job_info, 'exitval')
    return str2nr(s:to_string_or_empty(get(l:job_info, 'exitval', 0)))
  endif

  return 0
endfunction

function! s:on_remote_pull_exit(terminal_name, started_at, job, status) abort
  if !s:remote_pull_active || string(s:remote_pull_active_job) !=# string(a:job)
    return
  endif

  let l:elapsed_seconds = s:elapsed_seconds_since(a:started_at)
  let l:exit_code = s:terminal_job_exit_code(a:job, a:status)
  if s:remote_pull_cancel_requested && l:exit_code == 0
    let l:exit_code = -1
  endif

  call s:clear_remote_pull_active_state()
  call s:write_remote_pull_completion(a:terminal_name, l:elapsed_seconds, l:exit_code)
endfunction

function! s:trim_trailing_separators(path) abort
  return substitute(a:path, '[\/\\]\+$', '', '')
endfunction

function! s:with_trailing_separator(path) abort
  if empty(a:path) || a:path =~# '[\/\\]$'
    return a:path
  endif
  return a:path . '/'
endfunction

function! s:expand_tilde_home_path(path) abort
  if a:path !=# '~'
        \ && strpart(a:path, 0, 2) !=# '~/'
        \ && strpart(a:path, 0, 2) !=# "~\\"
    return a:path
  endif

  let l:home_directory = expand('~')
  if empty(l:home_directory)
    return a:path
  endif

  if a:path ==# '~'
    return l:home_directory
  endif

  return s:trim_trailing_separators(l:home_directory) . a:path[1:]
endfunction

function! s:is_windows() abort
  return has('win32') || has('win64') || has('win32unix')
endfunction

function! s:is_macos() abort
  return has('mac') || has('macunix')
endfunction

function! s:getenv_or_empty(name) abort
  if exists('*getenv')
    let l:value = getenv(a:name)
    return type(l:value) == v:t_string ? l:value : ''
  endif

  return expand('$' . a:name)
endfunction

function! s:path_join(parts) abort
  let l:non_empty_parts = filter(copy(a:parts), 'type(v:val) == v:t_string && !empty(v:val)')
  return join(l:non_empty_parts, '/')
endfunction

function! s:detected_platform_name() abort
  if s:is_windows()
    return 'windows'
  endif

  if s:is_macos()
    return 'macos'
  endif

  return 'linux'
endfunction

function! s:config_home_for(platform_name, home, appdata, xdg_config_home) abort
  let l:platform_name = tolower(trim(a:platform_name))
  let l:home = empty(a:home) ? expand('~') : a:home

  if l:platform_name ==# 'windows'
    if !empty(a:appdata)
      return s:trim_trailing_separators(a:appdata)
    endif

    return s:path_join([l:home, 'AppData', 'Roaming'])
  endif

  if l:platform_name ==# 'macos'
    return s:path_join([l:home, 'Library', 'Application Support'])
  endif

  if !empty(a:xdg_config_home)
    return s:trim_trailing_separators(a:xdg_config_home)
  endif

  return s:path_join([l:home, '.config'])
endfunction

function! vim_remote_naive#root_config_file_path_for(platform_name, home, appdata, xdg_config_home) abort
  let l:config_home = s:config_home_for(a:platform_name, a:home, a:appdata, a:xdg_config_home)
  let l:config_dir = s:path_join([l:config_home, s:root_config_directory_name])
  return s:path_join([l:config_dir, s:root_config_filename])
endfunction

function! vim_remote_naive#root_config_file_path() abort
  if exists('g:vim_remote_naive_root_config_file_path_override')
    return fnamemodify(g:vim_remote_naive_root_config_file_path_override, ':p')
  endif

  if exists('g:vim_remote_naive_config_file_path_override')
    return fnamemodify(g:vim_remote_naive_config_file_path_override, ':p')
  endif

  return vim_remote_naive#root_config_file_path_for(
        \ s:detected_platform_name(),
        \ expand('~'),
        \ s:getenv_or_empty('APPDATA'),
        \ s:getenv_or_empty('XDG_CONFIG_HOME'))
endfunction

function! vim_remote_naive#config_file_path_for(platform_name, home, appdata, xdg_config_home) abort
  return vim_remote_naive#root_config_file_path_for(a:platform_name, a:home, a:appdata, a:xdg_config_home)
endfunction

function! vim_remote_naive#config_file_path() abort
  return vim_remote_naive#root_config_file_path()
endfunction

function! s:default_root_config_lines() abort
  return [
        \ '{',
        \ '  "version": 1,',
        \ '  "remotes": []',
        \ '}'
        \ ]
endfunction

function! s:ensure_root_configuration_exists(root_config_file_path) abort
  let l:root_config_dir_path = fnamemodify(a:root_config_file_path, ':h')
  if !isdirectory(l:root_config_dir_path)
    call mkdir(l:root_config_dir_path, 'p')
    if !isdirectory(l:root_config_dir_path)
      call s:notify_error('Failed to create Root Configuration directory: ' . l:root_config_dir_path)
      return 0
    endif
  endif

  if filereadable(a:root_config_file_path)
    return 1
  endif

  let l:write_result = writefile(s:default_root_config_lines(), a:root_config_file_path)
  if l:write_result != 0 || !filereadable(a:root_config_file_path)
    call s:notify_error('Failed to write Root Configuration file: ' . a:root_config_file_path)
    return 0
  endif

  call s:notify('Created Root Configuration: ' . a:root_config_file_path)
  return 1
endfunction

function! s:is_valid_remote_item(remote_item, remote_index) abort
  if type(a:remote_item) != v:t_dict
    call s:notify_error('Invalid remote entry #' . (a:remote_index + 1) . ': expected an object.')
    return 0
  endif

  for l:key in s:remote_required_fields
    if !has_key(a:remote_item, l:key) || type(a:remote_item[l:key]) != v:t_string
      call s:notify_error(
            \ 'Invalid remote entry #' . (a:remote_index + 1)
            \ . ': missing string field "' . l:key . '".')
      return 0
    endif
  endfor

  return 1
endfunction

function! s:is_valid_current_remote(remote_item) abort
  if type(a:remote_item) != v:t_dict
    call s:notify_error('Root Configuration "current" must be an object. Run :RemoteSwitch to select a remote.')
    return 0
  endif

  for l:key in s:remote_required_fields
    if !has_key(a:remote_item, l:key) || type(a:remote_item[l:key]) != v:t_string
      call s:notify_error(
            \ 'Root Configuration "current" is missing string field "' . l:key
            \ . '". Run :RemoteSwitch to select a remote.')
      return 0
    endif
  endfor

  return 1
endfunction

function! s:read_root_configuration(root_config_file_path) abort
  if !filereadable(a:root_config_file_path)
    call s:notify_error('Root Configuration file not found: '
          \ . a:root_config_file_path . '. Run :RemoteConfig first.')
    return v:null
  endif

  if !exists('*json_decode')
    call s:notify_error('json_decode() is not available in this Vim build.')
    return v:null
  endif

  let l:root_config_text = join(readfile(a:root_config_file_path), "\n")
  try
    let l:root_configuration = json_decode(l:root_config_text)
  catch /^Vim\%((\a\+)\)\=:E474/
    call s:notify_error('Root Configuration contains invalid JSON: ' . a:root_config_file_path)
    return v:null
  endtry

  if type(l:root_configuration) != v:t_dict
    call s:notify_error('Root Configuration must be a JSON object: ' . a:root_config_file_path)
    return v:null
  endif

  if !has_key(l:root_configuration, s:root_config_remotes_key)
    call s:notify_error('Root Configuration is missing "' . s:root_config_remotes_key . '" array.')
    return v:null
  endif

  let l:remotes = l:root_configuration[s:root_config_remotes_key]
  if type(l:remotes) != v:t_list
    call s:notify_error('Root Configuration field "' . s:root_config_remotes_key . '" must be an array.')
    return v:null
  endif

  for l:remote_index in range(len(l:remotes))
    if !s:is_valid_remote_item(l:remotes[l:remote_index], l:remote_index)
      return v:null
    endif
  endfor

  return l:root_configuration
endfunction

function! s:write_root_configuration(root_config_file_path, root_configuration) abort
  if !exists('*json_encode')
    call s:notify_error('json_encode() is not available in this Vim build.')
    return 0
  endif

  if type(a:root_configuration) != v:t_dict
    call s:notify_error('Internal error: Root Configuration payload must be an object.')
    return 0
  endif

  let l:write_result = writefile([json_encode(a:root_configuration)], a:root_config_file_path)
  if l:write_result != 0
    call s:notify_error('Failed to write Root Configuration file: ' . a:root_config_file_path)
    return 0
  endif

  return 1
endfunction

function! s:same_remote(left, right) abort
  if type(a:left) != v:t_dict || type(a:right) != v:t_dict
    return 0
  endif

  for l:key in s:remote_required_fields
    let l:left_value = get(a:left, l:key, v:null)
    let l:right_value = get(a:right, l:key, v:null)
    if type(l:left_value) != v:t_string
          \ || type(l:right_value) != v:t_string
          \ || l:left_value !=# l:right_value
      return 0
    endif
  endfor

  return 1
endfunction

function! s:find_current_remote_index(remotes, current_remote) abort
  if type(a:current_remote) != v:t_dict
    return -1
  endif

  for l:remote_index in range(len(a:remotes))
    if s:same_remote(a:remotes[l:remote_index], a:current_remote)
      return l:remote_index
    endif
  endfor

  return -1
endfunction

function! s:remote_selection_line(remote_item, is_current) abort
  let l:prefix = a:is_current ? '* ' : '  '
  return l:prefix
        \ . a:remote_item['connection']
        \ . ' | '
        \ . a:remote_item['source']
        \ . ' -> '
        \ . a:remote_item['destination']
endfunction

function! s:remote_selection_lines(remotes, current_remote_index) abort
  let l:lines = []
  for l:remote_index in range(len(a:remotes))
    call add(
          \ l:lines,
          \ s:remote_selection_line(
          \   a:remotes[l:remote_index],
          \   l:remote_index == a:current_remote_index))
  endfor
  return l:lines
endfunction

function! s:remote_indexes(remotes) abort
  if empty(a:remotes)
    return []
  endif
  return range(len(a:remotes))
endfunction

function! s:filtered_remote_indexes(remotes, search_query) abort
  let l:normalized_query = tolower(a:search_query)
  if empty(l:normalized_query)
    return s:remote_indexes(a:remotes)
  endif

  let l:indexes = []
  for l:remote_index in range(len(a:remotes))
    let l:search_text = tolower(
          \ a:remotes[l:remote_index]['connection']
          \ . ' '
          \ . a:remotes[l:remote_index]['source']
          \ . ' '
          \ . a:remotes[l:remote_index]['destination'])
    if stridx(l:search_text, l:normalized_query) >= 0
      call add(l:indexes, l:remote_index)
    endif
  endfor
  return l:indexes
endfunction

function! s:remote_selection_lines_for_indexes(remotes, current_remote_index, remote_indexes) abort
  let l:lines = []
  for l:remote_index in a:remote_indexes
    call add(
          \ l:lines,
          \ s:remote_selection_line(
          \   a:remotes[l:remote_index],
          \   l:remote_index == a:current_remote_index))
  endfor
  return l:lines
endfunction

function! s:remote_selection_popup_title(prompt_title, search_query, search_mode) abort
  let l:title = a:prompt_title
  if !empty(a:search_query)
    let l:title .= ' [' . a:search_query . ']'
  endif
  if a:search_mode
    let l:title .= ' (SEARCH)'
  endif
  return l:title
endfunction

function! s:remote_selection_popup_display_lines(remotes, current_remote_index, filtered_remote_indexes) abort
  if empty(a:filtered_remote_indexes)
    return ['1.   no matches']
  endif

  return s:remote_selection_lines_for_indexes(
        \ a:remotes,
        \ a:current_remote_index,
        \ a:filtered_remote_indexes)
endfunction

function! s:refresh_remote_selection_popup(popup_id) abort
  let l:state = get(s:remote_list_popup_states, a:popup_id, {})
  if empty(l:state)
    return
  endif

  let l:remotes = l:state.root_configuration[s:root_config_remotes_key]
  let l:current_remote_index = s:find_current_remote_index(
        \ l:remotes,
        \ get(l:state.root_configuration, s:root_config_current_key, v:null))
  let l:filtered_remote_indexes = s:filtered_remote_indexes(l:remotes, l:state.search_query)
  let l:state.filtered_remote_indexes = l:filtered_remote_indexes

  call popup_setoptions(a:popup_id, {
        \ 'title': s:remote_selection_popup_title(
        \   l:state.prompt_title,
        \   l:state.search_query,
        \   l:state.search_mode),
        \ 'minheight': 1,
        \ 'maxheight': 10
        \ })
  call popup_settext(
        \ a:popup_id,
        \ s:remote_selection_popup_display_lines(
        \   l:remotes,
        \   l:current_remote_index,
        \   l:filtered_remote_indexes))

  if exists('*win_execute')
    call win_execute(a:popup_id, 'normal! gg')
  endif
endfunction

function! s:is_popup_enter_key(key) abort
  return a:key ==# "\<CR>" || a:key ==# "\<Enter>"
endfunction

function! s:is_popup_escape_key(key) abort
  return a:key ==# "\<Esc>"
endfunction

function! s:is_popup_backspace_key(key) abort
  return a:key ==# "\<BS>" || a:key ==# "\<C-H>"
endfunction

function! s:is_popup_delete_key(key) abort
  return a:key ==# "\<Del>" || a:key ==# "\<kDel>"
endfunction

function! s:is_printable_popup_key(key) abort
  return strchars(a:key) == 1
        \ && char2nr(a:key) >= 32
        \ && char2nr(a:key) != 127
endfunction

function! s:popup_query_without_last_char(search_query) abort
  let l:query_length = strchars(a:search_query)
  if l:query_length <= 0
    return ''
  endif
  return strcharpart(a:search_query, 0, l:query_length - 1)
endfunction

function! s:rounded_border_chars() abort
  return [
        \ nr2char(0x2500),
        \ nr2char(0x2502),
        \ nr2char(0x2500),
        \ nr2char(0x2502),
        \ nr2char(0x256D),
        \ nr2char(0x256E),
        \ nr2char(0x256F),
        \ nr2char(0x2570)
        \ ]
endfunction

function! s:select_remote_with_inputlist(selection_lines) abort
  let l:menu_lines = ['Select active remote (0 to cancel):']
  for l:line_index in range(len(a:selection_lines))
    call add(l:menu_lines, printf('%d. %s', l:line_index + 1, a:selection_lines[l:line_index]))
  endfor
  return inputlist(l:menu_lines)
endfunction

function! s:apply_remote_selection(root_config_file_path, root_configuration, selection_result) abort
  let l:selection_result = type(a:selection_result) == v:t_number
        \ ? a:selection_result
        \ : str2nr(a:selection_result)

  if l:selection_result <= 0
    call s:notify('Remote selection cancelled.')
    return
  endif

  let l:remotes = a:root_configuration[s:root_config_remotes_key]
  let l:selected_index = l:selection_result - 1
  if l:selected_index < 0 || l:selected_index >= len(l:remotes)
    call s:notify_error('Invalid remote selection: ' . l:selection_result)
    return
  endif

  let l:selected_remote = deepcopy(l:remotes[l:selected_index])
  let l:updated_root_configuration = deepcopy(a:root_configuration)
  let l:updated_root_configuration[s:root_config_current_key] = l:selected_remote

  if !s:write_root_configuration(a:root_config_file_path, l:updated_root_configuration)
    return
  endif

  call s:notify('Active remote set to: ' . l:selected_remote['connection'])
endfunction

function! s:on_remote_list_popup_done(popup_id, result) abort
  if !has_key(s:remote_list_popup_states, a:popup_id)
    return
  endif

  let l:state = s:remote_list_popup_states[a:popup_id]
  call remove(s:remote_list_popup_states, a:popup_id)

  let l:selection_result = type(a:result) == v:t_number
        \ ? a:result
        \ : str2nr(a:result)
  if l:selection_result <= 0
    call s:apply_remote_selection(
          \ l:state.root_config_file_path,
          \ l:state.root_configuration,
          \ l:selection_result)
    return
  endif

  let l:filtered_remote_indexes = get(l:state, 'filtered_remote_indexes', [])
  let l:filtered_selection_index = l:selection_result - 1
  if l:filtered_selection_index < 0 || l:filtered_selection_index >= len(l:filtered_remote_indexes)
    call s:notify('Remote selection cancelled.')
    return
  endif

  call s:apply_remote_selection(
        \ l:state.root_config_file_path,
        \ l:state.root_configuration,
        \ l:filtered_remote_indexes[l:filtered_selection_index] + 1)
endfunction

function! s:on_remote_list_popup_filter(popup_id, key) abort
  let l:state = get(s:remote_list_popup_states, a:popup_id, {})
  if empty(l:state)
    return popup_filter_menu(a:popup_id, a:key)
  endif

  if a:key ==# "\<C-F>"
    let l:state.search_mode = !l:state.search_mode
    call s:refresh_remote_selection_popup(a:popup_id)
    return 1
  endif

  if l:state.search_mode
    if a:key ==# "\<C-U>"
      let l:state.search_query = ''
      call s:refresh_remote_selection_popup(a:popup_id)
      return 1
    endif

    if s:is_popup_backspace_key(a:key) || s:is_popup_delete_key(a:key)
      let l:state.search_query = s:popup_query_without_last_char(l:state.search_query)
      call s:refresh_remote_selection_popup(a:popup_id)
      return 1
    endif

    if s:is_popup_escape_key(a:key) || s:is_popup_enter_key(a:key)
      if s:is_popup_enter_key(a:key) && empty(get(l:state, 'filtered_remote_indexes', []))
        return 1
      endif
      return popup_filter_menu(a:popup_id, a:key)
    endif

    if s:is_printable_popup_key(a:key)
      let l:state.search_query .= a:key
      call s:refresh_remote_selection_popup(a:popup_id)
      return 1
    endif
  endif

  return popup_filter_menu(a:popup_id, a:key)
endfunction

function! s:show_remote_selection_popup(root_config_file_path, root_configuration, selection_lines) abort
  if !has('popupwin') || !exists('*popup_menu')
    return 0
  endif

  let l:popup_id = popup_menu(a:selection_lines, {
        \ 'title': 'RemoteSwitch: select active remote',
        \ 'callback': function('s:on_remote_list_popup_done'),
        \ 'filter': function('s:on_remote_list_popup_filter'),
        \ 'mapping': 0,
        \ 'minheight': 1,
        \ 'maxheight': 10,
        \ 'scrollbar': 1,
        \ 'highlight': 'Pmenu',
        \ 'border': [1, 1, 1, 1],
        \ 'borderhighlight': ['Pmenu'],
        \ 'borderchars': s:rounded_border_chars()
        \ })
  if l:popup_id <= 0
    return 0
  endif

  let s:remote_list_popup_states[l:popup_id] = {
        \ 'root_config_file_path': a:root_config_file_path,
        \ 'root_configuration': deepcopy(a:root_configuration),
        \ 'prompt_title': 'RemoteSwitch: select active remote',
        \ 'search_query': '',
        \ 'search_mode': 0,
        \ 'filtered_remote_indexes': s:remote_indexes(
        \   a:root_configuration[s:root_config_remotes_key])
        \ }
  call s:refresh_remote_selection_popup(l:popup_id)
  return 1
endfunction

function! s:remote_pull_transport(connection) abort
  let l:raw_connection = trim(a:connection)
  if empty(l:raw_connection)
    call s:notify_error(
          \ 'Root Configuration "current.connection" is empty.'
          \ . ' Run :RemoteConfig and :RemoteSwitch to select a remote.')
    return v:null
  endif

  let l:ssh_command = 'ssh'
  let l:target = l:raw_connection
  if l:raw_connection =~# '^ssh\>'
    let l:connection_parts = split(l:raw_connection)
    if len(l:connection_parts) < 2
      call s:notify_error(
            \ 'Root Configuration "current.connection" must include SSH target.'
            \ . ' Run :RemoteConfig and :RemoteSwitch to select a remote.')
      return v:null
    endif

    let l:target = l:connection_parts[-1]
    let l:ssh_parts = l:connection_parts[0 : len(l:connection_parts) - 2]
    let l:ssh_command = empty(l:ssh_parts) ? 'ssh' : join(l:ssh_parts, ' ')
  endif

  if l:target =~# '\s'
    call s:notify_error(
          \ 'Root Configuration "current.connection" must end with SSH target'
          \ . ' like user@host. Run :RemoteConfig and :RemoteSwitch to select a remote.')
    return v:null
  endif

  return {
        \ 'ssh_command': l:ssh_command,
        \ 'target': l:target
        \ }
endfunction

function! s:start_async_terminal_command(command_args, terminal_name) abort
  if s:is_active_remote_pull_running()
    call s:notify_error('RemotePull is already running. Run :RemoteCancel to stop active pull.')
    return 0
  endif

  let l:terminal_name = trim(s:to_string_or_empty(a:terminal_name))
  if empty(l:terminal_name)
    let l:terminal_name = 'vim-remote-naive:RemotePull'
  endif

  if exists('g:vim_remote_naive_test_remote_pull_terminal_capture')
    let g:vim_remote_naive_test_remote_pull_terminal_capture = {
          \ 'command_args': deepcopy(a:command_args),
          \ 'terminal_name': l:terminal_name
          \ }
    let l:start_result = get(g:, 'vim_remote_naive_test_remote_pull_terminal_start_result', 1)
    return type(l:start_result) == v:t_number ? l:start_result : str2nr(l:start_result)
  endif

  if !has('terminal') || !exists('*term_start')
    call s:notify_error('Terminal support is unavailable in this Vim build.')
    return 0
  endif

  botright 12new
  let l:started_at = reltime()
  let l:job_id = term_start(a:command_args, {
        \ 'curwin': 1,
        \ 'term_name': l:terminal_name,
        \ 'term_finish': 'open',
        \ 'exit_cb': function('s:on_remote_pull_exit', [l:terminal_name, l:started_at])
        \ })
  if l:job_id <= 0
    close
    call s:notify_error('Failed to start terminal job.')
    return 0
  endif

  call s:set_remote_pull_active_state(l:job_id, bufnr('%'), l:terminal_name, l:started_at)
  return 1
endfunction

function! vim_remote_naive#remote_config() abort
  let l:root_config_file_path = vim_remote_naive#root_config_file_path()
  if !s:ensure_root_configuration_exists(l:root_config_file_path)
    return
  endif

  execute 'edit ' . fnameescape(l:root_config_file_path)
endfunction

function! vim_remote_naive#remote_pull() abort
  if s:is_active_remote_pull_running()
    call s:notify_error('RemotePull is already running. Run :RemoteCancel to stop active pull.')
    return
  endif

  let l:root_config_file_path = vim_remote_naive#root_config_file_path()
  let l:root_configuration = s:read_root_configuration(l:root_config_file_path)
  if l:root_configuration is v:null
    return
  endif

  if !has_key(l:root_configuration, s:root_config_current_key)
    call s:notify_error('No active remote selected. Run :RemoteSwitch to select a remote.')
    return
  endif

  let l:selected_remote = l:root_configuration[s:root_config_current_key]
  if !s:is_valid_current_remote(l:selected_remote)
    return
  endif

  if s:find_current_remote_index(l:root_configuration[s:root_config_remotes_key], l:selected_remote) < 0
    call s:notify_error(
          \ 'Current remote is not present in "remotes".'
          \ . ' Run :RemoteSwitch to select a remote.')
    return
  endif

  if empty(trim(l:selected_remote['source'])) || empty(trim(l:selected_remote['destination']))
    call s:notify_error(
          \ 'Root Configuration "current.source" and "current.destination" must not be empty.')
    return
  endif

  if executable('rsync') != 1
    call s:notify_error('rsync executable not found in PATH.')
    return
  endif

  let l:transport = s:remote_pull_transport(l:selected_remote['connection'])
  if l:transport is v:null
    return
  endif

  let l:remote_source = l:transport['target'] . ':' . s:with_trailing_separator(l:selected_remote['source'])
  let l:local_destination = s:with_trailing_separator(
        \ s:expand_tilde_home_path(l:selected_remote['destination']))
  let l:rsync_command = [
        \ 'rsync',
        \ '-a',
        \ '-e',
        \ l:transport['ssh_command'],
        \ l:remote_source,
        \ l:local_destination
        \ ]
  if !s:start_async_terminal_command(l:rsync_command, 'vim-remote-naive:RemotePull')
    return
  endif

  call s:notify(
        \ 'RemotePull started: '
        \ . l:transport['target'] . ':' . l:selected_remote['source']
        \ . ' -> '
        \ . l:selected_remote['destination'])
endfunction

function! vim_remote_naive#remote_cancel() abort
  if !s:is_active_remote_pull_running()
    call s:notify('No active RemotePull job to cancel.')
    return
  endif

  let l:buffer_number = s:remote_pull_active_buffer_number
  let s:remote_pull_cancel_requested = 1
  call s:stop_terminal_buffer_job(l:buffer_number)

  if s:is_terminal_buffer_job_running(l:buffer_number)
    call s:notify_error('Failed to cancel active RemotePull job.')
    return
  endif

  if s:remote_pull_active
    let l:elapsed_seconds = s:elapsed_seconds_since(s:remote_pull_started_at)
    let l:terminal_name = s:remote_pull_terminal_name
    call s:clear_remote_pull_active_state()
    call s:write_remote_pull_completion(l:terminal_name, l:elapsed_seconds, -1)
  endif
endfunction

function! vim_remote_naive#remote_switch() abort
  let l:root_config_file_path = vim_remote_naive#root_config_file_path()
  let l:root_configuration = s:read_root_configuration(l:root_config_file_path)
  if l:root_configuration is v:null
    return
  endif

  let l:remotes = l:root_configuration[s:root_config_remotes_key]
  if empty(l:remotes)
    call s:notify_error('Root Configuration "' . s:root_config_remotes_key . '" array is empty.')
    return
  endif

  let l:current_remote_index = s:find_current_remote_index(
        \ l:remotes,
        \ get(l:root_configuration, s:root_config_current_key, v:null))
  let l:selection_lines = s:remote_selection_lines(l:remotes, l:current_remote_index)

  if exists('g:vim_remote_naive_test_remote_switch_selection_index')
    call s:apply_remote_selection(
          \ l:root_config_file_path,
          \ l:root_configuration,
          \ g:vim_remote_naive_test_remote_switch_selection_index)
    return
  endif

  if s:show_remote_selection_popup(l:root_config_file_path, l:root_configuration, l:selection_lines)
    return
  endif

  let l:selection_result = s:select_remote_with_inputlist(l:selection_lines)
  call s:apply_remote_selection(l:root_config_file_path, l:root_configuration, l:selection_result)
endfunction
