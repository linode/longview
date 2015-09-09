package Linode::Longview::DataGetter::Applications::Apache;

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
our $SIGNATURES    = [ 'apache2', 'httpd' ];

my $default_location    = 'http://127.0.0.1/server-status?auto';
my $determined_location = undef;
my @cared_about         = ( "Total Accesses", "Total kBytes", "Scoreboard" );
my $scoreboard_lookup   = {
	"_" => 'Waiting for Connection',
	"S" => 'Starting up',
	"R" => 'Reading Request',
	"W" => 'Sending Reply',
	"K" => 'Keepalive',
	"D" => 'DNS Lookup',
	"C" => 'Closing connection',
	"L" => 'Logging',
	"G" => 'Gracefully finishing',
	"I" => 'Idle cleanup of worker',

	# don't capture placeholder slots
	# "." => Open slot with no current process,
};
my $namespace = 'Applications.Apache.';

sub get {
	my ( undef, $dataref ) = @_;

	my $config_file = get_config_file_name();
	return unless application_preflight( $dataref, $SIGNATURES, $config_file );

	$logger->trace('Collecting Apache information');

	unless ($determined_location) {
		my $site_location = get_config_data($config_file);
		unless ( exists( $site_location->{location} ) ) {
			$logger->warn(
				"Unable to find the location of the Apache statistics page, defaulting to $default_location"
			);
			$determined_location = $default_location;
		}
		else {
			$determined_location = $site_location->{location};
			if ( $determined_location !~ /\?auto$/ ) {
				$determined_location .= '?auto';
				$logger->warn(
					"The location specified in $config_file should end in '?auto'. Automatically appending '?auto' for Apache checks"
				);
			}
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
			"Unable to access local server status for Apache at $determined_location: "
				. $res->status_line(),
			1
		);
	}
	unless ( $res->content =~ /Scoreboard:/ ) {
		return application_error(
			$dataref,
			$namespace,
			"The Apache status page doesn't look right. Check $determined_location and investigate any redirects for misconfiguration.",
			2
		);
	}
	my $server_version = $res->header('Server');
	$dataref->{INSTANT}->{ $namespace . 'version' } = $server_version if ($server_version);
	foreach my $line ( split( /\n/, $res->content() ) ) {
		if($line =~ /^([^:]+):\s*(\S*)/) {
			my ( $key, $value ) = ( $line =~ /^([^:]+):\s*(\S*)/ );
			next unless grep {/$key/} @cared_about;
			$dataref->{LONGTERM}->{ $namespace . $key } = $value;
		}
	}

	for my $char (split( '', $dataref->{LONGTERM}->{ $namespace . 'Scoreboard' } ) ) {
		next unless exists $scoreboard_lookup->{$char};
		$dataref->{LONGTERM}->{ $namespace . "Workers.$scoreboard_lookup->{$char}" } += 1;
	}
	for my $key ( keys(%$scoreboard_lookup) ) {
		$dataref->{LONGTERM}->{ $namespace . "Workers.$scoreboard_lookup->{$key}" } += 0;
	}
	delete $dataref->{LONGTERM}->{ $namespace . 'Scoreboard' };
	$dataref->{INSTANT}->{ $namespace . 'status' } = 0;
	$dataref->{INSTANT}->{ $namespace . 'status_message' } ||= '';
	return $dataref;
}

1;
