# Copyright Brian Starkey <stark3y@gmail.com>, 2016
# One component of the backup.sh suite. This file is not intended to be
# executed independently, but sourced from the main backup.sh script.

BACKUP_COMMANDS+=("snapshot")

function snapshot_usage() {
	cat >&2 <<EOM
	snapshot MOUNTPOINT
		Take a local snapshot of the given MOUNTPOINT.

EOM
}

function snapshot_command() {
	if [ $# -ne 1 ]
	then
		echo "Expected MOUNTPOINT, got '$@'" >&2
		usage_and_exit
	fi
	MOUNTPOINT=$(realpath $1)

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
}
