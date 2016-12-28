#!/bin/bash
# Copyright Brian Starkey <stark3y@gmail.com>, 2016

function usage_and_exit() {
	cat >&2 <<EOM
Usage: $0 [-c config_file] COMMAND MOUNTPOINT

Options:
	-c config_file      Config file to use, if not specified defaults to
	                    /etc/backup.conf

Commands:

	init
		Set up directories for backups for MOUNTPOINT; a snapshot directory on
		the same filesystem, and if a remote repository is configured, then a
		directory in the repo too.

		This should be run once for each desired backup directory.

	snapshot
		Take a local snapshot of the given MOUNTPOINT.

	sync
		Synchronise with the remote repository.
EOM
	exit 1
}

if [ $# -eq 0 ]
then
	usage_and_exit
fi

# Default argument values
CONFIG="/etc/backup.conf"
KEEP_LOCAL=1

# Argument parsing
NARGS=0
while [ $# -gt 0 ]
do
	getopts ":c:" OPT
	if [ $? -eq 0 ]
	then
		case $OPT in
		c)
			CONFIG=$OPTARG
			if [ ! -f $CONFIG ]
			then
				echo "ERROR: Config file $CONFIG doesn't exist"
				exit 1
			fi
			# shift to 'consume' the filename argument
			shift
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
	else
		ARGS[$NARGS]=$1
		NARGS=$(($NARGS + 1))
	fi
	shift
done

if [ $NARGS -gt 2 ]
then
	echo "ERROR: Excess arguments" >&2
	usage_and_exit
elif [ $NARGS -lt 2 ]
then
	echo "ERROR: COMMAND and MOUNTPOINT are required" >&2
	usage_and_exit
fi

# Load the config
source $CONFIG

if [ $DEBUG -gt 0 ]
then
	VERBOSE="--verbose"
fi

# Helper functionality
# Extract filesystem label from "btrfs filesystem show"
function get_label() {
	# FIXME: Workaround for automounts, which don't seem to get triggered
	# by "btrfs filesystem show"
	ls $1 2>&1 > /dev/null

	FS_DETAILS=$(sudo btrfs filesystem show $1 2>&1)
	RET=$?
	if [ $RET != 0 ]
	then
		echo "$FS_DETAILS"
		exit $RET
	fi

	LABEL=$(echo $FS_DETAILS | grep "Label:" | sed -n "s/Label: '\(.*\)'.*$/\1/p")
	if [ -z $LABEL ]
	then
		echo "ERROR: Couldn't get filesystem label for $1"
		exit 1
	fi
	return 0
}

# Check that $1 is a mount for filesystem labelled $LABEL
function check_fs_label() {
	TMP=$LABEL
	get_label $1
	if [ $LABEL != $TMP ]
	then
		echo "ERROR: $1 isn't a mount for filesystem label $TMP"
		exit 1
	fi
	LABEL=$TMP
}

# Check remote settings
function check_remote() {
	if [ -z $REMOTE_HOST ]
	then
		echo "No remote host configured."
		return 1
	elif [ -z $REMOTE_USER ] || [ -z $REMOTE_REPO ]
	then
		echo "ERROR: \$REMOTE_HOST, \$REMOTE_USER and \$REMOTE_REPO are required"
		exit 1
	fi

	LOCALHOST=$(hostname)
	if [ $REMOTE_HOST == $LOCALHOST ]
	then
		REMOTE_HOST="localhost"
	fi

	# FIXME: Fix handling of $REMOTE_HOST == $LOCALHOST to not use ssh at all
	ssh $REMOTE_USER@$REMOTE_HOST cd
	if [ $? != 0 ]
	then
		echo "ERROR: Couldn't access remote host: $REMOTE_HOST"
		exit 1
	fi
}

COMMAND=$(echo -n "${ARGS[0]}" | tr '[A-Z]' '[a-z]')
MOUNTPOINT=$(realpath ${ARGS[1]})

case $COMMAND in
	init)
		echo "Initialising backup for $MOUNTPOINT"

		get_label $MOUNTPOINT
		check_fs_label /mnt/$LABEL
		SNAPSHOT_DIR=$(realpath -m "/mnt/$LABEL/snapshots/$MOUNTPOINT")

		mkdir -p $SNAPSHOT_DIR
		if [ ! -d $SNAPSHOT_DIR ]
		then
			echo "ERROR: Couldn't create local backup dir $SNAPSHOT_DIR"
			exit 1
		fi

		# Initialise remote
		check_remote
		if [ $? -ne 0 ]
		then
			exit 0
		fi
		REMOTE_BACKUP_NAME=$LOCALHOST$MOUNTPOINT
		echo "Setting up remote: $REMOTE_USER@$REMOTE_HOST:$REMOTE_REPO $REMOTE_BACKUP_NAME"
		ssh $REMOTE_USER@$REMOTE_HOST backup_repo_add.sh $REMOTE_REPO $REMOTE_BACKUP_NAME
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
