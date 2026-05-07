if exists('g:loaded_vim_remote_naive')
  finish
endif
let g:loaded_vim_remote_naive = 1

command! -nargs=0 RemoteConfig call vim_remote_naive#remote_config()
command! -nargs=0 RemoteSwitch call vim_remote_naive#remote_switch()
command! -nargs=0 RemotePull call vim_remote_naive#remote_pull()
command! -nargs=0 RemoteCancel call vim_remote_naive#remote_cancel()
