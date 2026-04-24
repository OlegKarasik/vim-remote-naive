let s:repo_root = fnamemodify(expand('<sfile>:p'), ':h:h')

function! s:assert_file_lines(path, expected_lines, message) abort
  call assert_true(filereadable(a:path), 'Expected file to exist: ' . a:path)
  call assert_equal(a:expected_lines, readfile(a:path), a:message)
endfunction

function! s:cleanup_directory(path) abort
  if isdirectory(a:path)
    call delete(a:path, 'rf')
  endif
endfunction

function! s:write_json_file(path, payload) abort
  call writefile([json_encode(a:payload)], a:path)
endfunction

function! s:read_json_file(path) abort
  let l:json_text = join(readfile(a:path), "\n")
  return json_decode(l:json_text)
endfunction

function! s:captured_messages() abort
  redir => l:messages
  silent messages
  redir END
  return l:messages
endfunction

function! s:test_root_config_file_path_for_windows() abort
  let l:path = vim_remote_naive#root_config_file_path_for('windows', '/home/user', 'C:/Users/user/AppData/Roaming', '')
  call assert_equal('C:/Users/user/AppData/Roaming/vim-remote-naive/config.json', l:path)

  let l:fallback_path = vim_remote_naive#root_config_file_path_for('windows', 'C:/Users/user', '', '')
  call assert_equal('C:/Users/user/AppData/Roaming/vim-remote-naive/config.json', l:fallback_path)
endfunction

function! s:test_root_config_file_path_for_macos() abort
  let l:path = vim_remote_naive#root_config_file_path_for('macos', '/Users/me', '', '')
  call assert_equal('/Users/me/Library/Application Support/vim-remote-naive/config.json', l:path)
endfunction

function! s:test_root_config_file_path_for_linux() abort
  let l:path = vim_remote_naive#root_config_file_path_for('linux', '/home/me', '', '/home/me/.xdg')
  call assert_equal('/home/me/.xdg/vim-remote-naive/config.json', l:path)

  let l:fallback_path = vim_remote_naive#root_config_file_path_for('linux', '/home/me', '', '')
  call assert_equal('/home/me/.config/vim-remote-naive/config.json', l:fallback_path)
endfunction

function! s:test_remote_config_creates_default_root_configuration() abort
  let l:test_root = s:repo_root . '/tests/tmp/remote-config-create'
  let l:config_path = l:test_root . '/config.json'

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
  call mkdir(l:test_root, 'p')

  let g:vim_remote_naive_root_config_file_path_override = l:config_path
  try
    silent RemoteConfig
  finally
    unlet g:vim_remote_naive_root_config_file_path_override
  endtry

  call s:assert_file_lines(
        \ l:config_path,
        \ ['{', '  "version": 1,', '  "remotes": []', '}'],
        \ 'Expected default Root Configuration JSON content.')

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
endfunction

function! s:test_remote_config_does_not_overwrite_existing_root_configuration() abort
  let l:test_root = s:repo_root . '/tests/tmp/remote-config-existing'
  let l:config_path = l:test_root . '/config.json'
  let l:custom_lines = ['{"custom":true}']

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
  call mkdir(l:test_root, 'p')
  call writefile(l:custom_lines, l:config_path)

  let g:vim_remote_naive_root_config_file_path_override = l:config_path
  try
    silent RemoteConfig
  finally
    unlet g:vim_remote_naive_root_config_file_path_override
  endtry

  call s:assert_file_lines(
        \ l:config_path,
        \ l:custom_lines,
        \ 'Expected existing Root Configuration to remain unchanged.')

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
endfunction

function! s:test_remote_list_fails_when_root_configuration_missing() abort
  let l:test_root = s:repo_root . '/tests/tmp/remote-list-missing-config'
  let l:config_path = fnamemodify(l:test_root . '/config.json', ':p')

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
  call mkdir(l:test_root, 'p')

  let g:vim_remote_naive_root_config_file_path_override = l:config_path
  try
    RemoteList
  finally
    unlet g:vim_remote_naive_root_config_file_path_override
  endtry

  let l:messages = s:captured_messages()
  call assert_true(
        \ stridx(l:messages, 'Root Configuration file not found: ' . l:config_path) >= 0,
        \ 'Expected missing Root Configuration error message.')

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
endfunction

function! s:test_remote_list_fails_when_remotes_missing() abort
  let l:test_root = s:repo_root . '/tests/tmp/remote-list-missing-remotes'
  let l:config_path = l:test_root . '/config.json'

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
  call mkdir(l:test_root, 'p')
  call s:write_json_file(l:config_path, {'version': 1})

  let g:vim_remote_naive_root_config_file_path_override = l:config_path
  try
    RemoteList
  finally
    unlet g:vim_remote_naive_root_config_file_path_override
  endtry

  let l:messages = s:captured_messages()
  call assert_true(
        \ stridx(l:messages, 'Root Configuration is missing "remotes" array.') >= 0,
        \ 'Expected missing remotes error message.')

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
endfunction

function! s:test_remote_list_fails_when_remotes_empty() abort
  let l:test_root = s:repo_root . '/tests/tmp/remote-list-empty-remotes'
  let l:config_path = l:test_root . '/config.json'

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
  call mkdir(l:test_root, 'p')
  call s:write_json_file(l:config_path, {'version': 1, 'remotes': []})

  let g:vim_remote_naive_root_config_file_path_override = l:config_path
  try
    RemoteList
  finally
    unlet g:vim_remote_naive_root_config_file_path_override
  endtry

  let l:messages = s:captured_messages()
  call assert_true(
        \ stridx(l:messages, 'Root Configuration "remotes" array is empty.') >= 0,
        \ 'Expected empty remotes error message.')

  let l:updated_config = s:read_json_file(l:config_path)
  call assert_false(has_key(l:updated_config, 'current'), 'Expected current to remain unset when remotes are empty.')

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
endfunction

function! s:test_remote_list_selects_active_remote_and_writes_current() abort
  let l:test_root = s:repo_root . '/tests/tmp/remote-list-selects-current'
  let l:config_path = l:test_root . '/config.json'
  let l:remote_one = {
        \ 'source': '/srv/project-a',
        \ 'destination': '/Users/me/project-a',
        \ 'connection': 'ssh user@host-a'
        \ }
  let l:remote_two = {
        \ 'source': '/srv/project-b',
        \ 'destination': '/Users/me/project-b',
        \ 'connection': 'ssh user@host-b'
        \ }
  let l:initial_config = {
        \ 'version': 1,
        \ 'remotes': [l:remote_one, l:remote_two]
        \ }

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
  call mkdir(l:test_root, 'p')
  call s:write_json_file(l:config_path, l:initial_config)

  let g:vim_remote_naive_root_config_file_path_override = l:config_path
  let g:vim_remote_naive_test_remote_list_selection_index = 2
  try
    silent RemoteList
  finally
    unlet g:vim_remote_naive_root_config_file_path_override
    unlet g:vim_remote_naive_test_remote_list_selection_index
  endtry

  let l:updated_config = s:read_json_file(l:config_path)
  call assert_equal(l:remote_two, l:updated_config['current'], 'Expected selected remote to be written to current.')
  call assert_equal([l:remote_one, l:remote_two], l:updated_config['remotes'], 'Expected remotes array to remain unchanged.')

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
endfunction

function! s:test_remote_list_cancel_keeps_existing_current() abort
  let l:test_root = s:repo_root . '/tests/tmp/remote-list-cancel'
  let l:config_path = l:test_root . '/config.json'
  let l:remote_one = {
        \ 'source': '/srv/project-a',
        \ 'destination': '/Users/me/project-a',
        \ 'connection': 'ssh user@host-a'
        \ }
  let l:remote_two = {
        \ 'source': '/srv/project-b',
        \ 'destination': '/Users/me/project-b',
        \ 'connection': 'ssh user@host-b'
        \ }
  let l:initial_config = {
        \ 'version': 1,
        \ 'remotes': [l:remote_one, l:remote_two],
        \ 'current': l:remote_one
        \ }

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
  call mkdir(l:test_root, 'p')
  call s:write_json_file(l:config_path, l:initial_config)

  let g:vim_remote_naive_root_config_file_path_override = l:config_path
  let g:vim_remote_naive_test_remote_list_selection_index = 0
  try
    silent RemoteList
  finally
    unlet g:vim_remote_naive_root_config_file_path_override
    unlet g:vim_remote_naive_test_remote_list_selection_index
  endtry

  let l:updated_config = s:read_json_file(l:config_path)
  call assert_equal(l:initial_config, l:updated_config, 'Expected cancel to keep current unchanged.')

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
endfunction

function! s:test_remote_list_rejects_invalid_remote_item() abort
  let l:test_root = s:repo_root . '/tests/tmp/remote-list-invalid-entry'
  let l:config_path = l:test_root . '/config.json'
  let l:invalid_remote = {
        \ 'source': '/srv/project-a',
        \ 'destination': '/Users/me/project-a'
        \ }
  let l:initial_config = {
        \ 'version': 1,
        \ 'remotes': [l:invalid_remote]
        \ }

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
  call mkdir(l:test_root, 'p')
  call s:write_json_file(l:config_path, l:initial_config)

  let g:vim_remote_naive_root_config_file_path_override = l:config_path
  let g:vim_remote_naive_test_remote_list_selection_index = 1
  try
    RemoteList
  finally
    unlet g:vim_remote_naive_root_config_file_path_override
    unlet g:vim_remote_naive_test_remote_list_selection_index
  endtry

  let l:messages = s:captured_messages()
  call assert_true(
        \ stridx(l:messages, 'Invalid remote entry #1: missing string field "connection".') >= 0,
        \ 'Expected invalid remote field error message.')

  let l:updated_config = s:read_json_file(l:config_path)
  call assert_false(has_key(l:updated_config, 'current'), 'Expected invalid remote entry to prevent current updates.')

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
endfunction

function! VimRemoteNaiveTestRunAll() abort
  call s:test_root_config_file_path_for_windows()
  call s:test_root_config_file_path_for_macos()
  call s:test_root_config_file_path_for_linux()
  call s:test_remote_config_creates_default_root_configuration()
  call s:test_remote_config_does_not_overwrite_existing_root_configuration()
  call s:test_remote_list_fails_when_root_configuration_missing()
  call s:test_remote_list_fails_when_remotes_missing()
  call s:test_remote_list_fails_when_remotes_empty()
  call s:test_remote_list_selects_active_remote_and_writes_current()
  call s:test_remote_list_cancel_keeps_existing_current()
  call s:test_remote_list_rejects_invalid_remote_item()
endfunction
