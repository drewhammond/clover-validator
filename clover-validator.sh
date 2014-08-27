#!/usr/bin/env bash

# Clover Validator
#
# Author: Drew Hammond <drew@alphagenetica.com>
# Fork: https://github.com/drewhammond/clover-validator


############################
##  Script Configuration  ##
############################

# Mount point of the EFI partition
efi_path=/Volumes/EFI

# Device Node of the EFI partition (default: empty)
efi_device_node=$(diskutil info "$efi_path" | grep "Device Node" | awk '{printf $3}')

# Path to git repo where we'll be versioning the changes that we make to
# clover configuration
clover_git_repo=~/.clover-repository

# Enable debugging functions (increases verbosity)
debug=1

# Enable tidy functionality
tidy=1

# Path to config.plist (relative to EFI path)
config_plist_path=${efi_path}/EFI/CLOVER/config.plist

# OSX Version and Build Version (you probably shouldn't touch this)
osx_version=$(echo "$(sw_vers)" | grep "ProductVersion" | awk '{printf $2}')
build_version=$(echo "$(sw_vers)" | grep "BuildVersion" | awk '{printf $2}')

# Installed Clover Version
clover_version=$(xmllint ${efi_path}/Library/Preferences/com.projectosx.clover.installer.plist --xpath "/plist/dict/integer" | egrep -o "([0-9])+" )

#######################
##  Script Workflow  ##
#######################
function main() {

	# Display debug info about environment if enabled
	[ $debug -eq 1 ] && show_debug_info

	# Ensure we have tidy and xmllint installed on computer
	try "Checking for required prerequesites..." check_required_binaries

	# Look for a mounted EFI partition
	try "Checking for mounted EFI partition..." check_if_efi_partition_is_mounted

	# Create git repo for configuration (first run only)
	if [ ! -d "${clover_git_repo}" ]; then
		try "Creating git repo for clover configuration..." create_git_repo
	fi

	# Attempt to ping Google
	# try "Checking internet connection..." check_internet_access

	# Validate clover config (look for invalid XML; not misconfigurations)
	try "Validating XML in ${config_plist_path}..." validate_xml
}

#########################################
##  Script Functions / No Edits Below  ##
#########################################

# Create git repository for the first time
function create_git_repo() {
	mkdir "${clover_git_repo}"
	cd "${clover_git_repo}" && git init --bare .
	return $?
}

# Validate XML in config.plist to make sure there are no stray errors
function validate_xml() {

	if [ ! -f "${config_plist_path}" ]; then
		return 1
	fi

	# Validate XML (todo use plutil since its designed specifically for plist files)
	if [ $tidy == 1 ]; then
		xmllint --valid --format --noblanks --nsclean --valid --xmlout "${config_plist_path}" &> /dev/null
	else
		xmllint --valid --format --noblanks --nsclean --valid --xmlout "${config_plist_path}" &> /dev/null
	fi
	return $?

}

# Verify user has connectivity to the internet
function check_internet_access() {
	ping -oq google.com 2> /dev/null
	return $?
}

# Check to see if user's system has the required binaries to perform
# the functions of this script
function check_required_binaries() {
	if [[ $(which tidy &>/dev/null) -ne 0 || $(which xmllint &>/dev/null) -ne 0 ]]; then
		echo 'Missing dependencies: tidy and xmllint. Please install and retry.'
		return 1
	fi
}

# Usage statement; Displayed when script is run without any arguments
function usage() {
	echo
	echo 'USAGE: @todo'
	echo
}

# usage

# Search for a mounted EFI partition
function check_if_efi_partition_is_mounted() {

	_result="$(diskutil info ${efi_path} | grep 'Device Node' | awk '{printf $3}')"

	if [ $? -ne 0 ]; then
		exit 1
	fi

	efi_device_node=$_result
}

# Debugging info
function show_debug_info() {
	echo
	echo '--------------------------------------------------------------------'
	echo "OS Name: $(uname -a)"
	echo "OS Version: ${osx_version} [${build_version}]"
	echo "Current User: $(whoami)"
	echo "EFI Device Node: ${efi_device_node}"
	echo "EFI Mount Point: ${efi_path}"
	echo "Clover Version: ${clover_version}"
	echo '--------------------------------------------------------------------'
	echo
}

##################################
# Non-essential helper functions #
##################################

# Wrapper for success/failure operations
# $1 = message
# $2 = function to try
function try() {
	msg="$1"
	callback="$2"

	if [[ -z "${msg}" || -z "$callback" ]]; then
		echo 'try() requires two arguments: 1) message 2) function to call'
		exit 1
	fi

	echo -ne "${msg}" && $callback
	[ $? -eq 0 ] && success || failure
}

# Echo success in terminal
function success() {
	echo '[  OK  ]'
}

# Echo failure in terminal
function failure() {
	echo '[FAILED]'
}

# Capture arguments
args="$@"

if [ "$args" == "" ]; then
	usage
else
	main
fi
