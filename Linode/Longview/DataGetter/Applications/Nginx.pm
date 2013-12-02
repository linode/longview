package Linode::Longview::DataGetter::Applications::Nginx;

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

use Linode::Longview::Util qw(:APPLICATIONS get_UA);

our $DEPENDENCIES = ['Processes.pm'];
our $SIGNATURES = ['nginx'];

my $default_location    = 'http://127.0.0.1/nginx_status';
my $determined_location = undef;
my $namespace           = 'Applications.Nginx.';

sub get {
	my ( undef, $dataref ) = @_;

	my $config_file = get_config_file_name();
	return unless application_preflight( $dataref, $SIGNATURES, $config_file );

	$logger->trace('Collecting Nginx information');

	unless ($determined_location) {
		my $location = get_config_data($config_file);
		unless ( $location->{location} ) {
			$logger->warn(
				"Unable to find a location for the Nginx status page, defaulting to $default_location"
			);
			$determined_location = $default_location;
		}
		else {
			$determined_location = $location->{location};
		}
	}
	my $ua  = get_UA();

	# temporarily skip checks for self-signed certs
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
	my $res = $ua->get($determined_location);
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 1;

	unless ( $res->is_success ) {
		return application_error(
			$dataref,
			$namespace,
			"Unable to access server status page ($determined_location) for Nginx: "
				. $res->status_line(),
			1,
		);
	}
	unless ( $res->content =~ /server accepts handled requests/ ) {
		return application_error(
			$dataref,
			$namespace,
			"The Nginx status page doesn't look right. Check $determined_location and any redirects for misconfiguration.",
			2,
		);
	}

	my $server_version = $res->header('Server');
	$dataref->{INSTANT}->{ $namespace . 'version' } = $server_version if ($server_version);
	my @output = split( /\n/, $res->decoded_content );
	( $dataref->{LONGTERM}->{ $namespace . 'active' } ) = $output[0] =~ /^Active connections: (\d+)/;

	my ( $accepted_cons, $handled_cons, $requests )  = $output[2] =~ /(\d+) (\d+) (\d+)/;
	$dataref->{LONGTERM}->{ $namespace . 'accepted_cons' } = $accepted_cons;
	$dataref->{LONGTERM}->{ $namespace . 'handled_cons' }  = $handled_cons;
	$dataref->{LONGTERM}->{ $namespace . 'requests' }      = $requests;

	my ( $reading, $writing, $waiting ) = $output[3] =~ /Reading: (\d+) Writing: (\d+) Waiting: (\d+)/;
	$dataref->{LONGTERM}->{ $namespace . 'reading' } = $reading;
	$dataref->{LONGTERM}->{ $namespace . 'writing' } = $writing;
	$dataref->{LONGTERM}->{ $namespace . 'waiting' } = $waiting;

	$dataref->{INSTANT}->{ $namespace . 'status' } = 0;
	$dataref->{INSTANT}->{ $namespace . 'status_message' } ||= '';
	return $dataref;
}

1;
