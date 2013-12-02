package Linode::Longview::DataGetter::Applications::MySQL;

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

use DBI;
use Linode::Longview::Util qw(:APPLICATIONS slurp_file);

our $DEPENDENCIES = ['Processes.pm'];
our $SIGNATURES = ['mysqld'];
my $namespace  = 'Applications.MySQL.';

sub get {
	my ( undef, $dataref ) = @_;

	my $config_file = get_config_file_name();
	return unless application_preflight( $dataref, $SIGNATURES, $config_file );

	$logger->trace('Collecting MySQL information');

	my $creds = get_config_data($config_file);
	unless ( exists( $creds->{username} ) && exists( $creds->{password} ) ) {

		# try to use the debian maint user
		if ( -e '/etc/mysql/debian.cnf' ) {
			$creds->{username} = 'debian-sys-maint';
			for my $line ( slurp_file('/etc/mysql/debian.cnf') ) {
				if ( $line =~ /^password\s+=\s+(.*)$/ ) {
					$creds->{password} = $1;
					last;
				}
			}
		}
		unless ( $creds->{username} && $creds->{password} ) {
			return application_error( $dataref, $namespace,
				'Unable to connect to the database, no credentials found',
				1 );
		}
	}

	my $dbh = DBI->connect_cached( "DBI:mysql:host=localhost;", $creds->{username}, $creds->{password} ) or do {
		return application_error( $dataref, $namespace,
			'Unable to connect to the database: ' . $DBI::errstr,
			2 );
	};

	my $sth = $dbh->prepare(q{
		SHOW /*!50002 GLOBAL */ STATUS  WHERE Variable_name IN (
			"Com_select", "Com_insert", "Com_update", "Com_delete",
			"slow_queries",
			"Bytes_sent", "Bytes_received",
			"Connections", "Max_used_connections", "Aborted_Connects", "Aborted_Clients",
			"Qcache_queries_in_cache", "Qcache_hits", "Qcache_inserts", "Qcache_not_cached", "Qcache_lowmem_prunes"
		)
	});
	$sth->execute() or do {
		return application_error( $dataref, $namespace,
			'Unable to collect MySQL status information: ' . $sth->errstr,
			3 );
	};
	while ( my ( $name, $value ) = $sth->fetchrow_array() ) {
		if ( ( $name eq 'Qcache_queries_in_cache' ) || ( $name eq 'Max_used_connections' ) ) {
			$dataref->{INSTANT}->{ $namespace . $name } = $value;
		}
		else {
			$dataref->{LONGTERM}->{ $namespace . $name } = $value;
		}
	}

	$sth = $dbh->prepare(q{
		SHOW /*!50002 GLOBAL */ VARIABLES LIKE "version"
	});
	$sth->execute() or do {
		return application_error( $dataref, $namespace,
			'Unable to collect MySQL status information: ' . $sth->errstr,
			3 );
	};
	my ( undef, $version ) = $sth->fetchrow_array();
	$dataref->{INSTANT}->{ $namespace . 'version' } = $version;
	$dataref->{INSTANT}->{ $namespace . 'status' }  = 0;
	$dataref->{INSTANT}->{ $namespace . 'status_message' } ||= '';
	return $dataref;
}

1;
