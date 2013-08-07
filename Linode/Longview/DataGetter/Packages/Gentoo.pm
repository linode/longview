package Linode::Longview::DataGetter::Packages::Gentoo;

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
use 5.010;
use feature 'state';

use Linode::Longview::Util;

sub get {
	my ( undef, $dataref ) = @_;
	state @pkgs;

	$logger->trace('Entering Gentoo module');

	if(should_update()){
		@pkgs = qx(VERSION='<version>,' eix -u '-*' --format '<category>/<name> <installedversions:VERSION> <bestslotupgradeversions:VERSION>\n');
	}

	$dataref->{INSTANT}->{Packages} = [
		map {
			my ($name, $current, $new) = $_ =~ /^([^ ]+) (.+?), (.+?),$/;
			{
				name    => $name,
				current => join(', ', split(/,/, $current)),
				new     => join(', ', split(/,/, $new))
			}
		} @pkgs
	];
	return $dataref;
}

sub should_update {
	state $next_run;
	return 0 if((defined $next_run) && ($next_run > time));
	$next_run = time + 1800; # Checking updates is expensive; only do it every 30 minutes
	return 1;
}

1;