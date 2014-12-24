package Linode::Longview::DataGetter::SysInfo;

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

use Sys::Hostname;

use Linode::Longview::Util ':SYSINFO';
use Linux::Distribution qw(distribution_name distribution_version);
use POSIX 'uname';

our $DEPENDENCIES = [];

sub get {
	my (undef, $dataref) = @_;
	$logger->trace('Collecting SysInfo');

	$dataref->{INSTANT}->{'SysInfo.os.dist'}			= 'unknown';
	$dataref->{INSTANT}->{'SysInfo.os.distversion'} 	= 'unknown';
	if ( my $distro = distribution_name() ) {
		$dataref->{INSTANT}->{'SysInfo.os.dist'} 		= ucfirst($distro);
		$dataref->{INSTANT}->{'SysInfo.os.distversion'} = distribution_version();
	}

	$dataref->{INSTANT}->{'SysInfo.client'} = $VERSION;

	my ( $sysname, undef, $release, $version, $machine ) = uname();
	$dataref->{INSTANT}->{'SysInfo.kernel'}   = "$sysname $release";
	$dataref->{INSTANT}->{'SysInfo.type'}     = detect_system();
	$dataref->{INSTANT}->{'SysInfo.arch'}     = $ARCH;
	$dataref->{INSTANT}->{'SysInfo.hostname'} = hostname;

	my @cpu_info = slurp_file( $PROCFS . 'cpuinfo' )
		or do {
			$logger->info("Couldn't read ${PROCFS}cpuinfo: $!");
			return $dataref;
	};

	my $cores = grep {/^processor/} @cpu_info;
	# There's always at least 1 core
	$dataref->{INSTANT}->{'SysInfo.cpu.cores'} = $cores || 1;
	#<<<
	($dataref->{INSTANT}->{'SysInfo.cpu.type'} =
		(map { /^(?:model name|Processor)\s+:(.*)$/; $1 || ()} @cpu_info)[0])
		=~ s/^\s+//;
	#>>>
	$dataref->{INSTANT}->{'SysInfo.cpu.type'} =~ s/\s{2,}/ /g;
	$dataref->{INSTANT}->{Uptime} =
		( split( /\s+/, slurp_file( $PROCFS . 'uptime' ) ) )[0] or
		$logger->info("Couldn't check ${PROCFS}uptime: $!");

	$dataref->{INSTANT}->{Uptime} = $dataref->{INSTANT}->{Uptime} +0;

	return $dataref;
}

1;
