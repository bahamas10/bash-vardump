#!/usr/bin/env bash
#
# Bash library for pretty-printing a variable given by name.
#
# This was inspired by `util.inspect` in Node.js, `p` in or `pp` in ruby,
# `var_dump` in php, etc.  This is intended for developers to use for debugging
# - this should not be parsed by a machine nor should the output format be
# considered stable.
#
# Author: Dave Eddy <dave@daveeddy.com>
# Date: December 18, 2024
# License: MIT

# vardump
#
# Dump the given variable (by name) information and value to stdout.
#
# Usage: vardump [-v] <name>
#
# Example:
#
# ``` bash
# $ declare -A assoc=([foo]=1 [bar]=2)
# $ vardump assoc
# (
#	['foo']='1'
#	['bar']='2'
# )
# $ vardump -v assoc
# --------------------------
# vardump: assoc
# attributes: (A)associative array
# length: 2
# (
#	['foo']='1'
#	['bar']='2'
# )
# --------------------------
# ```
#
# Arguments:
#   -v                      verbose output
#   -C [always|auto|never]  when to colorize output, defaults to auto
#
vardump() {
	# read arguments
	local _vd_verbose=false
	local _vd_color='auto'
	local OPTIND OPTARG _vd_opt
	while getopts 'C:v' _vd_opt; do
		case "$_vd_opt" in
			C) _vd_color=$OPTARG;;
			v) _vd_verbose=true;;
			*) return 1;;
		esac
	done
	shift "$((OPTIND - 1))"

	# read variable name
	local _vd_name=$1

	if [[ -z $_vd_name ]]; then
		echo 'vardump: name required as first argument' >&2
		return 1
	fi

	# optionally load colors
	local -A _vd_colors=()
	if [[ $_vd_color == always ]] || [[ $_vd_color == auto && -t 1 ]]; then
		_vd_colors[green]=$'\e[32m'
		_vd_colors[magenta]=$'\e[35m'
		_vd_colors[rst]=$'\e[0m'
		_vd_colors[dim]=$'\e[2m'

		_vd_colors[value]=${_vd_colors[green]}
		_vd_colors[key]=${_vd_colors[magenta]}
		_vd_colors[length]=${_vd_colors[magenta]}
	fi

	# optionally print header
	if $_vd_verbose; then
		echo "${_vd_colors[dim]}--------------------------${_vd_colors[rst]}"
		echo "${_vd_colors[dim]}vardump: ${_vd_colors[rst]}$_vd_name"
	fi

	# ensure the variable is defined
	if ! declare -p "$_vd_name" &>/dev/null; then
		echo "variable ${_vd_name@Q} not defined" >&2
		return 1
	fi

	# get the variable attributes - this will tell us what kind of variable
	# it is.
	local -a _vd_attrs=()
	local _vd_attr_string=${!_vd_name@a}
	local _vd_i
	for ((_vd_i = 0; _vd_i < ${#_vd_attr_string}; _vd_i++)); do
		local _vd_attr=${_vd_attr_string:_vd_i:1}
		_vd_attrs+=("$_vd_attr")
	done

	# parse the variable attributes and construct a human-readable string
	local _vd_attributes=()
	local _vd_typ=''
	for _vd_attr in "${_vd_attrs[@]}"; do
		local _vd_s=''
		case "$_vd_attr" in
			a) _vd_s='indexed array'; _vd_typ='a';;
			A) _vd_s='associative array'; _vd_typ='A';;
			r) _vd_s='read-only';;
			i) _vd_s='integer';;
			g) _vd_s='global';;
			x) _vd_s='exported';;
			*) _vd_s="unknown";;
		esac
		_vd_attributes+=("($_vd_attr)$_vd_s")
	done

	# optionally print the attributes to the user
	if $_vd_verbose; then
		echo -n "${_vd_colors[dim]}attributes: ${_vd_colors[rst]}"
		if [[ -n ${_vd_attributes[0]} ]]; then
			# separate the list of attributes by a `/` character
			(
			IFS=/
			echo -n "${_vd_attributes[*]}"
			)
		else
			echo -n '(none)'
		fi
		echo
	fi

	# print the variable itself! we use $typ defined above to format it
	# appropriately.
	local -n _vd_ref="$_vd_name"

	if [[ $_vd_typ == 'a' || $_vd_typ == 'A' ]]; then
		# print this as an array - indexed, sparse, associative,
		# whatever
		local _vd_key _vd_value

		# optionally print length
		if $_vd_verbose; then
			local _vd_length=${#_vd_ref[@]}
			printf '%s %s\n' \
			    "${_vd_colors[dim]}length:${_vd_colors[rst]}" \
			    "${_vd_colors[length]}$_vd_length${_vd_colors[rst]}"
		fi

		# loop keys and print the data itself
		echo '('
		for _vd_key in "${!_vd_ref[@]}"; do
			_vd_value=${_vd_ref[$_vd_key]}

			# safely quote the key name if it's an associative array
			# (the user controls the key names in this case so we
			# can't trust them to be safe)
			if [[ $_vd_typ == 'A' ]]; then
				_vd_key=${_vd_key@Q}
			fi

			# always safely quote the value
			_vd_value=${_vd_value@Q}

			printf '\t[%s]=%s\n' \
			    "${_vd_colors[key]}$_vd_key${_vd_colors[rst]}" \
			    "${_vd_colors[value]}$_vd_value${_vd_colors[rst]}"
		done
		echo ')'
	else
		# we are just a simple scalar value - print this as a regular,
		# safely-quoted,  value.
		echo "${_vd_colors[value]}${_vd_ref@Q}${_vd_colors[rst]}"
	fi

	# optionally print the trailer
	if $_vd_verbose; then
		echo "${_vd_colors[dim]}--------------------------${_vd_colors[rst]}"
	fi

	return 0

}

_vardump-complete() {
        COMPREPLY=(
                # add all variables
                $(compgen -v -- "${COMP_WORDS[COMP_CWORD]}")

                # add the individual flags TODO add `-C <arg>`
                $(compgen -W '-v' -- "${COMP_WORDS[COMP_CWORD]}")
        )
}

if ( return 0 &>/dev/null ); then
        # we are being sourced
        complete -F _vardump-complete vardump
else
	# we are run directly (not-sourced) - run through some examples
	declare s='some string'
	declare -r read_only='this cant be changed'
	declare -i int_value=5
	declare -ri read_only_int=8

	declare -a simple_array=(foo bar baz "$(tput setaf 1)red$(tput sgr0)")
	declare -a sparse_array=([0]=hi [5]=bye [7]=ok)
	declare -A assoc_array=([foo]=1 [bar]=2)

	vars=(
		s read_only int_value read_only_int
		simple_array sparse_array assoc_array
	)

	echo 'simple vardump'
	for var in "${vars[@]}"; do
		vardump "$var"
	done

	echo 'verbose vardump'
	for var in "${vars[@]}"; do
		vardump -v "$var"
		echo
	done
fi
