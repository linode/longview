package Linode::Longview::DataGetter::Packages::APT;

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

our $DEPENDENCIES = ['Processes.pm'];

our $next_run;
our $cache_touch_dt;

sub get {
	my ( undef, $dataref ) = @_;

	$logger->trace('Entering APT module');

	if(check_running($dataref)){
		$logger->debug('Another instance of apt-get is already running, skip package this pass');
		$dataref->{INSTANT}->{Packages} = [];
		return $dataref;
	}

	if(should_update()){
		$logger->trace('Running apt-get update before reporting packages');
		`apt-get -q update 2>/dev/null`;
	}

	my $new_touch_dt = (stat('/var/cache/apt/pkgcache.bin'))[9];

	return $dataref if (defined($cache_touch_dt) && ($new_touch_dt == $cache_touch_dt));
	$cache_touch_dt = $new_touch_dt;

	$dataref->{INSTANT}->{Packages} = [];

	my $held = 1;

	if (open(APT, "echo n | apt-get -q -V upgrade 2>&1 |")) {
		while (my $line = <APT>) {
			chomp($line);
			$held = 0 if ($line =~ m/^The following packages will be upgraded:/);
			if ($line =~ m/^\s+(\S+)\s+\((\S+)\s+=>\s+(\S+)\)/) {
				my $update = {};
				$update->{name} = $1;
				$update->{current} = $2;
				$update->{new} = $3;
				$update->{held} = $held;
				push @{$dataref->{INSTANT}->{Packages}}, $update;
			}
		}
		close(APT);
	}
	return $dataref;
}

sub should_update {
	return 0 if((defined $next_run) && ($next_run > time));
	$next_run = time + 86400; #Only actually hit the mirrors once every 24 hours.
	return 1;
}

sub check_running {
	my $dataref = shift;
	return grep(m/Processes\.apt(?:-get|itude)/,keys %{$dataref->{LONGTERM}});
}

1;
