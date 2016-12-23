#!/bin/bash
#
# Copyright 2016 Brian Starkey <stark3y@gmail.com>
#
# Create backup snapshots using snapbtrex.
#
# Usage: $0 MOUNTPOINT
#  Creates a backup snapshot of $MOUNTPOINT (which must be a btrfs subvolume)
#  following the scheme described below.
#
# This script handles finding the appropriate place for the snapshots, assuming
# multiple local btrfs devices.
#
# The btrfs filesystems must be labelled:
#    # btrfs filesystem label /dev/sdX $LABEL)
# It is assumed that the top-level subvolume of a filesystem is mounted at
# /mnt/$LABEL, with a directory "snapshots" for storing the local snapshots.
#
# For example, if there are two different btrfs filesystems in use, with two
# subvolumes:
#  /dev/sda1, Label: 'small'
#		Subvol 'root' -> Mounted at /
#  /dev/sdb1, Label: 'large'
#		Subvol 'home' -> Mounted at /home
#
# Then the two top-level subvolumes should be mounted at /mnt/small and
# /mnt/large respectively, both with a subdirectory called "snapshots"
#
# The snapshots are named after their local mountpoints, so assuming snapbtrex
# was run on both in a single instant at 20161222-115500, the resulting trees
# would be:
#
# /mnt/small
#   |- root
#   |  `- ... rootfs files
#   `- snapshots
#      `- 20161222-115500
#
# /mnt/large
#   |- home
#   |  `- ... /home files
#   `- snapshots
#      `- home
#         `- 20161222-115500
#
# A snapshot can thus be resolved to its original mountpoint by taking its path,
# and stripping the leading "/mnt/$LABEL/snapshots"
#
# The snapshots are sent to a "remote" repository (could be a different
# filesystem on this host), and if that succeeds then all but one local
# snapshots are removed.
#
# On the remote repository, the snapshots follow the same directory structure
# described above, but are namespaced into directories named after the hostname
# of the machine the snapshot belongs to.
DEBUG=0

SOURCE_MOUNTPOINT=$(realpath $1)

REMOTE_MOUNTPOINT=/mnt/testimage/backups
REMOTE_HOST="localhost"

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

if [ $DEBUG != 0 ]
then
	VERBOSE="--verbose"
fi

get_label $SOURCE_MOUNTPOINT
if [ $? != 0 ]
then
	echo "ERROR: Couldn't determine mount-point for snapshots"
	exit 1
fi

SNAPSHOT_DIR=$(realpath -m "/mnt/$LABEL/snapshots/$SOURCE_MOUNTPOINT")
echo "Assuming local snapshots dir: $SNAPSHOT_DIR"
if [ ! -d $SNAPSHOT_DIR ]
then
	echo "ERROR: Snapshot directory doesn't exist, and I won't make it."
	exit
fi

# TODO: Check that $SNAPSHOT_DIR lives on the same device as the source

# Make the actual snapbtrex snapshot.
snapbtrex $VERBOSE --path $SNAPSHOT_DIR -s $SOURCE_MOUNTPOINT

# Send snapshot(s) to remote dir (could be different filesystem on this host)
# snapbtrex improvements wanted:
#  - btrfs send/recv without ssh for "local" remotes
HOSTNAME=$(hostname)
REMOTE_DIR=$(realpath -m "$REMOTE_MOUNTPOINT/$HOSTNAME/$SOURCE_MOUNTPOINT")
echo "Assuming remote backup dir: $REMOTE_HOST:$REMOTE_DIR"

# Send snapshot(s) to remote host
# TODO: Check that the remote target directory exists
snapbtrex $VERBOSE -S --path $SNAPSHOT_DIR --remote-host $REMOTE_HOST --remote-dir $REMOTE_DIR
if [ $? == 0 ]
then
	# If we succeeded in sending to the remote, then we only need to keep one
	# snapshot locally to use as the parent for next time. Clean up any others
	echo "Snapshot(s) sent to remote, cleaning up local copies"
	snapbtrex $VERBOSE -S --path $SNAPSHOT_DIR --target-backups 1 --keep-backups 1
else
	echo "ERROR: Couldn't send to remote. Keeping local snapshots"
	exit 1
fi
