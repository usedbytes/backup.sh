#!/bin/bash

REPO=$(realpath $1)
BACKUP_LIST=$REPO/.backup_list
if [ ! -f $BACKUP_LIST ]
then
	echo "ERROR: Couldn't determine repository"
	exit 1
fi

TARGET_FREESPACE=200M
TARGET_BACKUPS=10
MIN_BACKUPS=3
DEBUG=0

if [ $DEBUG != 0 ]
then
	VERBOSE="--verbose"
fi

# http://stackoverflow.com/a/10929511
while IFS='' read -r SNAPSHOT_DIR || [[ -n "$SNAPSHOT_DIR" ]]
do
	snapbtrex $VERBOSE -S --path $SNAPSHOT_DIR \
		--target-backups $TARGET_BACKUPS \
		--keep-backups $MIN_BACKUPS \
		--target-freespace $TARGET_FREESPACE
done < "$BACKUP_LIST"
