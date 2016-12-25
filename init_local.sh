#!/bin/bash
DEBUG=0

SOURCE_MOUNTPOINT=$(realpath $1)

DIR=$(dirname `realpath $0`)
source $DIR/local_tools.sh

echo "Initialising local dir $SNAPSHOT_DIR"
mkdir -p $SNAPSHOT_DIR
