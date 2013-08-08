package Linode::Longview::DataGetter::Packages::YUM;

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

sub get {
	my (undef, $dataref) = @_;

	$logger->trace('Entering YUM module');

	my %u_pkgs = upgradable_pkgs();
	if (!%u_pkgs){
		$dataref->{INSTANT}->{Packages} = [];
		return $dataref;
	}
	my %c_pkgs = current_pkgs();
	$dataref->{INSTANT}->{Packages} = [
		map {
			{
				name => $_,
				current => $c_pkgs{$_},
				new => $u_pkgs{$_}
			}
		}
		keys %u_pkgs
	];
	return $dataref;
}

sub current_pkgs {
	# yum wraps unless we fake a tty
	my @pkg_list = qx(script -c 'yum --color=never list installed' /dev/null);
	my %pkgs;
	for my $pkg (@pkg_list) {
		if ( $pkg =~ m/^(.*?)\s+(.*?)\s+@(.*)$/ ) {
			$pkgs{$1} = $2;
		}
	}
	return %pkgs;
}

sub upgradable_pkgs {
	my @pkg_list = qx(yum check-update);
	my %pkgs;
	for my $pkg (@pkg_list) {
		if ( $pkg =~ m/^(\S+\.\S+)\s+(\S+)\s+\S+$/ ) {
			$pkgs{$1} = $2;
		}
	}
	return %pkgs;
}

1;
