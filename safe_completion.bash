#!/bin/bash

# bash completion for safe

#Envvars:
#  _SAFECOMP_PREFIX: Prepends this prefix to each in completion list
#  _SAFECOMP_NOSPACE: Doesn't append space to completion. Overrides _SAFECOMP_NOSPACE_SLASH
#  _SAFECOMP_NOSPACE_SLASH: Doesn't append space to completion ending with slash
__safecomp() {
  __safe_debug "Entering __safecomp"

  local s IFS=$' '$'\t'$'\n'
  local cur=${2:-${COMP_WORDS[COMP_CWORD]}}

  if [[ -n $_SAFECOMP_NOSPACE ]]; then
    __safe_debug "_SAFECOMP_NOSPACE is set"
  fi

  if [[ -n $_SAFECOMP_NOSPACE_SLASH ]]; then
    __safe_debug "_SAFECOMP_NOSPACE_SLASH is set"
  fi

  if [[ -n $_SAFECOMP_PREFIX ]]; then
    __safe_debug "_SAFECOMP_PREFIX is \"${_SAFECOMP_PREFIX}\""
  fi

  #Old bash installations (like the system bash on mac) have
  # terrible completion utilities. Let's hack our own `compgen'
  COMPREPLY=()
  COMP_WORDBREAKS="${COMP_WORDBREAKS//:}"
  for s in $1; do
    local prefixed="${_SAFECOMP_PREFIX}$s"
    if grep -E "^$cur.*" <<<"$prefixed" >/dev/null; then
      local space=" "
      if [[ -n $_SAFECOMP_NOSPACE ]]; then
        space=""
      elif [[ -n $_SAFECOMP_NOSPACE_SLASH && \
            ${prefixed:${#prefixed}-1:1} == "/" ]]; then
        space=""
      fi

      COMPREPLY+=("$prefixed$space")
    else
      __safe_debug "Discarding: '$prefixed'"
    fi
  done

  if [[ -n $_SAFECOMP_DEBUG ]]; then
    __safe_debug "Completion options:"
    __safe_debug "---START---"
    for option in "${COMPREPLY[@]}"; do
      __safe_debug "'$option'"
    done
    __safe_debug "---END---"
  fi
}

#Envvars
# _SAFECOMP_SUBKEY: If nonempty, this will complete a key if a colon is found
__safe_complete_path() {
  __safe_debug "Completing path"
  local full_path="${COMP_WORDS[$COMP_CWORD]}"
  if [[ -z $full_path ]]; then
    _SAFECOMP_NOSPACE=1 __safecomp "$($_SAFECOMP_TIMEOUT_CMD safe ls 2>/dev/null)"
    return 0
  fi

  local dir
  dir="$(dirname "$full_path")"
  if [[ ${full_path:$((${#full_path} - 1)):1} == "/" ]]; then
    dir=${full_path:0:$((${#full_path} - 1))}
    #base=""
  fi

  if [[ $dir == "." && $full_path ]]; then
    _SAFECOMP_NOSPACE=1 __safecomp "$($_SAFECOMP_TIMEOUT_CMD safe ls 2>/dev/null)"
    return 0
  fi

  local should_nospace=0

  if [[ -n $_SAFECOMP_SUBKEY ]]; then
    if grep -E ':' <<<"$full_path" >/dev/null; then
      local secret="${full_path/:*}"
      __safe_debug "...calling safe_complete_key from found-colon path"
      __safe_complete_key "$secret"
      return 0
    fi

    should_nospace=1
  fi

  #We'll want this if we split completion on slashes
  #local base
  #base="$(basename $full_path)"

  if [[ ${full_path:$((${#full_path} - 1)):1} == "/" ]]; then
    dir=${full_path:0:$((${#full_path} - 1))}
    #base=""
  fi
  dir="${dir}/"

  if [[ $should_nospace == 1 ]]; then
    _SAFECOMP_NOSPACE=1 \
    _SAFECOMP_PREFIX="$dir" \
      __safecomp "$($_SAFECOMP_TIMEOUT_CMD safe ls "$dir" 2>/dev/null)"
  else
    _SAFECOMP_NOSPACE_SLASH=1 \
    _SAFECOMP_PREFIX="$dir" \
      __safecomp "$($_SAFECOMP_TIMEOUT_CMD safe ls "$dir" 2>/dev/null)"
  fi

  if [[ -n $_SAFECOMP_SUBKEY && ${#COMPREPLY[@]} -eq 1 && ${COMPREPLY[0]} == "$full_path" ]]; then
    __safe_complete_key "$full_path"
  fi
}

__safe_complete_key() {
  __safe_debug "Completing key"
  __safe_debug "Checking for keys under secret: $1"
  __safecomp "$($_SAFECOMP_TIMEOUT_CMD safe paths --keys "$1" 2>/dev/null)"
}

# _SAFECOMP_NOHELP: if nonempty, help is omitted from the selection
_safe_commands() {
  __safe_debug "Completing command"

  local help="help"
  if [[ -n $_SAFECOMP_NOHELP ]]; then
    help=""
  fi
  __safecomp "
${help} version targets status unseal seal env auth login renew ask set write
paste exists check init rekey get read cat ls paths tree target delete rm
export import move rename mv copy cp gen auto ssh rsa dhparam dhparams dh
prompt vault fmt curl x509"
}

_safe_auth() {
  __safe_debug "Completing auth"
  local found
  while [[ "$_safe_current_token" -lt "$COMP_CWORD" ]]; do
    local s="${COMP_WORDS[_safe_current_token]}"
    case "$s" in
      token|github|ldap|userpass)
        found=1
        break
        ;;
    esac
    _safe_current_token="$((++_safe_current_token))"
  done

  if [[ -z $found ]]; then
    __safecomp "token github ldap userpass"
  fi
}

_safe_x509() {
  __safe_debug "Completing x509"
  local cmd
  while [[ "$_safe_current_token" -lt "$COMP_CWORD" ]]; do
    local s="${COMP_WORDS[_safe_current_token]}"
    _safe_current_token="$((++_safe_current_token))"
    case "$s" in
      issue|revoke|validate|show|crl)
        cmd=$s
        break
        ;;
    esac
  done

  if [[ -z $cmd ]]; then
    __safecomp "issue revoke validate show crl"
    return 0
  fi

  __safe_complete_path
}

_safe_target() {
  target_output=$($_SAFECOMP_TIMEOUT_CMD safe targets 2>&1 | tail -n +3)
  __safe_debug "target_output: $target_output"

  local targets=()
  IFS=$'\n'
  for line in $target_output; do
    __safe_debug "line: $line"
    local target
    target=$(awk '{print $1}' <<<"$line" )
    if [[ $target == "(*)" ]]; then
      target=$(awk '{print $2}' <<<"$line" )
    fi

    __safe_debug "target: $target"

    targets+=("$target")
  done

  __safecomp "${targets[*]}"
}

__safe_debug() {
  if [[ -n $_SAFECOMP_DEBUG ]]; then
    echo "$1" >>/tmp/safecomp_debug
  fi
}

_safe() {
  __safe_debug "Beginning completion"
  SAFECOMP_TIMEOUT=${SAFECOMP_TIMEOUT:-0}
  set _SAFECOMP_TIMEOUT_CMD
  if [[ SAFECOMP_TIMEOUT -gt 0 ]]; then
    _SAFECOMP_TIMEOUT_CMD="timeout --foreground $SAFECOMP_TIMEOUT"
  fi

  _safe_current_token=1
  local cmd
  while [[ "$_safe_current_token" -lt "$COMP_CWORD" ]]; do
    local s="${COMP_WORDS[_safe_current_token]}"
    _safe_current_token="$((++_safe_current_token))"
    case "$s" in
      -*) #Ignore flags
        ;;
      *)
        cmd="$s"
        break
        ;;
    esac
  done

  if [[ -z $cmd ]]; then
    _safe_commands
    return 0
  fi

  case "$cmd" in
    ask|set|write|paste|list|ls|tree|paths|export|rsa|ssh) __safe_complete_path ;;
    get|read|cat|rm|move|rename|mv|cp|copy|gen|auto) _SAFECOMP_SUBKEY=1 __safe_complete_path ;;
    x509)                _safe_x509 ;;
    auth|login)          _safe_auth ;;
    target)              _safe_target ;;
    help)                _SAFECOMP_NOHELP=1 _safe_commands ;;
    *) ;;
  esac
}

complete -o nospace -F _safe safe
