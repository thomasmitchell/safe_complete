# bash completion for safe

#Envvars:
#  _SAFECOMP_PREFIX: Prepends this prefix to each in completion list
#  _SAFECOMP_NOSPACE_SLASH: Doesn't append space to completion if
#     completion ends with a slash
__safecomp() {
	local s IFS=$' '$'\t'$'\n'
	local cur=${2:-${COMP_WORDS[COMP_CWORD]}}
	local prefix
	local space=" "

	#Old bash installations (like the system bash on mac) have
	# terrible completion utilities. Let's hack our own `compgen'
	COMPREPLY=()
	for s in $1; do
		local prefixed="${_SAFECOMP_PREFIX}$s"
		if egrep "^$cur.*" <<<"$prefixed" >/dev/null; then
			space=" "
			if [[ -n $_SAFECOMP_NOSPACE_SLASH && \
			      ${prefixed:${#prefixed}-1:1} == "/" ]]; then
				space=""
			fi

			COMPREPLY+=("$prefixed$space")
		fi
	done
}

__safe_complete_path() {
	local full_path="${COMP_WORDS[$COMP_CWORD]}"
	if [[ -z $full_path ]]; then
	  _SAFECOMP_NOSPACE_SLASH=1 __safecomp "secret/"
	  return 0
	fi

	local dir="$(dirname $full_path)"
	if [[ $dir == "." && $full_path != "secret/" ]]; then
		_SAFECOMP_NOSPACE_SLASH=1 __safecomp "secret/"
		return 0
	fi

	local base="$(basename $full_path)"

	if [[ ${full_path:$((${#full_path} - 1)):1} == "/" ]]; then
		dir=${full_path:0:$((${#full_path} - 1))}
		base=""
	fi
	dir="${dir}/"

  _SAFECOMP_PREFIX="$dir" \
	_SAFECOMP_NOSPACE_SLASH=1 \
	__safecomp "$(safe ls "$dir" 2>/dev/null)"
}

__safe_commands() {
	echo "
help
version
targets
status
unseal
seal
env
auth
login
renew
ask
set
write
paste
exists
check
init
rekey
get
read
cat
ls
paths
tree
target
delete
rm
export
import
move
rename
mv
copy
cp
gen
auto
ssh
rsa
dhparam
dhparams
dh
prompt
vault
fmt
curl
x509
"
}


_safe() {
	local i=1
	local cmd
  while [[ "$i" -lt "$COMP_CWORD" ]]; do
		local s="${COMP_WORDS[i]}"
		case "$s" in
			-*) #Ignore flags
				;;
			*)
				cmd="$s"
				break
				;;
		esac
		i="$((++i))"
	done

	if [[ -z $cmd ]]; then
		cmds=$(__safe_commands)
		__safecomp "$(__safe_commands)"
	else
		__safe_complete_path
	fi
}

complete -o nospace -F _safe safe
