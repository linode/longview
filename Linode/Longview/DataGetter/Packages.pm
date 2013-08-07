package Linode::Longview::DataGetter::Packages;

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

use Linode::Longview::Util;
require $_ for glob('/opt/linode/longview/Linode/Longview/DataGetter/Packages/*.pm');

sub get {
	my (undef, $dataref) = @_;
	$logger->trace('Collecting Package information');

	return "Linode::Longview::DataGetter::Packages::@{[determine_pkg_tool($dataref)]}"->get($dataref);
}

sub determine_pkg_tool {
	my $dataref = shift;
	my $dist = $dataref->{INSTANT}->{'SysInfo.os.dist'};
	return 'APT' if ( $dist =~ /debian/i || $dist =~ /ubuntu/i );
	return 'YUM' if ( $dist =~ /centos/i || $dist =~ /fedora/i );
	return 'Gentoo' if ( $dist =~ /gentoo/i );
	return 'unknown';
}

1;
