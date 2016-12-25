#!/bin/bash

REPO_DIR=$(realpath $1)

echo "Initialising repo in $REPO_DIR"
touch $REPO_DIR/.backup_list
