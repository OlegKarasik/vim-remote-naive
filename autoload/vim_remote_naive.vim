let s:root_config_directory_name = 'vim-remote-naive'
let s:root_config_filename = 'config.json'
let s:root_config_remotes_key = 'remotes'
let s:root_config_current_key = 'current'
let s:remote_required_fields = ['source', 'destination', 'connection']
let s:message_prefix = '[vim-remote-naive] '
let s:remote_list_popup_states = {}

function! s:notify(message) abort
  echom s:message_prefix . a:message
endfunction

function! s:notify_error(message) abort
  echohl ErrorMsg
  echom s:message_prefix . a:message
  echohl None
endfunction

function! s:trim_trailing_separators(path) abort
  return substitute(a:path, '[\/\\]\+$', '', '')
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
  return range(len(a:remotes) - 1)
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
  let l:state = remove(s:remote_list_popup_states, a:popup_id, {})
  if empty(l:state)
    return
  endif

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
        \ 'border': [],
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

function! vim_remote_naive#remote_config() abort
  let l:root_config_file_path = vim_remote_naive#root_config_file_path()
  if !s:ensure_root_configuration_exists(l:root_config_file_path)
    return
  endif

  execute 'edit ' . fnameescape(l:root_config_file_path)
endfunction

function! vim_remote_naive#remote_add(...) abort
  if a:0 != 3
    call s:notify_error('RemoteAdd expects exactly 3 arguments: {connection} {local-path} {remote-path}.')
    return
  endif

  let l:connection = a:1
  let l:local_path = a:2
  let l:remote_path = a:3

  let l:root_config_file_path = vim_remote_naive#root_config_file_path()
  if !s:ensure_root_configuration_exists(l:root_config_file_path)
    return
  endif

  let l:root_configuration = s:read_root_configuration(l:root_config_file_path)
  if l:root_configuration is v:null
    return
  endif

  let l:added_remote = {
        \ 'source': l:remote_path,
        \ 'destination': l:local_path,
        \ 'connection': l:connection
        \ }
  let l:updated_root_configuration = deepcopy(l:root_configuration)
  call add(l:updated_root_configuration[s:root_config_remotes_key], l:added_remote)

  if !s:write_root_configuration(l:root_config_file_path, l:updated_root_configuration)
    return
  endif

  call s:notify('Added remote: ' . l:connection)
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
