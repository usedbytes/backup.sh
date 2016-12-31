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

function usage_and_exit() {
	cat >&2 <<EOM
Usage: $0 [-c config_file] COMMAND MOUNTPOINT

Options:
	-c config_file      Config file to use, if not specified defaults to
	                    /etc/backup.conf

Commands:

EOM

	# Print usage for each command
	for cmd in "${BACKUP_COMMANDS[@]}"
	do
		usage_${cmd}
	done

	exit 1
}

# Default global argument values
CONFIG="/etc/backup.conf"

# Global arguments
while getopts ":c:" OPT
do
		echo "Option $OPT optind: $OPTIND"
		case $OPT in
		c)
			CONFIG=$OPTARG
			if [ ! -f $CONFIG ]
			then
				echo "ERROR: Config file $CONFIG doesn't exist"
				exit 1
			fi
			echo "Config: $OPTARG"
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

# Load the config
# FIXME: Sourcing user-provided file, massive security hole
# Potential solution: http://unix.stackexchange.com/a/206216
source $CONFIG || exit 1

if [ $DEBUG -gt 0 ]
then
	VERBOSE="--verbose"
fi

# Execute the command
for cmd in "${BACKUP_COMMANDS[@]}"
do
	if [ "$cmd" == "$COMMAND" ]
	then
		command_${cmd} $@
		exit $?
	fi
done

echo "ERROR: Unknown command '$COMMAND'" >&2
exit 1
