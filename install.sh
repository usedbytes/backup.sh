#!/bin/bash

# http://stackoverflow.com/a/12694189
SRCDIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]
then
	SRCDIR="$PWD"
fi

function usage_and_exit() {
	cat >&2 <<EOM
Usage: $0 COMMAND ...

Commands:
	install-repo REPO_DISK_LABEL
		Setup a repository on disk label REPO_DISK.
		Run this once per repository.

	install-client
		Install files for a backup client. Run this once per client

	enable-disk DISK_LABEL
		Set up a filesystem for storing and sending backups. Run this once per
		client filesystem.
EOM
	exit 1
}

function fail() {
	# TODO: Cleanup half-finished things
	cleanup_tmpdir
	exit 1
}

function install_file() {
	if [ $# -ne 2 ]
	then
		echo "ERROR: install_file() expects two arguments: src, dst" >&2
		fail
	fi

	sudo cp -v --no-clobber $1 $2
}

function start_enable_unit() {
	if [ $# -ne 1 ]
	then
		echo "ERROR: start_enable_service() expects an argument: unit" >&2
		fail
	fi
   sudo systemctl enable $1
   sudo systemctl start $1
}

function enter_tmpdir() {
	TMPDIR=$(mktemp -d)
	pushd $TMPDIR
}

function cleanup_tmpdir() {
	popd
	if [ -n $TMPDIR ]
	then
		rm -rf $TMPDIR
	fi
}

function get_snapbtrex() {
	SNAPBTREX_REPO=https://github.com/yoshtec/snapbtrex.git
	git clone $SNAPBTREX_REPO
}

function install_tools() {
	echo "*** Install tools..."
	get_snapbtrex
	install_file snapbtrex/snapbtrex.py /usr/local/sbin/snapbtrex
	install_file $SRCDIR/bin/\*.sh /usr/local/sbin/
}

function install_config() {
	echo "*** Installing config file..."
	install_file $SRCDIR/backup.conf /etc/
}

function setup_automount() {
	if [ $# -ne 1 ]
	then
		echo "ERROR: setup_automount() expects an argument: disk_label" >&2
		fail
	fi

	echo "*** Installing automount for label '$1'..."
	$SRCDIR/create_mount_templates.sh $1
	install_file mnt-$1.\*mount /etc/systemd/system/
	rm -f mnt-$1.*mount
}

function create_btrfs_user() {
	echo "*** Creating btrfs user..."
	sudo useradd --system -m -k /home/btrfs btrfs
	sudo -u btrfs mkdir -p /home/btrfs/.ssh
	echo "PATH=\$PATH:/usr/local/sbin:/usr/local/bin:/usr/bin" | sudo -u btrfs tee -a /home/btrfs/.ssh/environment
	install_file $SRCDIR/sudoers.d/99-btrfs-backup /etc/sudoers.d/
}

function generate_btrfs_key() {
	echo "*** Generating SSH key for btrfs user..."
	sudo -u btrfs ssh-keygen
	echo "/// Please install this key in /home/btrfs/.ssh/authorized_keys on the repo host"
	sudo -u btrfs cat /home/btrfs/.ssh/id_rsa.pub
}

function install_client_templates() {
	echo "*** Installing client templates..."
	install_file $SRCDIR/systemd/backup-poll-sync\@.service /etc/systemd/system/
	install_file $SRCDIR/systemd/backup\@.service /etc/systemd/system/
	install_file $SRCDIR/systemd/backup\@.timer /etc/systemd/system/
}

function create_repo() {
	if [ $# -ne 1 ]
	then
		echo "ERROR: create_repo() expects an argument: disk_label" >&2
		fail
	fi

	echo "*** Initialising repo in /mnt/$1/backups..."
	sudo systemctl start mnt-$1.automount
	sudo mkdir /mnt/$1/backups
	sudo chown btrfs:btrfs /mnt/$1/backups
	sudo -u btrfs backup.sh -R /mnt/$1/backups repo init
	sudo systemctl stop mnt-$1.automount
}

function create_snapshot_dir {
	if [ $# -ne 1 ]
	then
		echo "ERROR: create_snapshot_dir() expects an argument: disk_label" >&2
		fail
	fi

	echo "*** Initialising snapshot dir in /mnt/$1/snapshots..."
	sudo systemctl start mnt-$1.automount
	sudo mkdir /mnt/$1/snapshots
	sudo chown btrfs:btrfs /mnt/$1/snapshots
	sudo systemctl stop mnt-$1.automount

}

function install_repo_prune() {
	echo "*** Installing backup prune service..."
	install_file $SRCDIR/systemd/backup-repo-prune\@.timer /etc/systemd/system/
	install_file $SRCDIR/systemd/backup-repo-prune\@.service /etc/systemd/system/
}

function enable_disk_services() {
	if [ $# -ne 1 ]
	then
		echo "ERROR: enable_repo_services() expects an argument: disk_label" >&2
		fail
	fi
	start_enable_unit mnt-$1.automount
}

function enable_repo_services() {
	if [ $# -ne 1 ]
	then
		echo "ERROR: enable_repo_services() expects an argument: disk_label" >&2
		fail
	fi

	echo "*** Enabling services for repo in /mnt/$1/backups..."
	sudo systemctl daemon-reload
	enable_disk_services $1
	start_enable_unit backup-repo-prune\@mnt-$1-backups.timer
}

function install_repo() {
	if [ $# -ne 1 ]
	then
		echo "ERROR: install_repo() expects an argument: disk_label" >&2
		fail
	fi

	echo "*** Installing repo for disk $1"

	enter_tmpdir
	install_tools
	setup_automount $1
	create_btrfs_user
	create_repo $1
	install_repo_prune $1
	enable_repo_services $1
	cleanup_tmpdir
}

function install_client() {
	echo "*** Installing client files"
	enter_tmpdir
	install_tools
	install_config
	create_btrfs_user
	generate_btrfs_key
	install_client_templates
	cleanup_tmpdir
}

function enable_disk() {
	if [ $# -ne 1 ]
	then
		echo "ERROR: enable_disk() expects an argument: disk_label" >&2
		fail
	fi

	echo "*** Enabling backups for disk $1"
	enter_tmpdir
	setup_automount $1
	create_snapshot_dir $1
	enable_disk_services $1
	cleanup_tmpdir
}

if [ $# -lt 1 ]
then
	usage_and_exit
fi
COMMAND=$1
shift

case $COMMAND in
	install-repo)
		install_repo $@
		;;
	install-client)
		install_client
		;;
	enable-disk)
		enable_disk $@
		;;
	*)
		echo "ERROR: Unknown command $1" >&2
		exit 1
		;;
esac
