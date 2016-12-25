
if [ -z $SOURCE_MOUNTPOINT ]
then
	echo "ERROR: Source me with \$SOURCE_MOUNTPOINT set"
	exit 1
fi

# Extract filesystem label from "btrfs filesystem show"
function get_label() {
	FS_DETAILS=$(sudo btrfs filesystem show $1 2>&1)
	RET=$?
	if [ $RET != 0 ]
	then
		echo "$FS_DETAILS"
		return $RET
	fi

	LABEL=$(echo $FS_DETAILS | grep "Label:" | sed -n "s/Label: '\(.*\)'.*$/\1/p")
	if [ -z $LABEL ]
	then
		return 1
	fi
	return 0
}

get_label $SOURCE_MOUNTPOINT
if [ $? != 0 ]
then
	echo "ERROR: Couldn't determine mount-point for snapshots"
	exit 1
fi

SNAPSHOT_DIR=$(realpath -m "/mnt/$LABEL/snapshots/$SOURCE_MOUNTPOINT")
