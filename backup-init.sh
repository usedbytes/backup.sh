# Copyright Brian Starkey <stark3y@gmail.com>, 2016
# One component of the backup.sh suite. This file is not intended to be
# executed independently, but sourced from the main backup.sh script.

BACKUP_COMMANDS+=("init")

function usage_init() {
	cat >&2 <<EOM
	init
		Set up directories for backups for MOUNTPOINT; a snapshot directory on
		the same filesystem, and if a remote repository is configured, then a
		directory in the repo too.

		This should be run once for each desired backup directory.

EOM
}

function command_init() {
	if [ $# -ne 1 ]
	then
		echo "Expected MOUNTPOINT, got '$@'" >&2
		usage_and_exit
	fi
	MOUNTPOINT=$(realpath $1)

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
}
