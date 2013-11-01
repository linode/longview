package Linode::Longview::DataGetter::CPU;

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
use Linode::Longview::Util ':BASIC';

our $DEPENDENCIES = [];

sub get {
	my (undef, $dataref) = @_;

	$logger->trace('Collecting CPU info');

	my $ts = time;
	my @stat_file = slurp_file( $PROCFS . 'stat' ) or do{
		$logger->info("Couldn't check ${PROCFS}stat: $!");
		return $dataref;
	};
	shift @stat_file;    #first line is combined, pitch it
	for my $line (@stat_file) {
		last unless $line =~ m/^(cpu\d+)\s+/;
		my ( $user, $nice, $system, $idle, $wait )
			= ( split /\s+/, $line )[ 1 .. 5 ];
		$dataref->{LONGTERM}->{"CPU.$1.user"} = $user + $nice;
		$dataref->{LONGTERM}->{"CPU.$1.system"} = $system + 0;
		$dataref->{LONGTERM}->{"CPU.$1.wait"} = $wait + 0;
	}

	my $load = ( split( /\s/, ( slurp_file( $PROCFS . 'loadavg' ) )[0], 2 ) )[0] or do {
		$logger->info("Couldn't check ${PROCFS}loadavg: $!");
		return $dataref;
	};
	$dataref->{LONGTERM}->{Load} = $load + 0;

	return $dataref;
}

1;
