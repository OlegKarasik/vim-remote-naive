if exists('g:loaded_vim_remote_naive')
  finish
endif
let g:loaded_vim_remote_naive = 1

command! -nargs=0 RemoteConfig call vim_remote_naive#remote_config()
command! -nargs=* RemoteAdd call vim_remote_naive#remote_add(<f-args>)
command! -nargs=0 RemoteSwitch call vim_remote_naive#remote_switch()
