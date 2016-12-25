#!/bin/bash
# Usage: $0 REPO_BASE BACKUP_NAME

REPO=$(realpath $1)

if [ ! -f $REPO/.backup_list ]
then
	echo "ERROR: Couldn't determine repository"
	exit 1
fi

BACKUP_DIR=$REPO/$2
echo "Initialising backup in $BACKUP_DIR"
mkdir -p $BACKUP_DIR

grep -q "^$BACKUP_DIR\$" $REPO/.backup_list
if [ $? != 0 ]
then
	echo "Added $BACKUP_DIR to repo"
	echo "$BACKUP_DIR" >> $REPO/.backup_list
fi
