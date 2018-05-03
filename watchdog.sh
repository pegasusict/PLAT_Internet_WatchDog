#!/bin/bash
############################################################################
# Pegasus' Linux Administration Tools #					 Internet Watchdog #
# (C)2017-2018 Mattijs Snepvangers	  #				 pegasus.ict@gmail.com #
# License: GPL v3					  # Please keep my name in the credits #
############################################################################
START_TIME=$(date +"%Y-%m-%d_%H.%M.%S.%3N")
declare -g VERBOSITY=5
declare -g LOG_FILE_CREATED=false
tolog() {
	local _LOG_ENTRY="$1"
	if [ $LOG_FILE_CREATED != true]
	then
		if [ -z ${LOG_BUFFER+x} ] ; then declare -g LOG_BUFFER="" ; fi
		echo $_LOG_ENTRY >> $LOG_BUFFER
	else
		if [ -z ${LOG_BUFFER+x} ] ; then declare -g LOG_BUFFER="" ; fi
		if var_exists $_LOG_BUFFER
		then
			echo $_LOG_BUFFER >> "$LOG_FILE"
			unset $_LOG_BUFFER
			echo $_LOG_ENTRY >> "$LOG_FILE"
		fi
	fi
}
# Making sure this script is run by bash to prevent mishaps
if [ "$(ps -p "$$" -o comm=)" != "bash" ]; then bash "$0" "$@" ; exit "$?" ; fi
# Make sure only root can run this script
if [[ $EUID -ne 0 ]]; then echo "This script must be run as root" ; exit 1 ; fi
echo "$START_TIME ## Starting Watchdog Process #######################"
### DECLARING FUNCTIONS ########################################################

### INIT #############################
init() {
	dbg_line "INIT start"
	################### PROGRAM INFO ##############################################
	declare -gr PROGRAM_SUITE="Pegasus' Linux Administration Tools"
	declare -gr SCRIPT="${0##*/}"
	declare -gr SCRIPT_DIR="${0%/*}"
	declare -gr SCRIPT_TITLE="Internet Watchdog"
	declare -gr MAINTAINER="Mattijs Snepvangers"
	declare -gr MAINTAINER_EMAIL="pegasus.ict@gmail.com"
	declare -gr COPYRIGHT="(c)2017-$(date +"%Y")"
	declare -gr VERSION_MAJOR=0
	declare -gr VERSION_MINOR=2
	declare -gr VERSION_PATCH=0
	declare -gr VERSION_STATE="BETA"
	declare -gr VERSION_BUILD=20180503
	declare -gr LICENSE="MIT"
	###############################################################################
	declare -gr PROGRAM="$PROGRAM_SUITE - $SCRIPT_TITLE"
	declare -gr SHORT_VERSION="$VERSION_MAJOR.$VERSION_MINOR.$VERSION_PATCH-$VERSION_STATE"
	declare -gr VERSION="Ver$SHORT_VERSION build $VERSION_BUILD"
	declare -gr DEFAULT_TEST_SERVER="www.google.com"

	### initializing terminal colors
	create_constants
	create_logfile
	dbg_line "INIT end"
}
get_screen_size() { ### gets terminal size and sets global vars
					#+  SCREEN_HEIGHT and SCREEN_WIDTH
	dbg_line "getting screen size"
	declare -g SCREEN_HEIGHT=$(tput lines) #${ $LINES:-25 }
	declare -g SCREEN_WIDTH=$(tput cols) #${ $COLUMNS:-80 }
	dbg_line "Found $SCREEN_HEIGHT lines and $SCREEN_WIDTH columns."
}
#####
create_constants() { ### defines constants
	dbg_line "creating constants"
	declare -gr LOG_EXT=".log"
	declare -gr LOG_DIR="/var/log/plat/"
	declare -gr LOG_FILE="$LOG_DIR$SCRIPT_$START_TIME$LOG_EXT"
	dbg_line "constants created"
}
get_args() { ### parses commandline arguments
	dbg_line "parsing args"
	getopt --test > /dev/null
	if [[ $? -ne 4 ]]
	then
		err_line "I’m sorry, \"getopt --test\" failed in this environment."
		exit 1
	fi
	OPTIONS="hv:s:"
	LONG_OPTIONS="help,verbosity:,server:"
	PARSED=$(getopt -o $OPTIONS --long $LONG_OPTIONS -n "$0" -- "$@")
	if [ $? -ne 0 ]
		then usage
	fi
	eval set -- "$PARSED"
	while true; do
		case "$1" in
			-h|--help			) dbg_line "help asked"				;	usage						;	shift	;;
			-v|--verbosity		) dbg_line "set verbosity to $2"	;	set_verbosity $2			;	shift 2	;;
			-s|--server			) dbg_line "set testserver to $2"	;	declare -gr TEST_SERVER=$2	;	shift 2	;;
			--					) shift; break ;;
			*					) break ;;
		esac
	done
	dbg_line "done parsing args"
}
set_verbosity() { ### Set verbosity level
	dbg_line "setting verbosity to $1"
	case $1 in
		1	)	declare -gr VERBOSITY=1; info_line "Verbosity is set to 1";;	### Be vewy, vewy quiet... Will only show Critical errors which result in an untimely exiting of the script
		2	)	declare -gr VERBOSITY=2; info_line "Verbosity is set to 2";;	# Will show errors that don't endanger the basic functioning of the program
		3	)	declare -gr VERBOSITY=3; info_line "Verbosity is set to 3";;	# Will show warnings
		4	)	declare -gr VERBOSITY=4; info_line "Verbosity is set to 4";;	# Let me know what youre doing, every step of the way
		5	)	declare -gr VERBOSITY=5; info_line "Verbosity is set to 5";;	# I want it all, your thoughts and dreams too!!!

		*	)	declare -gr VERBOSITY=3; info_line "Verbosity is set to default 3";;	## DEFAULT
	esac
}
### User Interface & LOGGING ###################################################
usage() { ### returns usage information
	version
	cat <<-EOT
		USAGE: sudo bash $SCRIPT -h
				or
			   sudo bash $SCRIPT [ -v INT ] [ -s <uri> ]

		OPTIONS

		   -v or --verbosity	defines the amount of chatter. 0=CRITICAL, 1=WARNING, 2=INFO, 3=VERBOSE, 4=DEBUG. default=2
		   -s or --server		defines which server, instead of the default server is to be used to test our DNS
		   -h or --help			prints this message

		  The options can be used in any order

		  WARNING!!! There is no error checking on the URI you give to check against!!!
		  If you want to screw up your server, that's on your shoulders!
		EOT
	exit 3
}
version() { ### returns version information
	echo -e "\n$PROGRAM $VERSION - $COPYRIGHT $MAINTAINER"
}
###
crit_line() { ### CRITICAL MESSAGES
	local _MESSAGE="$1"
	log_line 1 "$_MESSAGE"
}
err_line() { ### ERROR MESSAGES
	local _MESSAGE="$1"
	log_line 2 "$_MESSAGE"
}
warn_line() { ### WARNING MESSAGES
	local _MESSAGE="$1"
	log_line 3 "$_MESSAGE"
}
info_line() { ### VERBOSE MESSAGES
	local _MESSAGE="$1"
	log_line 4 "$_MESSAGE"
}
dbg_line() { ### DEBUG MESSAGES
	if [[ "$VERBOSITY" -ge 5 ]]
	then
		local _MESSAGE="$1"
		log_line 5 "$_MESSAGE"
	fi
}
###
log_line() {	# creates a nice logline and decides what to print on screen and
				#+ what to send to logfile based on VERBOSITY and IMPORTANCE levels
				# messages up to level 4 are sent to log
				# if verbosity = 5, all messages are printed on screen and sent to log incl debug
				# usage: log_line <importance> <message>
	_log_line_length() {
		local _LINE=""
		_LINE="$_LOG_LINE$_MESSAGE $_LOG_LINE_FILLER"
		echo ${#_LINE}
	}
	local _IMPORTANCE=$1
	local _MESSAGE=$2
	local _LABEL=""
	local _LOG_LINE=""
	local _SCREEN_LINE=""
	local _LOG_LINE_FILLER=""
	case $_IMPORTANCE in
		1	)	_LABEL="CRITICAL"	;;
		2	)	_LABEL="ERROR"		;;
		3	)	_LABEL="WARNING"	;;
		4	)	_LABEL="INFO"		;;
		5	)	_LABEL="DEBUG"		;;
	esac
	_LOG_LINE="$(get_timestamp) # $_LABEL: "
	local IMAX=$SCREEN_WIDTH-$(_log_line_length)
	for (( i=1 ; i<IMAX ; i++ ))
	do
		_LOG_LINE_FILLER+="#"
	done
	_MESSAGE+=" $_LOG_LINE_FILLER"
	if (( "$_IMPORTANCE" <= "$VERBOSITY" ))
	then
		case $_IMPORTANCE in
			1	)	crit_colors "$_LOG_LINE" "$_MESSAGE"	;;
			2	)	err_colors "$_LOG_LINE" "$_MESSAGE"		;;
			3	)	warn_colors "$_LOG_LINE" "$_MESSAGE"	;;
			4	)	info_colors "$_LOG_LINE" "$_MESSAGE"	;;
			5	)	dbg_colors "$_LOG_LINE" "$_MESSAGE"		;;
		esac
	fi
	_LOG_LINE+=$_MESSAGE
	echo "$_LOG_LINE" >> tolog
}
define_colors() {
	# Reset
	Color_Off='\033[0m'			# Text Reset

	# Regular Colors
	Black='\033[0;30m'			# Black
	Red='\033[0;31m'			# Red
	Green='\033[0;32m'			# Green
	Yellow='\033[0;33m'			# Yellow
	Blue='\033[0;34m'			# Blue
	Purple='\033[0;35m'			# Purple
	Cyan='\033[0;36m'			# Cyan
	White='\033[0;37m'			# White

	# Bold
	BBlack='\033[1;30m'			# Black
	BRed='\033[1;31m'			# Red
	BGreen='\033[1;32m'			# Green
	BYellow='\033[1;33m'		# Yellow
	BBlue='\033[1;34m'			# Blue
	BPurple='\033[1;35m'		# Purple
	BCyan='\033[1;36m'			# Cyan
	BWhite='\033[1;37m'			# White

	# Underline
	UBlack='\033[4;30m'			# Black
	URed='\033[4;31m'			# Red
	UGreen='\033[4;32m'			# Green
	UYellow='\033[4;33m'		# Yellow
	UBlue='\033[4;34m'			# Blue
	UPurple='\033[4;35m'		# Purple
	UCyan='\033[4;36m'			# Cyan
	UWhite='\033[4;37m'			# White

	# Background
	On_Black='\033[40m'			# Black
	On_Red='\033[41m'			# Red
	On_Green='\033[42m'			# Green
	On_Yellow='\033[43m'		# Yellow
	On_Blue='\033[44m'			# Blue
	On_Purple='\033[45m'		# Purple
	On_Cyan='\033[46m'			# Cyan
	On_White='\033[47m'			# White

	# High Intensity
	IBlack='\033[0;90m'			# Black
	IRed='\033[0;91m'			# Red
	IGreen='\033[0;92m'			# Green
	IYellow='\033[0;93m'		# Yellow
	IBlue='\033[0;94m'			# Blue
	IPurple='\033[0;95m'		# Purple
	ICyan='\033[0;96m'			# Cyan
	IWhite='\033[0;97m'			# White

	# Bold High Intensity
	BIBlack='\033[1;90m'		# Black
	BIRed='\033[1;91m'			# Red
	BIGreen='\033[1;92m'		# Green
	BIYellow='\033[1;93m'		# Yellow
	BIBlue='\033[1;94m'			# Blue
	BIPurple='\033[1;95m'		# Purple
	BICyan='\033[1;96m'			# Cyan
	BIWhite='\033[1;97m'		# White

	# High Intensity backgrounds
	On_IBlack='\033[0;100m'		# Black
	On_IRed='\033[0;101m'		# Red
	On_IGreen='\033[0;102m'		# Green
	On_IYellow='\033[0;103m'	# Yellow
	On_IBlue='\033[0;104m'		# Blue
	On_IPurple='\033[0;105m'	# Purple
	On_ICyan='\033[0;106m'		# Cyan
	On_IWhite='\033[0;107m'		# White
}
crit_colors() {
	local _LABEL="$1"
	local _MESSAGE="$2"
	local _OUTPUT="$BIYellow$On_IRed$_LABEL$Color_Off $Red$On_Black$_MESSAGE$Color_Off"
	echo -e "$_OUPUT"
}
err_colors() {
	local _LABEL="$1"
	local _MESSAGE="$2"
	local _OUTPUT="$BRed$On_Black$_LABEL$Color_Off $Red$On_Black$_MESSAGE$Color_Off"
	echo -e "$_OUPUT"
}
warn_colors() {
	local _LABEL="$1"
	local _MESSAGE="$2"
	local _OUTPUT="$Red$On_White$_LABEL$Color_Off $Red$On_White$_MESSAGE$Color_Off"
	echo -e "$_OUPUT"
}
info_colors() {
	local _LABEL="$1"
	local _MESSAGE="$2"
	local _OUTPUT="$Black$On_White$_LABEL$Color_Off $Black$On_White$_MESSAGE$Color_Off"
	echo -e "$_OUPUT"
}
dbg_colors() {
	local _LABEL="$1"
	local _MESSAGE="$2"
	local _OUTPUT="$Black$On_White$_LABEL$Color_Off $Black$On_Green$_MESSAGE$Color_Off"
	echo -e "$_OUTPUT"
}
create_logfile() {
    create_file $LOG_FILE
    declare -gr LOG_FILE_CREATED=true
}
create_file() { ### Creates file if it doesn't exist
	local _TARGET_FILE="$1"
	if [ ! -f "$_TARGET_FILE" ]
	then
		touch "$_TARGET_FILE"
	fi
}
### (Inter)Net(work) ###########################################################
cycle_network() {
	dbg_line "cycle_network: resetting network"
	ifdown --exclude=lo -a && ifup --exclude=lo -a 
}
test_DNS() {
	dbg_line "test_DNS: testing DNS"
	local _SERVER="$1"
	# Checking for the resolved IP address from the end of the command output. Refer
	# the normal command output of nslookup to understand why.
	local _RESOLVED_IP=$(nslookup "$_SERVER" | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)
	# Deciding the lookup status by checking the variable has a valid IP string
	dbg_line "test_DNS: nslookup $_SERVER yielded $_RESOLVED_IP"
	if [[ -z "$_RESOLVED_IP" ]]
	then
		declare -g DNS_STATE="false"
		dbg_line "test_DNS: DNS DOWN"
	else
		declare -g DNS_STATE="true"
		dbg_line "test_DNS: DNS OK"
	fi
}
watch_dog() {
	local _TEST_SERVER="$1"
	dbg_line "watch_dog: commencing DNS testing"
	while true
	do
		test_DNS "$_TEST_SERVER"
		if [ "$DNS_STATE" == "false" ]
		then
			err_line "watch_dog: DNS Down, resetting network"
			cycle_network
		else
			dbg_line "watch_dog: DNS works fine"
		fi
		dbg_line "watch_dog: sleeping for 1 minute"
		sleep 60
	done
}
### DATE/TIME ##################################################################
get_timestamp() { ### returns something like 2018-03-23_13.37.59.123
	echo $(date +"%Y-%m-%d_%H.%M.%S.%3N")
}

insert_into_initd() {
	#copy to /etc/init.d/
	cp "$SCRIPT_DIR/$SCRIPT" /etc/init.d/
	# set rights and ownership
	chmod a+x "/etc/init.d/$SCRIPT"
	chown root "/etc/init.d/$SCRIPT"
	update-rc.d $SCRIPT
}
### start preperations ###
define_colors
get_screen_size

init
get_args  "$@"
### verified up to here --------------------------------------------------
if [ -z ${TEST_SERVER+x} ]
then
	declare -gr TEST_SERVER="$DEFAULT_TEST_SERVER"
	info_line "test server is set to default"
fi
### end of preperations ###

watch_dog $TEST_SERVER
