# Copyright Brian Starkey <stark3y@gmail.com>, 2016
# One component of the backup.sh suite. This file is not intended to be
# executed independently, but sourced from the main backup.sh script.

BACKUP_COMMANDS+=("sync")

function sync_usage() {
	cat >&2 <<EOM
	sync [-k] MOUNTPOINT
		Synchronise MOUNTPOINT snapshots with the remote repository.

		Options:
		    -k       Keep local snapshots, even when they have been successfully
		             sent to the remote. Default is to remove snapshots when
		             they have been sent.

EOM
}

function sync_parse_args() {
	# Defaults
	KEEP_LOCAL=0

	while getopts ":k" OPT
	do
		case $OPT in
		k)
			echo "Keeping local snapshots"
			KEEP_LOCAL=1
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

	shift $(( $OPTIND - 1 ))
	if [ $# -ne 1 ]
	then
		echo "Expected MOUNTPOINT, got '$@'" >&2
		usage_and_exit
	fi
	MOUNTPOINT=$(realpath $1)
}

function sync_command() {
	sync_parse_args $@

	echo "Initialising backup for $MOUNTPOINT"

	remote_or_die
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
}
