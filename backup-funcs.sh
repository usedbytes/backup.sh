# Copyright Brian Starkey <stark3y@gmail.com>, 2016
# Helper functions for the backup.sh script.
# Not intended to be executed independently, but sourced from the main
# backup.sh script.

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
# Exit if a remote is configured but not available
function remote_or_die() {
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
