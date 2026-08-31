# Omaclippy Zsh Command Hook
# Source this file in your ~/.zshrc:
#   source ~/.config/omarchy/plugins/dorneles.omaclippy/hooks/zsh-command-hook.zsh
#
# Reacts when long-running terminal commands (> 8s) start, complete, or fail!

_omaclippy_cmd_start_time=0
_omaclippy_last_cmd=""

_omaclippy_preexec() {
  _omaclippy_cmd_start_time=$EPOCHSECONDS
  _omaclippy_last_cmd="$1"
}

_omaclippy_precmd() {
  local exit_code=$?
  if (( _omaclippy_cmd_start_time > 0 )); then
    local duration=$(( EPOCHSECONDS - _omaclippy_cmd_start_time ))
    _omaclippy_cmd_start_time=0

    # Only react to commands that took longer than 8 seconds (e.g. builds, tests, downloads)
    if (( duration >= 8 )); then
      local base_cmd="${_omaclippy_last_cmd%% *}"
      base_cmd="${base_cmd//[^a-zA-Z0-9_.-]/}"
      if [[ -z "$base_cmd" ]]; then
        base_cmd="Command"
      fi
      if (( exit_code == 0 )); then
        if command -v omaclippy >/dev/null 2>&1; then
          omaclippy done "${base_cmd} completed successfully in ${duration}s!" >/dev/null 2>&1 &
        fi
      else
        if command -v omaclippy >/dev/null 2>&1; then
          omaclippy alert "Error running ${base_cmd} (exit code ${exit_code}) after ${duration}s!" >/dev/null 2>&1 &
        fi
      fi
    fi
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _omaclippy_preexec
add-zsh-hook precmd _omaclippy_precmd
