# Copyright Brian Starkey <stark3y@gmail.com>, 2016
# One component of the backup.sh suite. This file is not intended to be
# executed independently, but sourced from the main backup.sh script.

BACKUP_COMMANDS+=("repo")

function repo_usage() {
	cat >&2 <<EOM
	repo SUBCOMMAND ...
		Tasks relating to the management of a "remote" repo
		These are intended to be run on the machine hosting the repo.

		Subcommands:
			init
				Initialise the repo directory

			add BACKUP_NAME
				Add a new backup directory to the repository. This doesn't
				involve sending any snapshots for the specified backup, only
				creating directories and an entry in the repo file.

			remove [OPTION]... BACKUP_NAME
				Remove BACKUP_NAME from the repo. By default, doesn't remove any
				existing backups.

				Options:
					-r      Also remove all backups for the given BACKUP_NAME
					-f      Force removal, even if the given backup name doesn't
					        exist in the repo's list (useful after a previous
							'repo remove' without -r).

			prune [BACKUP_NAME]
				Prune backups. If BACKUP_NAME is specified, then only backups
				belonging to it will be removed, otherwise the whole repo will
				be pruned.
				Backups are pruned according to the configured
				REPO_TARGET_FREESPACE, REPO_TARGET_BACKUPS and REPO_MIN_BACKUPS

EOM
}

function repo_check() {
	if [ ! -f $REPO/.backup_list ]
	then
		echo "ERROR: Couldn't determine repository"
		exit 1
	fi
}


function repo_prune_command() {
	repo_check
	BACKUP_LIST=$REPO/.backup_list

	if [ $# -lt 1 ]
	then
		echo "Pruning all backups in repo"
		while IFS='' read -r SNAPSHOT_DIR || [[ -n "$SNAPSHOT_DIR" ]]
		do
			snapbtrex -S --path $SNAPSHOT_DIR \
				--target-backups $REPO_TARGET_BACKUPS \
				--keep-backups $REPO_MIN_BACKUPS \
				--target-freespace $REPO_TARGET_FREESPACE
		done < "$BACKUP_LIST"
	else
		BACKUP_NAME=$1
		grep -q "^$REPO/$BACKUP_NAME\$" $BACKUP_LIST
		if [ $? != 0 ]
		then
			echo "ERROR: Requested backup not in list."
			exit 1
		fi

		if [ ! -d $REPO/$BACKUP_NAME ]
		then
			echo "ERROR: No such backup directory: $REPO/$BACKUP_NAME"
			exit 1
		fi

		echo "Pruning backups for $BACKUP_NAME"
		snapbtrex -S --path $REPO/$BACKUP_NAME \
			--target-backups $REPO_TARGET_BACKUPS \
			--keep-backups $REPO_MIN_BACKUPS \
			--target-freespace $REPO_TARGET_FREESPACE
	fi
}

function repo_remove_command() {
	repo_check
	REMOVE_BACKUPS=0
	FORCE=0

	while getopts ":rf" OPT
	do
		case $OPT in
		r)
			REMOVE_BACKUPS=1
			;;
		f)
			FORCE=1
			;;
		\?)
			echo "Unknown option: -$OPTARG" >&2
			usage_and_exit
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
		echo "ERROR: Expected BACKUP_NAME, got '$@'" >&2
		usage_and_exit
	fi
	BACKUP_NAME=$1

	grep -q "^$REPO/$BACKUP_NAME\$" $REPO/.backup_list
	if [ $? != 0 ] && [ $FORCE == 0 ]
	then
		echo "ERROR: Requested backup not in list."
		exit 1
	fi

	if [ ! -d $REPO/$BACKUP_NAME ]
	then
		echo "ERROR: No such backup directory: $REPO/$BACKUP_NAME"
		exit 1
	fi

	if [ $REMOVE_BACKUPS -gt 0 ]
	then
		echo "Removing backups for $BACKUP_NAME"
		# Match backup snapshots the same way snapbtrex does
		# (which is horrible and will end badly if someone uses similar filenames)
		for i in `find $REPO/$BACKUP_NAME/ -maxdepth 1 -mindepth 1 -type d`
		do
			candidate=$(basename $i)
			python2 -c "import time; time.strptime('$candidate', '%Y%m%d-%H%M%S')" 2> /dev/null
			if [ $? == 0 ]
			then
				sudo btrfs subvolume delete $i
				if [ $? != 0 ]
				then
					exit 1
				fi
			fi
		done
	fi

	# Remove this dir from our list
	echo "Removing $BACKUP_NAME from repo"
	BACKUP_DIR="$REPO/$BACKUP_NAME"
	sed -i '\|^'$BACKUP_DIR'$|d' $REPO/.backup_list

	# Try and delete the rest of the tree if no-one is using it
	TMP=$BACKUP_NAME
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
}

function repo_add_command() {
	repo_check

	if [ $# -lt 1 ]
	then
		echo "ERROR: Command 'repo add' requires a BACKUP_NAME" >&2
		usage_and_exit
	fi
	BACKUP_NAME=$1
	BACKUP_DIR=$REPO/$BACKUP_NAME

	grep -q "^$BACKUP_DIR\$" $REPO/.backup_list
	if [ $? != 0 ]
	then
		echo "Initialising backup in $BACKUP_DIR"
		mkdir -p $BACKUP_DIR
		echo "$BACKUP_DIR" >> $REPO/.backup_list
		echo "Added $BACKUP_NAME to repo"
	else
		echo "Backup $BACKUP_NAME already present in repo"
	fi
}

function repo_init_command() {
	if [ $# -gt 0 ]
	then
		echo "ERROR: Excess arguments" >&2
		usage_and_exit
	fi

	if [ -f $REPO/.backup_list ]
	then
		echo "ERROR: Found existing repo in $REPO" >&2
		exit 1
	fi

	mkdir -p $REPO
	touch $REPO/.backup_list
}

function repo_command() {
	REPO=$REMOTE_REPO
	if [ $# -lt 1 ]
	then
		echo "ERROR: Command 'repo' requires a SUBCOMMAND" >&2
		usage_and_exit
	fi

	SUBCOMMAND=$1
	shift
	OPTIND=1

	case $SUBCOMMAND in
		init)
			repo_init_command $@
			;;
		add)
			repo_add_command $@
			;;
		remove)
			repo_remove_command $@
			;;
		prune)
			repo_prune_command $@
			;;
		*)
			echo "ERROR: Unknown SUBCOMMAND: '$SUBCOMMAND'" >&2
			usage_and_exit
			;;
	esac
}
