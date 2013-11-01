package Linode::Longview::DataGetter::Memory;

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

	$logger->trace('Collecting memory info');

	my $meminfo = slurp_file( $PROCFS . 'meminfo' ) or do {
		$logger->info("Couldn't read ${PROCFS}meminfo: $!");
		return $dataref;
	};

	# We need to "numify" these matches to make JSON::PP not-quote
	( $dataref->{LONGTERM}->{'Memory.real.free'} )    = ( $meminfo =~ /MemFree:\s+(\d+)/ )[0] + 0;
	( $dataref->{LONGTERM}->{'Memory.real.buffers'} ) = ( $meminfo =~ /Buffers:\s+(\d+)/ )[0] + 0;
	( $dataref->{LONGTERM}->{'Memory.real.cache'} )   = ( $meminfo =~ /Cached:\s+(\d+)/ )[0] + 0;
	( $dataref->{LONGTERM}->{'Memory.real.used'} )
		= ( $meminfo =~ /MemTotal:\s+(\d+)/ )[0]
		- ( $meminfo =~ /MemFree:\s+(\d+)/ )[0];
	( $dataref->{LONGTERM}->{'Memory.swap.used'} )
		= ( $meminfo =~ /SwapTotal:\s+(\d+)/ )[0]
		- ( $meminfo =~ /SwapFree:\s+(\d+)/ )[0];
	( $dataref->{LONGTERM}->{'Memory.swap.free'} ) = ( $meminfo =~ /SwapFree:\s+(\d+)/ )[0] + 0;
	return $dataref;
}

1;
