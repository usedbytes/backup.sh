#!/bin/bash

REPO=$(realpath $1)
BACKUP=$2

if [ ! -f $REPO/.backup_list ]
then
	echo "ERROR: Couldn't determine repository"
	exit 1
fi

grep -q "^$REPO/$BACKUP\$" $REPO/.backup_list
if [ $? != 0 ]
then
	echo "ERROR: Requested backup not in list."
	exit 1
fi

if [ ! -d $REPO/$BACKUP ]
then
	echo "ERROR: No such backup directory: $REPO/$BACKUP"
	exit 1
fi

# Match backup snapshots the same way snapbtrex does
# (which is horrible and will end badly if someone uses similar filenames)
for i in `find $REPO/$BACKUP/ -maxdepth 1 -mindepth 1 -type d`
do
	candidate=$(basename $i)
	python2 -c "import time; time.strptime('$candidate', '%Y%m%d-%H%M%S')" 2> /dev/null
	if [ $? == 0 ]
	then
		sudo btrfs subvolume delete $i
	fi
done

# Remove this dir from our list
DIR="$REPO/$BACKUP"
sed -i '\|^'$DIR'$|d' $REPO/.backup_list

# Try and delete the rest of the tree if no-one is using it
TMP=$BACKUP
while [ "$TMP" != "." ]
do
	grep -q "^$REPO/$TMP" $REPO/.backup_list
	if [ $? != 0 ]
	then
		echo "Try to clean redundant dir $TMP"
		rmdir $REPO/$TMP
		if [ $? != 0 ]
		then
			break
		fi
	fi
	TMP=$(dirname $TMP)
done
