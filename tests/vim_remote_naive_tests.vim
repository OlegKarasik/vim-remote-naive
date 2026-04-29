let s:repo_root = fnamemodify(expand('<sfile>:p'), ':h:h')

function! s:assert_file_lines(path, expected_lines, message) abort
  call assert_true(filereadable(a:path), 'Expected file to exist: ' . a:path)
  call assert_equal(a:expected_lines, readfile(a:path), a:message)
endfunction

function! s:assert_current_buffer_path(expected_path, message) abort
  call assert_equal(fnamemodify(a:expected_path, ':p'), fnamemodify(expand('%:p'), ':p'), a:message)
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

function! s:autoload_script_local_function(script_local_name) abort
  call vim_remote_naive#root_config_file_path_for('linux', '/home/me', '', '')
  let l:function_name = matchstr(execute('function'), '<SNR>\d\+_' . a:script_local_name)
  call assert_notequal('', l:function_name, 'Expected script-local function: ' . a:script_local_name)
  return function(l:function_name)
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
  call s:assert_current_buffer_path(
        \ l:config_path,
        \ 'Expected RemoteConfig to open the created Root Configuration file.')

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
  call s:assert_current_buffer_path(
        \ l:config_path,
        \ 'Expected RemoteConfig to open the existing Root Configuration file.')

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
endfunction

function! s:test_remote_add_command_is_not_defined() abort
  call assert_equal(0, exists(':RemoteAdd'), 'Expected RemoteAdd command to be undefined.')
endfunction

function! s:test_remote_pull_command_is_defined() abort
  call assert_equal(2, exists(':RemotePull'), 'Expected RemotePull command to be defined.')
endfunction

function! s:test_remote_pull_fails_when_current_missing() abort
  let l:test_root = s:repo_root . '/tests/tmp/remote-pull-missing-current'
  let l:config_path = l:test_root . '/config.json'
  let l:remote_one = {
        \ 'source': '/srv/project-a',
        \ 'destination': '/Users/me/project-a',
        \ 'connection': 'user@host-a'
        \ }
  let l:initial_config = {
        \ 'version': 1,
        \ 'remotes': [l:remote_one]
        \ }

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
  call mkdir(l:test_root, 'p')
  call s:write_json_file(l:config_path, l:initial_config)

  let g:vim_remote_naive_root_config_file_path_override = l:config_path
  try
    RemotePull
  finally
    unlet g:vim_remote_naive_root_config_file_path_override
  endtry

  let l:messages = s:captured_messages()
  call assert_true(
        \ stridx(l:messages, 'No active remote selected. Run :RemoteSwitch to select a remote.') >= 0,
        \ 'Expected missing current remote error message.')

  let l:updated_config = s:read_json_file(l:config_path)
  call assert_equal(l:initial_config, l:updated_config, 'Expected missing current to keep configuration unchanged.')

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
endfunction

function! s:test_remote_pull_starts_async_rsync_for_current_remote() abort
  let l:test_root = s:repo_root . '/tests/tmp/remote-pull-starts-rsync'
  let l:config_path = l:test_root . '/config.json'
  let l:remote_one = {
        \ 'source': '/srv/project-a',
        \ 'destination': '/Users/me/project-a',
        \ 'connection': 'ssh -p 2222 user@host-a'
        \ }
  let l:remote_two = {
        \ 'source': '/srv/project-b',
        \ 'destination': '/Users/me/project-b',
        \ 'connection': 'user@host-b'
        \ }
  let l:initial_config = {
        \ 'version': 1,
        \ 'remotes': [l:remote_one, l:remote_two],
        \ 'current': l:remote_one
        \ }

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
  call mkdir(l:test_root, 'p')
  call s:write_json_file(l:config_path, l:initial_config)

  let l:terminal_capture = {}
  let g:vim_remote_naive_root_config_file_path_override = l:config_path
  let g:vim_remote_naive_test_remote_pull_terminal_capture = {}
  try
    silent RemotePull
    let l:terminal_capture = deepcopy(g:vim_remote_naive_test_remote_pull_terminal_capture)
  finally
    unlet g:vim_remote_naive_root_config_file_path_override
    unlet g:vim_remote_naive_test_remote_pull_terminal_capture
  endtry

  call assert_equal(
        \ [
        \   'rsync',
        \   '-az',
        \   '-e',
        \   'ssh -p 2222',
        \   'user@host-a:/srv/project-a/',
        \   '/Users/me/project-a/'
        \ ],
        \ l:terminal_capture['command_args'],
        \ 'Expected RemotePull to build rsync command from current remote.')
  call assert_equal(
        \ 'vim-remote-naive:RemotePull',
        \ l:terminal_capture['terminal_name'],
        \ 'Expected RemotePull to use terminal title for rsync execution.')

  let l:updated_config = s:read_json_file(l:config_path)
  call assert_equal(l:initial_config, l:updated_config, 'Expected RemotePull to not modify Root Configuration.')

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
endfunction

function! s:test_remote_switch_fails_when_root_configuration_missing() abort
  let l:test_root = s:repo_root . '/tests/tmp/remote-switch-missing-config'
  let l:config_path = fnamemodify(l:test_root . '/config.json', ':p')

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
  call mkdir(l:test_root, 'p')

  let g:vim_remote_naive_root_config_file_path_override = l:config_path
  try
    RemoteSwitch
  finally
    unlet g:vim_remote_naive_root_config_file_path_override
  endtry

  let l:messages = s:captured_messages()
  call assert_true(
        \ stridx(l:messages, 'Root Configuration file not found: ' . l:config_path) >= 0,
        \ 'Expected missing Root Configuration error message.')

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
endfunction

function! s:test_remote_switch_fails_when_remotes_missing() abort
  let l:test_root = s:repo_root . '/tests/tmp/remote-switch-missing-remotes'
  let l:config_path = l:test_root . '/config.json'

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
  call mkdir(l:test_root, 'p')
  call s:write_json_file(l:config_path, {'version': 1})

  let g:vim_remote_naive_root_config_file_path_override = l:config_path
  try
    RemoteSwitch
  finally
    unlet g:vim_remote_naive_root_config_file_path_override
  endtry

  let l:messages = s:captured_messages()
  call assert_true(
        \ stridx(l:messages, 'Root Configuration is missing "remotes" array.') >= 0,
        \ 'Expected missing remotes error message.')

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
endfunction

function! s:test_remote_switch_fails_when_remotes_empty() abort
  let l:test_root = s:repo_root . '/tests/tmp/remote-switch-empty-remotes'
  let l:config_path = l:test_root . '/config.json'

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
  call mkdir(l:test_root, 'p')
  call s:write_json_file(l:config_path, {'version': 1, 'remotes': []})

  let g:vim_remote_naive_root_config_file_path_override = l:config_path
  try
    RemoteSwitch
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

function! s:test_remote_switch_popup_indexes_include_all_remotes() abort
  let l:RemoteIndexes = s:autoload_script_local_function('remote_indexes')

  call assert_equal([], call(l:RemoteIndexes, [[]]), 'Expected no popup indexes for empty remotes list.')
  call assert_equal([0], call(l:RemoteIndexes, [['first']]), 'Expected popup indexes to include single remote.')
  call assert_equal(
        \ [0, 1],
        \ call(l:RemoteIndexes, [['first', 'second']]),
        \ 'Expected popup indexes to include all remotes.')
endfunction

function! s:test_remote_switch_popup_done_ignores_unknown_popup_id() abort
  let l:PopupDone = s:autoload_script_local_function('on_remote_list_popup_done')
  let l:exception = ''

  try
    call call(l:PopupDone, [9999, 1])
  catch
    let l:exception = v:exception
  endtry

  call assert_equal(
        \ '',
        \ l:exception,
        \ 'Expected popup done callback to ignore unknown popup id without errors.')
endfunction

function! s:test_remote_switch_selects_active_remote_and_writes_current() abort
  let l:test_root = s:repo_root . '/tests/tmp/remote-switch-selects-current'
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
  let g:vim_remote_naive_test_remote_switch_selection_index = 2
  try
    silent RemoteSwitch
  finally
    unlet g:vim_remote_naive_root_config_file_path_override
    unlet g:vim_remote_naive_test_remote_switch_selection_index
  endtry

  let l:updated_config = s:read_json_file(l:config_path)
  call assert_equal(l:remote_two, l:updated_config['current'], 'Expected RemoteSwitch to update current to selected remote.')
  call assert_equal([l:remote_one, l:remote_two], l:updated_config['remotes'], 'Expected remotes array to remain unchanged.')

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
endfunction

function! s:test_remote_switch_cancel_keeps_existing_current() abort
  let l:test_root = s:repo_root . '/tests/tmp/remote-switch-cancel'
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
  let g:vim_remote_naive_test_remote_switch_selection_index = 0
  try
    silent RemoteSwitch
  finally
    unlet g:vim_remote_naive_root_config_file_path_override
    unlet g:vim_remote_naive_test_remote_switch_selection_index
  endtry

  let l:updated_config = s:read_json_file(l:config_path)
  call assert_equal(l:initial_config, l:updated_config, 'Expected cancel to keep current unchanged.')

  call s:cleanup_directory(fnamemodify(l:test_root, ':h'))
endfunction

function! s:test_remote_switch_rejects_invalid_remote_item() abort
  let l:test_root = s:repo_root . '/tests/tmp/remote-switch-invalid-entry'
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
  let g:vim_remote_naive_test_remote_switch_selection_index = 1
  try
    RemoteSwitch
  finally
    unlet g:vim_remote_naive_root_config_file_path_override
    unlet g:vim_remote_naive_test_remote_switch_selection_index
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
  call s:test_remote_add_command_is_not_defined()
  call s:test_remote_pull_command_is_defined()
  call s:test_remote_pull_fails_when_current_missing()
  call s:test_remote_pull_starts_async_rsync_for_current_remote()
  call s:test_remote_switch_fails_when_root_configuration_missing()
  call s:test_remote_switch_fails_when_remotes_missing()
  call s:test_remote_switch_fails_when_remotes_empty()
  call s:test_remote_switch_popup_indexes_include_all_remotes()
  call s:test_remote_switch_popup_done_ignores_unknown_popup_id()
  call s:test_remote_switch_selects_active_remote_and_writes_current()
  call s:test_remote_switch_cancel_keeps_existing_current()
  call s:test_remote_switch_rejects_invalid_remote_item()
endfunction
