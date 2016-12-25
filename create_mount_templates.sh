#!/bin/bash

TIMEOUT=30min

if [ -z $1 ]
then
	echo "ERROR: Label is required"
	exit 1
fi

LABEL=$1
if [ ! -L /dev/disk/by-label/$LABEL ]
then
	echo "ERROR: No such thing, /dev/disks/by-label/$LABEL"
	exit 1
fi


if [ -z $2 ]
then
	OPTIONS="compress=lzo,noatime"
else
	OPTIONS="$2"
fi

cat > mnt-$LABEL.mount <<END
[Unit]
Description=Mount for $LABEL

[Mount]
What=/dev/disk/by-label/$LABEL
Where=/mnt/$LABEL
Options=$OPTIONS
END

cat > mnt-$LABEL.automount <<END
[Unit]
Description=Automount $LABEL

[Automount]
Where=/mnt/$LABEL
TimeoutIdleSec=$TIMEOUT

[Install]
WantedBy=multi-user.target
END
