#!/bin/bash
# Copyright Brian Starkey <stark3y@gmail.com>, 2016

# http://stackoverflow.com/a/12694189
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi

# Load helper functionality and commands
BACKUP_COMMANDS=()
source $DIR/backup-funcs.sh
source $DIR/backup-init.sh

function usage_and_exit() {
	cat >&2 <<EOM
Usage: $0 [-c config_file] COMMAND MOUNTPOINT

Options:
	-c config_file      Config file to use, if not specified defaults to
	                    /etc/backup.conf

Commands:

EOM

	for cmd in "${BACKUP_COMMANDS[@]}"
	do
		usage_${cmd}
	done

	cat >&2 <<EOM
	snapshot
		Take a local snapshot of the given MOUNTPOINT.

	sync
		Synchronise with the remote repository.
EOM
	exit 1
}

# Default argument values
CONFIG="/etc/backup.conf"
KEEP_LOCAL=0

# Global arguents
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
shift 1
OPTIND=1

# Load the config and helpers
source $CONFIG
if [ $? != 0 ]
then
	exit 1
fi

if [ $DEBUG -gt 0 ]
then
	VERBOSE="--verbose"
fi

# Execute the command
case $COMMAND in
	init)
		command_init $@
		;;
	snapshot)
		echo "Taking snapshot for $MOUNTPOINT"

		get_label $MOUNTPOINT
		check_fs_label /mnt/$LABEL
		SNAPSHOT_DIR=$(realpath -m "/mnt/$LABEL/snapshots/$MOUNTPOINT")

		snapbtrex $VERBOSE --path $SNAPSHOT_DIR -s $MOUNTPOINT
		if [ $? != 0 ]
		then
			echo "ERROR: Couldn't create snapshot"
			exit 1
		fi
		;;
	sync)
		check_remote
		if [ $? -ne 0 ]
		then
			exit 0
		fi

		get_label $MOUNTPOINT
		check_fs_label /mnt/$LABEL
		SNAPSHOT_DIR=$(realpath -m "/mnt/$LABEL/snapshots/$MOUNTPOINT")

		echo "Syncing $MOUNTPOINT to remote: $REMOTE_USER@$REMOTE_HOST:$REMOTE_REPO $REMOTE_BACKUP_NAME"
		snapbtrex $VERBOSE -S --path $SNAPSHOT_DIR --remote-host "$REMOTE_USER@$REMOTE_HOST" --remote-dir $REMOTE_REPO/$LOCALHOST/$MOUNTPOINT
		if [ $? == 0 ]
		then
			if [ $KEEP_LOCAL -gt 0 ]
			then
				exit 0
			fi

			# If we succeeded in sending to the remote, then we only need to keep one
			# snapshot locally to use as the parent for next time. Clean up any others
			echo "Snapshot(s) sent to remote, cleaning up local copies"
			snapbtrex $VERBOSE -S --path $SNAPSHOT_DIR --target-backups 1 --keep-backups 1
		else
			echo "ERROR: Couldn't send to remote. Keeping local snapshots"
			exit 1
		fi
		;;
	:)
		echo "ERROR: Unknown command $COMMAND"
		exit 1
		;;
esac
