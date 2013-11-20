package Linode::Longview::DataGetter::Disk;

=head1 COPYRIGHT/LICENSE

Copyright 2013 Linode, LLC.  Longview is made available under the terms
of the Perl Artistic License, or GPLv2 at the recipients discretion.

=head2 Perl Artistic License

Read it at L<http://dev.perl.org/licenses/artistic.html>.

=head2 GNU General Public License (GPL) Version 2

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either version 2
  of the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see http://www.gnu.org/licenses/

See the full license at L<http://www.gnu.org/licenses/>.

=cut

use strict;
use warnings;

require 'syscall.ph';
use Linode::Longview::Util qw(:BASIC detect_system);
use POSIX 'uname';
use Cwd 'abs_path';
use Config;

our $DEPENDENCIES = [];

sub get {
	my (undef, $dataref) = @_;
	$logger->trace('Collecting Disk info');

	my @swaps   = @{ _get_swap_info() };
	_get_mounted_info($dataref);

	# OpenVZ doesn't do /proc/diskstats, bail
	return $dataref if ( detect_system() eq 'openvz' );

	# get the information from /proc/diskstats
	my @data = slurp_file( $PROCFS . 'diskstats' )or do {
		$logger->info("Couldn't read ${PROCFS}diststats: $!");
		return $dataref;
	};
	my %dev_mapper;
	for my $line (@data) {
		$line =~ s/^\s*//;

		#  202 0 xvda 3125353 13998 4980 2974 366 591 760 87320 15 366 9029
		my ( $major, $minor, $device, $reads, $read_sectors, $writes, $write_sectors ) = ( split( /\s+/, $line ) )[ 0..3, 5, 7, 9 ];
		my $sector_size = slurp_file("/sys/block/$device/queue/hw_sector_size");
		unless(defined $sector_size){
			(my $phys_dev = $device) =~ s/\d+$//;
			$sector_size = slurp_file("/sys/block/$phys_dev/queue/hw_sector_size");
			$sector_size = 512 unless defined $sector_size;
		}
		my $read_bytes = $read_sectors * $sector_size;
		my $write_bytes = $write_sectors * $sector_size;
		$device = '/dev/' . $device;
		# escaped version for use inside the result hash
		(my $e_device = $device) =~ s/\./\\\./g;

		if (substr($device,0,8) eq '/dev/dm-') {
			# if the filesystem sees it under /dev
			if ( -b $device ) {
				unless (keys(%dev_mapper)) {
					%dev_mapper = map { substr(readlink($_),3) => substr($_,12); } (glob("/dev/mapper/*"));
				}
				if (exists($dev_mapper{substr($device,5)})) {
					$dataref->{INSTANT}->{"Disk.$e_device.label"} = $dev_mapper{substr($device,5)};
				}
			} else {
				unless (keys(%dev_mapper)) {
					%dev_mapper = map {
						my $rdev=(stat($_))[6];
						my $major_m = ($rdev & 03777400) >> 0000010;
						my $minor_m = ($rdev & 037774000377) >> 0000000;
						join('_', $major_m,$minor_m) => substr($_,12);
					} glob ("/dev/mapper/*");
				}
				if (exists($dev_mapper{$major."_".$minor})) {
					$dataref->{INSTANT}->{"Disk.$e_device.label"} = $dev_mapper{$major."_".$minor};
				}
			}
		} elsif ($device =~ m|(/dev/md\d+)(p\d+)?|) {
			if (defined($2)) {
				# it's a partition
				$dataref->{INSTANT}->{"Disk.$e_device.childof"} = $1;
				if ($dataref->{INSTANT}->{"Disk.$1.children"} == 0) {
					undef $dataref->{INSTANT}->{"Disk.$1.children"};
				}
				push @{$dataref->{INSTANT}->{"Disk.$1.children"}}, "$1$2";
			} else {
				next unless ($reads || $writes);
			}
		} else {
			# don't check out this guy if he has no writes and isn't someone we care about
			next unless ( (exists($dataref->{LONGTERM}->{"Disk.$e_device.fs.free"})) || (grep { $_ eq $device } @swaps));
		}
		$dataref->{LONGTERM}->{"Disk.$e_device.reads"}  = $reads + 0;
		$dataref->{LONGTERM}->{"Disk.$e_device.writes"} = $writes + 0;
		$dataref->{LONGTERM}->{"Disk.$e_device.read_bytes"}  = $read_bytes + 0;
		$dataref->{LONGTERM}->{"Disk.$e_device.write_bytes"} = $write_bytes + 0;
		$dataref->{INSTANT}->{"Disk.$e_device.isswap"}  = (grep { $_ eq $device } @swaps) ? 1 : 0;
		unless (exists($dataref->{INSTANT}->{"Disk.$e_device.mounted"})) {
			$dataref->{INSTANT}->{"Disk.$e_device.mounted"} = 0;
		}
		unless (exists($dataref->{INSTANT}->{"Disk.$e_device.dm"})) {
			$dataref->{INSTANT}->{"Disk.$e_device.dm"} = 0;
		}
		unless (exists($dataref->{INSTANT}->{"Disk.$e_device.childof"})) {
			$dataref->{INSTANT}->{"Disk.$e_device.childof"} = 0;
		}
		unless (exists($dataref->{INSTANT}->{"Disk.$e_device.children"})) {
			$dataref->{INSTANT}->{"Disk.$e_device.children"} = 0;
		}
	}

	return $dataref;
}

sub _get_swap_info {
	my @proc_swaps = slurp_file( $PROCFS . 'swaps' ) or do {
		$logger->info("Couldn't read ${PROCFS}swaps: $!");
		return [];
	};

	# first line of /proc/swaps is a header
	shift @proc_swaps;

	my @swaps;
	for my $line (@proc_swaps) {

		# /dev/xvdb partition 262140 122988 -1
		my ($device, $type, $size, $used ) = ( split( /\s+/, $line ) )[ 0 .. 3 ];

		# not tracking file-backed swaps
		next if $type ne 'partition';
		push @swaps, $device;
	}
	return \@swaps;
}

sub _get_mounted_info {
	my $dataref = shift;
	my %devices;
	my @mtab = slurp_file('/etc/mtab') or do {
		$logger->info("Couldn't read /etc/mtab: $!");
		return $dataref;
	};
	for my $line ( grep {m|^/|} @mtab ) {
		my ( $device, $path ) = ( $line =~ m|^(\S+)\s+(\S+)| );
		next unless $device && $path;

		if ( $device =~ m|^/dev/mapper| ) {
			my $linkpath = readlink($device);
			if ($linkpath) {
				$device = abs_path("/dev/mapper/$linkpath");
			}
			else {
				my $rdev=(stat($device))[6];
				my $minor_m = ($rdev & 037774000377) >> 0000000;
				$device = "/dev/dm-$minor_m";
			}
		}

		if ($device =~ m|/dev/disk/by-uuid/[0-9a-f-]+|) {
			$device = '/dev' . abs_path( readlink($device) );
		}

		if ($device eq '/dev/root') {
			my $root_dev = slurp_file($PROCFS . 'cmdline');
			($device) = ($root_dev =~ m|root=(\S+)|);
			if ($device =~ /UUID=([0-9a-f-]*)/) {
				$device = '/dev' . abs_path (readlink("/dev/disk/by-uuid/$1"));
			}
		}

		my ( $type, $bsize, $blocks, $bfree, $bavail, $files, $ffree )
			= _statfs($path);

		(my $e_device = $device) =~ s/\./\\\./g;
		$dataref->{LONGTERM}->{"Disk.$e_device.fs.free"}   = $bfree * $bsize if (defined($bfree) && defined($bsize));
		$dataref->{LONGTERM}->{"Disk.$e_device.fs.total"}  = $bsize * $blocks if (defined($bsize) && defined($blocks));
		$dataref->{LONGTERM}->{"Disk.$e_device.fs.ifree"}  = $ffree if (defined($ffree));
		$dataref->{LONGTERM}->{"Disk.$e_device.fs.itotal"} = $files if (defined($files));
		$dataref->{INSTANT}->{"Disk.$e_device.fs.path"}    = $path if (defined($path));
		$dataref->{INSTANT}->{"Disk.$e_device.mounted"}    = 1;
	}
	return $dataref;
}

sub _statfs {
	my $path = shift or do{
		$logger->info("_statfs no path provided");
		return ();
	};
	my $fmt = '\0' x 512;
	syscall( &SYS_statfs, $path, $fmt ) == 0 or do {
		$logger->info("Couldn't call statfs syscall: $!");
		return ();
	};

	# unsigned long vs unsigned quad on 32 vs 64 bit boxes
	if ( !defined($Config{use64bitall}) ) {
		return unpack 'L7', $fmt;
	}
	elsif ( defined($Config{use64bitall}) ) {
		return unpack 'Q7', $fmt;
	}
	else {
		$logger->info('Unable to determine architecture');
		return ();
	}
}

1;
