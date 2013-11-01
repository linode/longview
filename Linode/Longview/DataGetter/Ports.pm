package Linode::Longview::DataGetter::Ports;

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

our $DEPENDENCIES = ['Processes.pm'];

our $sockInfoCache = {};
our $IPTranslationCache = {};

sub get {
	my (undef, $dataref) = @_;

	$logger->trace('Collecting port information');

	my @procs = Linode::Longview::DataGetter::Processes::process_list();
	my ( %listening,    %active );
	my ( @listening_out, @active_out );

	for my $proc (@procs) {
		my %proc_data = Linode::Longview::DataGetter::Processes::process_info($proc) or next;
		my @fds = glob "${PROCFS}/${proc}/fd/*";

		for my $fd (@fds) {
			my $rl = readlink $fd;

			# if the symlink went away, the process probably did too.
			next unless $rl;
			next unless ($rl) = ( $rl =~ m/socket:\[(\d+)\]/ );

			my ( $socket_type, $sip, $sport, $rip, $rport ) = get_socket_info($rl);

			# not a network connection
			next unless $socket_type;

			$sip   = translate_IP($sip);
			$sport = hex $sport;

			# active connection
			if ( hex $rport ) {
				if ( exists( $active{ $proc_data{name} . $proc_data{user} } ) ) {
					$active{ $proc_data{name} . $proc_data{user} }{count}++;
				}
				else {
					$active{ $proc_data{name} . $proc_data{user} } = {
						name  => $proc_data{name},
						user  => $proc_data{user},
						count => 1,
					};
				}
			}
			else {
				# listening port
				$listening{ $proc_data{name}
						. $proc_data{user}
						. $socket_type
						. $sip
						. $sport } = {
					name => $proc_data{name},
					user => $proc_data{user},
					type => $socket_type,
					ip   => $sip,
					port => $sport + 0,
						}
					unless exists(
					$listening{
							  $proc_data{name}
							. $proc_data{user}
							. $socket_type
							. $sip
							. $sport
					} );
			}
		}
	}
	$sockInfoCache = {};
	push @listening_out, $listening{$_} for keys(%listening);
	push @active_out,    $active{$_}    for keys(%active);
	$dataref->{INSTANT}->{'Ports.listening'} = \@listening_out;
	$dataref->{INSTANT}->{'Ports.active'}    = \@active_out;
	return $dataref;
}

sub get_socket_info {
	my $inode = shift;
	for my $type (qw(tcp udp tcp6 udp6)) {
		unless ($sockInfoCache->{$type}) {
			my @lines = slurp_file($PROCFS . "net/$type");
			for my $line (@lines) {
				# now we've got a local addr, remote addr, and inode
				my $tmp = [(split(/\s+/, $line))[2,3,10]];

				$tmp = [
					$type,
					(split(":", $tmp->[0])),
					(split(":", $tmp->[1])),
					$tmp->[2]
				];
				next unless $tmp->[5];
				push @{$sockInfoCache->{$type}}, $tmp;
			}
		}

		for my $sock (@{$sockInfoCache->{$type}}) {
			if ( $sock->[5] eq $inode ) {
				return @$sock;
			}
		}
	}
}

sub translate_IP {
	my $raw_IP = shift;
	return $IPTranslationCache->{$raw_IP} if $IPTranslationCache->{$raw_IP};
	if ( length($raw_IP) > 8 ) {
		my @ip;
		push( @ip, reverse( unpack( 'a2' x 4, $_ ) ) )
			for ( unpack( 'a8' x 4, $raw_IP ) );
		my $v6 = join( ':', unpack( 'a4' x 8, join( '', @ip ) ) );
		$v6 =~ s/(0000:?)+/:/;
		$v6 =~ s/:0+/:/;
		$v6 =~ s/^:/::/;
		$v6 = lc $v6;
		$IPTranslationCache->{$raw_IP} = $v6;
		return $IPTranslationCache->{$raw_IP};
	}
	my $hex_IP = hex $raw_IP;
	$IPTranslationCache->{$raw_IP} = join( '.', reverse( unpack( 'C4', pack( 'N', $hex_IP ) ) ) );
	return $IPTranslationCache->{$raw_IP};
}

1;
