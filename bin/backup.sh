#!/bin/bash
# Copyright Brian Starkey <stark3y@gmail.com>, 2016

# http://stackoverflow.com/a/12694189
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]
then
	DIR="$PWD"
fi

# Load helper functionality and commands
BACKUP_COMMANDS=()
source $DIR/backup-funcs.sh
source $DIR/backup-init.sh
source $DIR/backup-snapshot.sh
source $DIR/backup-sync.sh
source $DIR/backup-repo.sh

function usage_and_exit() {
	usage
	exit 1
}

function usage() {
	cat >&2 <<EOM
Usage: $0 [OPTION]... COMMAND ...

Options:
	-h                  Display this usage message
	-v                  Enable verbose output
	-H hostname         Hostname for "remote" repository. If not specified,
	                    the value of BACKUP_REMOTE_HOST environment variable is
	                    used.
	-U username         Username for "remote" repository. If not specified,
	                    the value of BACKUP_REMOTE_USER environment variable is
	                    used.
	-R repodir          Directory for "remote" repository. If not specified,
	                    the value of BACKUP_REMOTE_REPO environment variable is
	                    used.

Commands:

EOM

	# Print usage for each command
	for cmd in "${BACKUP_COMMANDS[@]}"
	do
		${cmd}_usage
	done
}


# Default global argument values
DEBUG=0
REMOTE_HOST=$BACKUP_REMOTE_HOST
REMOTE_USER=$BACKUP_REMOTE_USER
REMOTE_REPO=$BACKUP_REMOTE_REPO

# Global arguments
while getopts ":c:hvH:U:R:" OPT
do
		case $OPT in
		h)
			usage
			exit 0
			;;
		v)
			DEBUG=1
			;;
		H)
			REMOTE_HOST=$OPTARG
			;;
		U)
			REMOTE_USER=$OPTARG
			;;
		R)
			REMOTE_REPO=$OPTARG
			;;
		\?)
			echo "Unknown option: -$OPTARG" >&2
			exit 1
			;;
		:)
			echo "ERROR: Option $OPTARG requires an argument" >&2
			usage_and_exit
			;;
		esac
done

if [ $OPTIND -gt $# ]
then
	echo "Please specify a command" >&2
	usage_and_exit
fi

# Get the command and reset getopts
shift $(( $OPTIND - 1 ))
COMMAND=$(echo -n "$1" | tr '[A-Z]' '[a-z]')
if [ $# -gt 0 ]
then
	shift 1
fi
OPTIND=1

if [ $DEBUG -gt 0 ]
then
	VERBOSE="--verbose"
fi

# Execute the command
for cmd in "${BACKUP_COMMANDS[@]}"
do
	if [ "$cmd" == "$COMMAND" ]
	then
		${cmd}_command $@
		exit $?
	fi
done

echo "ERROR: Unknown command '$COMMAND'" >&2
exit 1
