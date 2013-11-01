#!/bin/bash

http_fetch() {
	if command -v wget >/dev/null 2>&1; then
		wget -q -4 -O $2 $1 || { 
			echo >&2 "Failed to fetch $1. Aborting install.";
			exit 1;
		}
	elif command -v curl >/dev/null 2>&1; then
		curl -sf4L $1 > $2 || { 
			echo >&2 "Failed to fetch $1. Aborting install.";
			exit 1;
		}
	else
		echo "Unable to find curl or wget, can not fetch needed files"
		exit 1
	fi
}

check_builddep() {
	command -v $1 >/dev/null 2>&1 || { 
		echo >&2 "$1 is required but not available, please install it and try again. Aborting install.";
		exit 1;
	}
}

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
echo "Installing dependencies in to: $BASE_DIR"

check_builddep make
check_builddep cc

http_fetch http://cpanmin.us /tmp/cpanm
chmod +x /tmp/cpanm

/tmp/cpanm -L $BASE_DIR LWP::UserAgent Crypt::SSLeay IO::Socket::INET6 Linux::Distribution JSON::PP JSON Log::LogLite Try::Tiny
rm /tmp/cpanm

h2ph -d $BASE_DIR /usr/include/syscall.h
h2ph -d $BASE_DIR /usr/include/sys/syscall.h
h2ph -d $BASE_DIR /usr/include/asm/unistd.h
h2ph -d $BASE_DIR /usr/include/asm/unistd_32.h
h2ph -d $BASE_DIR /usr/include/asm/unistd_64.h
h2ph -d $BASE_DIR /usr/include/bits/wordsize.h
h2ph -d $BASE_DIR /usr/include/bits/syscall.h
