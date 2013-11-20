package Linode::Longview::DataGetter::Processes;

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

use POSIX;
use Linode::Longview::Util qw(:BASIC $TICKS);

our $DEPENDENCIES = [];

use Exporter 'import';
our @EXPORT_OK = (qw(process_info process_list));

sub process_list {
	my @procs = map { s|$PROCFS||; $_ } glob "${PROCFS}[0-9]*";
	return @procs;
}

sub process_info {
	my $pid = shift;
	my %proc;

	# all or nothing, grab what we need asap
	my @proc_file  = slurp_file( $PROCFS . "$pid/status" ) or return;
	my $stat_line = slurp_file( $PROCFS . "$pid/stat" )   or return;
	my $cmd_line = slurp_file( $PROCFS . "$pid/cmdline" ) or return;
	# io stats are optional depending on kernel
	my @iosample  = slurp_file( $PROCFS . "$pid/io" ) ;

	$proc{longname} = (split("\0", $cmd_line))[0];

	for my $line (@proc_file) {
		if ( $line =~ m/^Name:\s+(.*)/ )         { $proc{name} = $1; next; }
		if ( $line =~ m/^Pid:\s+(.*)/ )          { $proc{pid}  = $1; next; }
		if ( $line =~ m/^PPid:\s+(.*)/ )         { $proc{ppid} = $1; next; }
		if ( $line =~ m/^Uid:\s+.*?\s+(.*?)\s/ ) { $proc{uid}  = $1; next; }
		if ( $line =~ m/^VmRSS:\s+(.*)\s+kB/ )   { $proc{mem}  = $1; last; }
	}

	$proc{user}  = ( getpwuid( $proc{uid} ) )[0];

	# cpu
	my ( $user_time, $system_time, $start_jiffies )
		= ( split /\s+/, $stat_line )[ 13, 14, 21 ];
	$proc{cpu} = $user_time + $system_time;
	$proc{age} = proc_age($start_jiffies);

	# io
	for my $line (@iosample) {
		if ( $line =~ m/^read_bytes:\s+(.*)/ )  { $proc{ioreadkbytes}  = $1; next; }
		if ( $line =~ m/^write_bytes:\s+(.*)/ ) { $proc{iowritekbytes} = $1; last; }
	}

	$proc{name} = $0 if $proc{pid} == $$;

	return %proc;
}

sub get {
	my (undef, $dataref) = @_;

	$logger->trace('Collecting Process information');

	my @procs = process_list();
	for my $proc (@procs) {
		my %info = process_info($proc);
		next if ( !%info );    # no such proc, it probably died while we were gathering info
		next if ( $info{ppid} == 2 );
		next if ( $info{pid} == 2 );
		$info{name} =~ s/\./\\\./g;

		$dataref->{INSTANT}->{"Processes.${info{name}}.longname"} = $info{longname};
		$dataref->{LONGTERM}->{"Processes.${info{name}}.${info{user}}.count"}++;
		$dataref->{LONGTERM}->{"Processes.${info{name}}.${info{user}}.mem"}             += $info{mem} + 0;
		$dataref->{LONGTERM}->{"Processes.${info{name}}.${info{user}}.cpu"}             += $info{cpu}           if (defined $info{cpu});
		$dataref->{LONGTERM}->{"Processes.${info{name}}.${info{user}}.ioreadkbytes"}    += $info{ioreadkbytes}  if (defined $info{ioreadkbytes});
		$dataref->{LONGTERM}->{"Processes.${info{name}}.${info{user}}.iowritekbytes"}   += $info{iowritekbytes} if (defined $info{iowritekbytes});
		$dataref->{LONGTERM}->{"Processes.${info{name}}.${info{user}}.zz_age"}           = $info{age}
			if ((!defined($dataref->{LONGTERM}->{"Processes.${info{name}}.${info{user}}.zz_age"} )) ||
				$info{age} > $dataref->{LONGTERM}->{"Processes.${info{name}}.${info{user}}.zz_age"} );
	}

	for my $key ( sort keys %{ $dataref->{LONGTERM} } ) {
		next unless $key =~ /^Processes/;
		if($key =~ /zz_age$/ ){
			delete $dataref->{LONGTERM}->{$key};
			next;
		}
		next if ($key =~ m/^Processes\.apt(?:-get|itude)/);
		my $age_key = $key;
		$age_key =~ s/[^\.]*$/zz_age/;
		delete $dataref->{LONGTERM}->{$key} if ($dataref->{LONGTERM}->{$age_key} < 60);
	}

	return $dataref;
}

sub proc_age {
	my $start_jiffies   = shift;
	my $uptime          = ( split( /\s+/, slurp_file( $PROCFS . 'uptime' ) ) )[0];
	my $current_jiffies = $uptime * $TICKS;
	return ($current_jiffies - $start_jiffies) / $TICKS;
}

1;
