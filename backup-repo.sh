# Copyright Brian Starkey <stark3y@gmail.com>, 2016
# One component of the backup.sh suite. This file is not intended to be
# executed independently, but sourced from the main backup.sh script.

BACKUP_COMMANDS+=("repo")

function repo_usage() {
	cat >&2 <<EOM
	repo SUBCOMMAND ...
		Tasks relating to the management of a "remote" repo

		Subcommands:
			add BACKUP_NAME
				Add a new backup directory to the repository. This doesn't
				involve sending any snapshots for the specified backup, only
				creating directories and an entry in the repo file.

EOM
}

function repo_check() {
	if [ ! -f $REPO/.backup_list ]
	then
		echo "ERROR: Couldn't determine repository"
		exit 1
	fi
}

function repo_command() {
	if [ $# -ne 2 ]
	then
		echo "ERROR: Command 'repo' requires two arguments" >&2
		usage_and_exit
	fi

	SUBCOMMAND=$1
	BACKUP_NAME=$2
	REPO=$REMOTE_REPO
	repo_check $REPO

	case $SUBCOMMAND in
		add)
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
			;;
		*)
			echo "ERROR: Unknown SUBCOMMAND: '$SUBCOMMAND'" >&2
			usage_and_exit
			;;
	esac
}
