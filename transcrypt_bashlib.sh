#!/usr/bin/env bash
__doc__='
This contains the standalone heredoc versions of transcrypt library functions.
These are not used in the main executable itself. Instead they are ported from
here to there and stripped of extranious information.

This makes it easier to unit test the individual bash components of the system
while still providing a fast and reasonably optimized runtime.
'

# print a message to stderr
warn() {
	local fmt="$1"
	shift
	# shellcheck disable=SC2059
	printf "transcrypt: $fmt\n" "$@" >&2
}

# print a message to stderr and exit with either
# the given status or that of the most recent command
die() {
	local st="$?"
	if [[ "$1" != *[^0-9]* ]]; then
		st="$1"
		shift
	fi
	warn "$@"
	exit "$st"
}

# print a canonicalized absolute pathname
realpath() {
	local path=$1

	# make path absolute
	local abspath=$path
	if [[ -n ${abspath##/*} ]]; then
		abspath=$(pwd -P)/$abspath
	fi

	# canonicalize path
	local dirname=
	if [[ -d $abspath ]]; then
		dirname=$(cd "$abspath" && pwd -P)
		abspath=$dirname
	elif [[ -e $abspath ]]; then
		dirname=$(cd "${abspath%/*}/" 2>/dev/null && pwd -P)
		abspath=$dirname/${abspath##*/}
	fi

	if [[ -d $dirname && -e $abspath ]]; then
		printf '%s\n' "$abspath"
	else
		printf 'invalid path: %s\n' "$path" >&2
		exit 1
	fi
}

joinby(){
    __doc__='
    A function that works similar to a Python join

    Args:
        SEP: the separator
        *ARR: elements of the strings to join

    Usage:
        source $HOME/local/init/utils.sh 
        ARR=("foo" "bar" "baz")
        RESULT=$(joinby / "${ARR[@]}")
        echo "RESULT = $RESULT"

        RESULT = foo/bar/baz

    References:
        https://stackoverflow.com/questions/1527049/how-can-i-join-elements-of-an-array-in-bash
    '
    _handle_help "$@" || return 0
    local d=${1-} f=${2-}
    if shift 2; then
        printf %s "$f" "${@/#/$d}"
    fi
}

# shellcheck disable=SC2154
_openssl_encrypt()
{
    __doc__='
    Example:
        source ~/code/transcrypt/transcrypt_bashlib.sh
        pbkdf2_args=("-pbkdf2")
        salt=deadbeafbad00000
        digest=sha256
        password=12345
        openssl_path=openssl
        cipher=aes-256-cbc
        tempfile=$(mktemp)
        echo "secret" > $tempfile
        _openssl_encrypt
    '
    # Exepcts that the following variables are set:
    # password, openssl_path, cipher, digest, salt, pbkdf2_args, tempfile

    # Test the openssl version
    openssl_major_version=$($openssl_path version  | cut -d' ' -f2 | cut -d'.' -f1)
    if [ "$openssl_major_version" -ge "3" ]; then
        # OpenSSL 3.x
        # In 3.x openssl disabled output of the salt prefix, which we need for determinism.
        # To reenable the prefix we emit the raw prefix bytes, encrypt in raw bytes, and then
        # send that entire stream to be base64 encoded
        (printf "Salted__" && printf "%s" "$salt" | xxd -r -p && \
            ENC_PASS=$password "$openssl_path" enc "-${cipher}" -md "${digest}" -pass env:ENC_PASS -e -S "$salt" "${pbkdf2_args[@]}" -in "$tempfile"
        ) | base64
    else
        # OpenSSL 1.x
        ENC_PASS=$password "$openssl_path" enc "-${cipher}" -md "${digest}" -pass env:ENC_PASS -e -a -S "$salt" "${pbkdf2_args[@]}" -in "$tempfile"
    fi
}

# shellcheck disable=SC2154
_openssl_decrypt()
{
    __doc__='
    Example:
        source ~/code/transcrypt/transcrypt_bashlib.sh
        pbkdf2_args=("-pbkdf2")
        digest=sha256
        password=12345
        openssl_path=openssl
        cipher=aes-256-cbc
        echo "U2FsdGVkX1/erb6vutAAADPXEjWJ3l4MEpSGTj5qC/w=" | _openssl_decrypt
        tempfile=$(mktemp)
        echo "U2FsdGVkX1/erb6vutAAADPXEjWJ3l4MEpSGTj5qC/w=" > $tempfile
        _openssl_decrypt -in $tempfile
    '
    # Exepcts that the following variables are set:
    # password, openssl_path, cipher, digest, pbkdf2_args
    # This works the same across openssl versions
	ENC_PASS=$password "$openssl_path" enc "-${cipher}" -md "${digest}" -pass env:ENC_PASS "${pbkdf2_args[@]}" -d -a "$@"
}

_openssl_list(){
    # Args: the openssl commands to list
    __doc__='
        source ~/code/transcrypt/bash_helpers.sh
        arg=digest-commands
        _openssl_list digest-commands
        _openssl_list cipher-commands
    '
    openssl_path=openssl
    arg=$1
	if "${openssl_path}  list-$arg" &>/dev/null; then
		# OpenSSL < v1.1.0
		"${openssl_path}" "list-$arg"
	else
		# OpenSSL >= v1.1.0
		"${openssl_path}" "list" "-$arg"
	fi
}


_is_contained_str(){
    __doc__='
    Args:
        arg : the query to check if it is contained in the values
        values : a string of space separated values

    Example:
        source ~/code/transcrypt/bash_helpers.sh
        # Demo using raw call
        (_is_contained_str "foo" "foo bar baz" && echo "contained") || echo "missing"
        (_is_contained_str "bar" "foo bar baz" && echo "contained") || echo "missing"
        (_is_contained_str "baz" "foo bar baz" && echo "contained") || echo "missing"
        (_is_contained_str "biz" "foo bar baz" && echo "contained") || echo "missing"
        # Demo using variables
        arg="bar"
        values="foo bar baz"
        (_is_contained_str "$arg" "$values" && echo "contained") || echo "missing"
    '
    arg=$1
    values=$2
    echo "$values" | tr -s ' ' '\n'  | grep -Fx "$arg" &>/dev/null
}

_is_contained_arr(){
    __doc__='
    Check if the first value is contained the rest of the values

    Args:
        arg : the query to check if it is contained in the values
        *values : the rest of the arguments are individual elements in the values

    Example:
        source ~/code/transcrypt/bash_helpers.sh
        # Demo using raw call
        (_is_contained_arr "bar" "foo" "bar" "baz" && echo "contained") || echo "missing"
        (_is_contained_arr "biz" "foo" "bar" "baz" && echo "contained") || echo "missing"
        # Demo using variables
        values=("foo" "bar" "baz")
        arg="bar" 
        (_is_contained_arr "$arg" "${values[@]}" && echo "contained") || echo "missing"
        arg="biz" 
        (_is_contained_arr "$arg" "${values[@]}" && echo "contained") || echo "missing"
    '
    # The first argument must be equal to one of the subsequent arguments
    local arg=$1
    shift
    local arr=("$@")
    for val in "${arr[@]}"; 
    do
        if [[ "${arg}" == "${val}" ]]; then
            return 0
        fi
    done
    return 1
}

_set_global(){
    # sets a bash global variable by name
    key=$1
    val=$2
    printf -v "$key" '%s' "$val"
}

_validate_variable_arr(){
    __doc__='
    Example:
        source bash_helpers.sh
        foo="bar"
        valid_values=("bar" "biz")
        _validate_variable "foo" "${valid_values[@]}"
        interactive=1
        _validate_variable "blaz" "${valid_values[@]}"
    '
    local varname=$1
    local valid_values=$2
    local varval=${!varname}
    if ! _is_contained_arr "$varval" "${valid_values[@]}"; then
        local valid_values_str
        valid_values_str=$(joinby ', ' "${valid_values[@]}")
        message=$(printf "%s is %s, but must be one of: %s" "$varname" "$varval" "$valid_values_str")
		if [[ $interactive ]]; then
            _set_global "$varname" ""
            echo "$message"
		else
            die 1 "$message"
        fi
    fi
}


_validate_variable_str(){
    __doc__='
    Checks if the target variable is in the set of valid values.
    If it is not, it unsets the target variable, then if not in interactive
    mode it calls die.

    Args:
        varname: name of variable to validate
        valid_values: space separated string of valid values

    Example:
        source bash_helpers.sh
        valid_values="bar biz"
        foo="bar"
        _validate_variable_str "foo" "$valid_values"
        interactive=1
        blaz=fds
        _validate_variable_str "blaz" "$valid_values"
    '
    local varname=$1
    local valid_values=$2
    local varval=${!varname}
    if ! _is_contained_str "$varval" "$valid_values"; then
        message=$(printf '%s is `%s`, but must be one of: %s' "$varname" "$varval" "$valid_values")
		if [[ $interactive ]]; then
            _set_global "$varname" ""
            echo "$message"
		else
            die 1 "$message"
        fi
    fi
}

_get_user_input2() {
    __doc__='
    Helper to prompt the user, store a response, and validate the result
    Args:
        varname : name of the bash variable to populate
        default : the default value to use if the user provides no answer
        valid_values: space separated string of valid values
        prompt : string to present to the user

    Example:
        source ~/code/transcrypt/bash_helpers.sh
        interactive=1
        myvar=
        echo "myvar = <$myvar>"
        _get_user_input2 "myvar" "a" "a b c" "choose one"
    '
    local varname=$1
    local default=$2
    local valid_values=$3
    local prompt=$4

	while [[ ! ${!varname} ]]; do
		local answer=
		if [[ $interactive ]]; then
			printf '%s > ' "$prompt"
			read -r answer
		fi
        # use the default value if the user gave no answer; otherwise call the
        # validate function, which should set the varname to empty if it is
        # invalid and the user should continue, otherwise it should die.
		if [[ ! $answer ]]; then
            _set_global "$varname" "$default"
		else
            _set_global "$varname" "$answer"
            _validate_variable_str "$varname" "$valid_values"
		fi
	done
}


# Helper to prompt the user, store a response, and validate the result
_get_user_input() {
	local varname=$1
	local default=$2
	local validate_fn=$3
	local prompt=$4

	while [[ ! ${!varname} ]]; do
		local answer=
		if [[ $interactive ]]; then
			printf '%s' "$prompt"
			read -r answer
		fi
		# use the default value if the user gave no answer; otherwise call the
		# validate function, which should set the varname to empty if it is
		# invalid and the user should continue, otherwise it should die.
		if [[ ! $answer ]]; then
			_set_global "$varname" "$default"
		else
			_set_global "$varname" "$answer"
			${validate_fn}
		fi
	done
}


# Load a config var from the versioned config 
# shellcheck disable=SC2155
_load_versioned_config_var(){
	# the current git repository's top-level directory
	if [ -z "${VERSIONED_TC_CONFIG+x}" ]; then
		readonly REPO=$(git rev-parse --show-toplevel 2>/dev/null)
		# This is the place where transcrypt can store state that will be
		# "versioned" (i.e. checked into the repo)
		readonly VERSIONED_TC_DIR="${REPO}/.transcrypt"
		readonly VERSIONED_TC_CONFIG="${VERSIONED_TC_DIR}/config"
	fi
	local key=$1
	# Test for blocked variables that should not go into a plaintext config file
	if _is_contained_str "${key}" "${VERSIONED_CONFIG_BLOCKLIST}"; then
		warn "Cannot use ${key} in versioned the transcrypt config"
		return 1
	fi
    # https://unix.stackexchange.com/questions/175648/use-config-file-for-my-shell-script
	git config --file "${VERSIONED_TC_CONFIG}" --get "${key}" || true
}

# Write a config var to the versioned config 
_set_versioned_config_var(){
	local key=$1
	local val=$2
	# Test for blocked variables that should not go into a plaintext config file
	if _is_contained_str "${key}" "${VERSIONED_CONFIG_BLOCKLIST}"; then
		warn "Cannot use ${key} in versioned the transcrypt config"
		return 1
	fi
	mkdir -p "${VERSIONED_TC_DIR}"
	git config --file "${VERSIONED_TC_CONFIG}" "${key}" "${val}"
}

# 
_load_config_var(){
	# First try loading from the local checkout-independent .git/config file
	# If that doesn't work, then look in the .transcrypt/config file
	# (which is expected to be stored in plaintext and checked into the repo)
	# Certain values will be blocked from being placed here (like the password)
	local key=$1
	git config --get --local "${key}"
	if [[ "$?" != "0" ]]; then
		_load_versioned_config_var "${key}"
	fi
}

# shellcheck disable=SC2155
_load_transcrypt_config_vars(){
	# Populate bash vars with our config
	cipher=$(git config --get --local transcrypt.cipher)
	digest=$(git config --get --local transcrypt.digest)
	use_pbkdf2=$(git config --get --local transcrypt.use-pbkdf2)
	salt_method=$(git config --get --local transcrypt.salt-method)

	password=$(git config --get --local transcrypt.password)
	openssl_path=$(git config --get --local transcrypt.openssl-path)

	if [[ "$salt_method" == "configured" ]]; then
		config_salt=$(_load_versioned_config_var "transcrypt.config-salt")
	else
		config_salt=""
	fi
}

_load_vars_for_encryption(){
	# Helper to populate variables needed to call openssl encryption
	_load_transcrypt_config_vars

	if [[ "$use_pbkdf2" == "1" ]]; then
		pbkdf2_args=('-pbkdf2')
	else
		pbkdf2_args=()
	fi

	if [[ "$salt_method" == "password" ]]; then
		extra_salt=$password
	elif [[ "$salt_method" == "configured" ]]; then
		extra_salt=$config_salt
	else
		die "unknown salt method"
	fi

	if [[ "$extra_salt" == "" ]]; then 
		die "Extra salt is not set"
	fi
}

_benchmark_methods(){
    # Development helepr to determine which way of checking if we have a available digest / cipher is fastest
    arg="sha512"
    source ~/code/transcrypt/bash_helpers.sh
    time (openssl list -digest-commands | tr -s ' ' '\n'  | grep -Fx "$arg")
    echo $?
    time _is_contained_str "$arg" "$(openssl list -digest-commands)"
    echo $?
    time (readarray -t available <<< "$(openssl list -digest-commands | tr -s ' ' '\n')" && _is_contained_arr "$arg" "${available[@]}") 
    echo $?
    #bash_array_repr "${available[@]}"
}


_lowercase(){
    __doc__='
    _lowercase "FOO"
    '
    echo "$1" |  tr '[:upper:]' '[:lower:]'
}
