package Linode::Longview::DataGetter::Network;

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

	$logger->trace('Collecting network traffic info');

	my @data = slurp_file( $PROCFS . 'net/dev' ) or do {
		$logger->info("Couldn't read ${PROCFS}net/dev: $!");
		return $dataref;
	};

	for my $line (@data) {
		next unless $line =~ /^\s*.*?:/;
		$line =~ s/^\s*//;
		my ( $dev, $rx_bytes, $tx_bytes ) = ($line =~ /^\s*?(\S*?):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/);
		next if ( $rx_bytes == 0 && $tx_bytes == 0 );
		$dev =~ s/:$//;
		$dev =~ s/\./\\\./g;

		$dataref->{LONGTERM}->{"Network.Interface.$dev.rx_bytes"} = $rx_bytes + 0;
		$dataref->{LONGTERM}->{"Network.Interface.$dev.tx_bytes"} = $tx_bytes + 0;
	}
	$dataref->{INSTANT}->{'Network.mac_addr'} = slurp_file('/sys/class/net/eth0/address');
	return $dataref;
}

1;

