#!/bin/bash


# bash completion for safe

#Envvars:
#  _SAFECOMP_NOSPACE: Doesn't append space to completion. Overrides _SAFECOMP_NOSPACE_SLASH
#  _SAFECOMP_NOSPACE_SLASH: Doesn't append space to completion ending with slash
__safecomp() {
  __safe_debug "Entering __safecomp"

  local cur=${2:-${COMP_WORDS[COMP_CWORD]}}
  COMP_WORDBREAKS="${COMP_WORDBREAKS//:}"
  COMP_WORDBREAKS="${COMP_WORDBREAKS//\/}/"
  __safe_debug "word break on: ${COMP_WORDBREAKS}"
  if [[ -z $cur || "${cur: -1}" == "/" ]]; then
    cur=""
  else
    IFS="${COMP_WORDBREAKS}" read -ra parts <<<$cur
    __safe_debug "parts is ${parts[*]}"
    cur=${parts[${#parts[@]}-1]}
  fi

  __safe_debug "cur is: '$cur'"

  local s IFS=$' '$'\t'$'\n'

  if [[ -n $_SAFECOMP_NOSPACE ]]; then
    __safe_debug "_SAFECOMP_NOSPACE is set"
  fi

  if [[ -n $_SAFECOMP_NOSPACE_SLASH ]]; then
    __safe_debug "_SAFECOMP_NOSPACE_SLASH is set"
  fi

  #Old bash installations (like the system bash on mac) have
  # terrible completion utilities. Let's hack our own `compgen'
  COMPREPLY=()
  for s in $1; do
    if grep -E "^$cur.*" <<<"$s" >/dev/null; then
      local space=" "
      if [[ -n $_SAFECOMP_NOSPACE ]]; then
        space=""
      elif [[ -n $_SAFECOMP_NOSPACE_SLASH && \
            ${s:${#s}-1:1} == "/" ]]; then
        space=""
      fi

      COMPREPLY+=("$s$space")
    else
      __safe_debug "Discarding: '$s'"
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
  __safe_debug "Full path is '$full_path'"
  if [[ -z $full_path ]]; then
    _SAFECOMP_NOSPACE=1 __safecomp "secret/"
    return 0
  fi

  local dir
  dir="$(dirname "$full_path")"
  if [[ $dir == "." && $full_path != "secret/" ]]; then
    _SAFECOMP_NOSPACE=1 __safecomp "secret/"
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

  __safe_debug "time to safe ls"
  if [[ $should_nospace == 1 ]]; then
    _SAFECOMP_NOSPACE=1 \
      __safecomp "$(timeout --foreground $SAFECOMP_TIMEOUT safe ls "$dir" 2>/dev/null)"
  else
    _SAFECOMP_NOSPACE_SLASH=1 \
      __safecomp "$(timeout --foreground $SAFECOMP_TIMEOUT safe ls "$dir" 2>/dev/null)"
  fi

  if [[ -n $_SAFECOMP_SUBKEY && ${#COMPREPLY[@]} -eq 1 && "${dir}${COMPREPLY[0]}" == "$full_path" ]]; then
    __safe_complete_key "$full_path"
  fi
}

__safe_complete_key() {
  __safe_debug "Completing key"
  __safe_debug "Checking for keys under secret: $1"
  __safecomp "$(timeout --foreground $SAFECOMP_TIMEOUT safe paths --keys "$1" 2>/dev/null | xargs -n 1 basename)"
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
  target_output=$(safe targets 2>&1 | tail -n +3)
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
  SAFECOMP_TIMEOUT=${SAFECOMP_TIMEOUT:-2}

  # bash v4 does splitting on COMP_WORDBREAKS, which I don't want
  if [[ ${BASH_VERSINFO[0]} == 4 ]]; then
    __safe_debug "Using bash version 4"
    IFS=' ' COMP_WORDS=( $COMP_LINE )
    COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
    if [[ "${COMP_LINE: -1}" == " " ]]; then
      COMP_CWORD=$((COMP_CWORD + 1))
    fi
  fi

  __safe_debug "COMP_WORDS is:"
  if [[ -n $_SAFECOMP_DEBUG ]]; then
    __safe_debug "---BEGIN---"
    for word in ${COMP_WORDS[@]}; do
      __safe_debug $word
    done
    __safe_debug "---END---"
  fi
  __safe_debug "COMP_CWORD is: ${COMP_CWORD}"
  __safe_debug "Current word is ${COMP_WORDS[$COMP_CWORD]}"

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
