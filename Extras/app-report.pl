#!/usr/bin/env perl
use strict;
use warnings;

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

BEGIN {
	use Config;
	use FindBin;
	push @INC, "$FindBin::RealBin/../";
	push @INC, "$FindBin::RealBin/../lib/perl5";
	push @INC, "$FindBin::RealBin/../lib/perl5/${Config{archname}}/";
	push @INC, "$FindBin::RealBin/../usr/include";
}

use Linode::Longview::DataGetter::Applications::Apache;
use Linode::Longview::DataGetter::Applications::Nginx;
use Linode::Longview::DataGetter::Applications::MySQL;
use Linode::Longview::DataGetter::Processes qw(process_info process_list);
use Linode::Longview::Util qw(get_config_file_name get_config_data get_UA slurp_file $apikey);

use DBI;
use Socket;
use Getopt::Long;
use Term::ANSIColor;
use Tie::File;
use Fcntl 'O_RDONLY';

our $processes = {};

my $force = '';
my $module = 'ALL';
my $verbose = '';

Getopt::Long::Configure ("bundling");
GetOptions ('f|force' => \$force, 'm|module=s' => \$module, 'v|verbose' => \$verbose);

our $sys_type ="generic";
$sys_type = "debian" if -e "/etc/debian_version";
$sys_type = "redhat" if -e "/etc/redhat-release";

my $running_apps = check_running();

$apikey = "Longview Config Test";

check_apache() if $module eq "ALL" or $module eq "Apache";
check_nginx() if $module eq "ALL" or $module eq "Nginx";
check_mysql() if $module eq "ALL" or $module eq "MySQL";
print "=" x 28 . "\n";

sub check_running{
	my $sigs = {
		Apache => $Linode::Longview::DataGetter::Applications::Apache::SIGNATURES,
		Nginx => $Linode::Longview::DataGetter::Applications::Nginx::SIGNATURES,
		MySQL => $Linode::Longview::DataGetter::Applications::MySQL::SIGNATURES,
	};
	my $found = {Apache => 0, Nginx => 0, MySQL => 0};
	my @procs = process_list();
	for my $proc (@procs) {
		my %info = process_info($proc);
		next if ( !%info );    # no such proc, it probably died while we were gathering info
		next if ( $info{ppid} == 2 );
		next if ( $info{pid} == 2 );
		for my $app (keys %$sigs){
			for my $sig (@{$sigs->{$app}}){
				$found->{$app} = 1 if ($info{name} =~ /$sig$/);
				$found->{$app} = 1 if ($info{longname} =~ /$sig$/);
			}
		}
	}
	return $found;
}

sub check_apache {
	print "=" x 10 . " Apache " . "=" x 10 ."\n";
	my $conf = get_config_data(get_config_file_name("Apache"));
	$conf->{location} = "http://127.0.0.1/server-status?auto" unless defined $conf->{location};
	my $conf_port = 80;
	$conf_port = 443 if $conf->{location} =~ m|^https://|;
	my ($host, undef, $file_port) = ($conf->{location} =~ /^https?:\/\/([^:\/]+)(:(\d+))?\/.*/);
	$conf_port = $file_port if defined $file_port;

	my $ua  = get_UA();

	# temporarily skip checks for self-signed certs
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
	my $res = $ua->get($conf->{location});
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 1;
	if ( $res->is_success ) {
		if ( $res->content =~ /Scoreboard:/ ) {
			print color 'bold green';
			print "Found apache status page at configured location ($conf->{location})\n";
			print color 'reset';
			return unless $force;
		}else{
			print color 'bold yellow';
			print "Got HTTP ".$res->status_line." for $conf->{location} but the content doesn't look like a status page\n";
			print color 'reset';
		}
	}
	else{
		print color 'bold red';
		print "Got HTTP ".$res->status_line." for $conf->{location}\n";
		print color 'reset';
	}

	unless ($running_apps->{Apache}) {
		print color 'bold red';
		print "Apache does not appear to be running\n";
		print color 'reset';
	}

	my $host_ip = inet_ntoa(scalar(gethostbyname($host)));

	my $found = 0;
	my $default = 0;
	my $skip_block = 0;
	my ($vname, $conf_file, $line_number);

	my $ctl_bin = "apache2ctl";
	$ctl_bin = "apachectl" if $sys_type eq "redhat";

	open(A2C,"$ctl_bin -t -D DUMP_MODULES 2>/dev/null|") or do {
		print "Could not exec the Apache control binary ($ctl_bin)\n";
		return;
	};
	
	my @mod_list = <A2C>;
	close(A2C);

	if($?){
		print color 'bold yellow';
		print "Could not find the Apache control binary ($ctl_bin) assuming apache isn't installed\n";
		print color 'reset';
		return;
	}

	unless(grep(/^\s*status_module/,@mod_list)){
		print color 'bold red';
		print "Apache mod_status not loaded\n";
		print color 'reset';
		return unless $force;
	}

	open(A2C,"$ctl_bin -t -D DUMP_VHOSTS 2>/dev/null|") or do {
		print "Could not exec the Apache control binary ($ctl_bin)\n";
		return;
	};
	my @conf_lines = <A2C>;
	close(A2C);
	
	foreach my $line (@conf_lines) {
		print $line;
		chomp($line);
		if($line =~ /^(\S+).*NameVirtualHost$/){
			my ($addr,$port) = ($line =~ /^(.*):(\d+)\s.*$/);
			
			unless ($port == $conf_port) {
				$skip_block = 1;
				next;
			}
			unless (($host eq $addr) or ($addr eq "*")) {
				$skip_block = 1;
				next
			}
			$skip_block = 0;
		}
		
		next if $skip_block;

		if($line =~ /^\s+default/) {
			($vname, $conf_file, $line_number) = ($line =~ /^\s+default\sserver\s(.*)\s\((.*):(\d+)\)$/) unless $found;
			$default = 1;
			
		}
		elsif($line =~ /^\s+port\s+\d+\s+namevhost.*$/){
			my ($name, $file, $ln) = ($line =~ /^\s+port\s+\d+\s+namevhost\s+(.*)\s+\((.*):(\d+)\)$/);
			if($name eq $host or inet_ntoa(scalar(gethostbyname($name))) eq $host_ip){
				($vname, $conf_file, $line_number) = ($name, $file, $ln);
				$found = 1;
			}
		}
	}
	if(defined $vname){
		print "Found a likely vhost $vname in $conf_file on line $line_number";
		print " [DEFAULT]" if $default and !$found;
		print "\n";
		print_vhost($conf_file, $line_number) if $verbose;
	}
}

sub print_vhost {
	my ($file, $line_no) = @_;
	$line_no--;
	my @vhost_conf;
	tie @vhost_conf, 'Tie::File', $file, mode => O_RDONLY;
	while (($line_no < scalar(@vhost_conf)) and ($vhost_conf[$line_no] !~ m|^\s*</VirtualHost>|)) {
		print $vhost_conf[$line_no++] . "\n";
	}
	print $vhost_conf[$line_no] . "\n";
	untie @vhost_conf;
}

sub check_mysql {
	print "=" x 10 . " MySQL " . "=" x 11 ."\n";

	my $conf = get_config_data(get_config_file_name("MySQL"));

	my $connection_string = "DBI:mysql:host=localhost;";

	my $socket_error = 0;
	my $spath_from_error;

	unless ($running_apps->{MySQL}) {
		print color 'bold red';
		print "MySQL does not appear to be running\n";
		print color 'reset';
		return unless $force;
	}

	if ( exists( $conf->{username} ) && exists( $conf->{password} ) ) {
		my $success = 1;
		my $dbh = DBI->connect_cached($connection_string, $conf->{username}, $conf->{password},{PrintError => 0,PrintWarn => 0}) or do {
			$success = 0;
		};
		if($success) {
			print color 'bold green';
			print "Connected to mysql with user '$conf->{username}' and the password supplied in /etc/linode/longview.d/MySQL.conf\n";
			print color 'reset';
			return unless $force;
		}
		else {
			print color 'bold yellow';
			print "Could not connect to mysql with user '$conf->{username}' and the password supplied in /etc/linode/longview.d/MySQL.conf\n";
			print $DBI::errstr . "\n" if $verbose;
			print color 'reset';
			if($DBI::errstr =~ /Can't connect to local MySQL server through socket/){
				$socket_error = 1;
				($spath_from_error) = ($DBI::errstr =~ /^Can't connect to local MySQL server through socket '(.*)'/);
			}
		}
	}
	else{
		print color 'bold yellow';
		print "No credentials found in /etc/linode/longview.d/MySQL.conf\n";
		print color 'reset';
	}

	if( $sys_type eq "debian" && -e '/etc/mysql/debian.cnf'){
		my $password;
		for my $line ( slurp_file('/etc/mysql/debian.cnf') ) {
			if ( $line =~ /^password\s+=\s+(.*)$/ ) {
				$password = $1;
				last;
			}
		}
		unless (defined $password) {
			print color 'bold yellow';
			print "Could not find user credentials in /etc/mysql/debian.cnf\n";
			print color 'reset';
		}else{
			my $success = 1;
			my $dbh = DBI->connect_cached($connection_string, 'debian-sys-maint', $password,{PrintError => 0,PrintWarn => 0}) or do {
				$success = 0;
			};
			if($success) {
				print color 'bold green';
				print "Connected to mysql with user 'debian-sys-maint'\n";
				print color 'reset';
				return unless $force;
			}
			else {
				print color 'bold yellow';
				print "Could not connect to mysql as user 'debian-sys-maint' with the password set in /etc/mysql/debian.cnf\n";
				print $DBI::errstr . "\n" if $verbose;
				print color 'reset';
				if($DBI::errstr =~ /Can't connect to local MySQL server through socket/){
					$socket_error = 1;
					($spath_from_error) = ($DBI::errstr =~ /^Can't connect to local MySQL server through socket '(.*)'/);
				}
			}
		}
	}
	if($socket_error){
		print "Could not connect due to socket error.\n";
		my $conf_file = "/etc/my.cnf";
		$conf_file = "/etc/mysql/my.cnf" if $sys_type eq "debian";
		my $spath_from_conf = mysql_socket_path_from_config($conf_file);
		print "Found socket ";
		print color 'bold';
		print $spath_from_conf;
		print color 'reset';
		print " in $conf_file\n";
		unless (-S $spath_from_conf){
			print color 'bold red';
			print "Socket $spath_from_conf does not exist\n";
			print color 'reset';
		}
		print "Client attempted to connect using socket ";
		print color 'bold';
		print "$spath_from_error\n";
		print color 'reset';
		unless($spath_from_conf eq $spath_from_error){
			print color 'bold red';
			print "Client appears to be using the wrong socket path\n";
			print color 'reset';
		}
	}
}


sub mysql_socket_path_from_config {
	my $file = shift;

	my @conf_lines = slurp_file($file);

	my ($section, $socket_path) = ('',undef);

	foreach my $line (@conf_lines) {
		chomp($line);
		if($line =~ /^\s*\[\S+\]/) {
			($section) = ($line =~ /^\s*\[(\S+)\]/);
		}
		next unless $section eq "mysqld";
		if($line =~ /^\s*socket\s*=\s*\S+/){
			($socket_path) = ($line =~ /^\s*socket\s*=\s*(\S+)/);
		}
	}
	return $socket_path;
}

sub check_nginx {
	print "=" x 10 . " Nginx " . "=" x 11 ."\n";
	my $conf = get_config_data(get_config_file_name("Nginx"));
	$conf->{location} = 'http://127.0.0.1/nginx_status' unless defined $conf->{location};
	my $conf_port = 80;
	$conf_port = 443 if $conf->{location} =~ m|^https://|;
	my ($host, undef, $file_port) = ($conf->{location} =~ /^https?:\/\/([^:\/]+)(:(\d+))?\/.*/);
	$conf_port = $file_port if defined $file_port;

	my $ua  = get_UA();

	# temporarily skip checks for self-signed certs
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
	my $res = $ua->get($conf->{location});
	$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 1;
	if ( $res->is_success ) {
		if ( $res->content =~ /server accepts handled requests/ ) {
			print color 'bold green';
			print "Found nginx status page at configured location ($conf->{location})\n";
			print color 'reset';
			return unless $force;
		}else{
			print color 'bold yellow';
			print "Got HTTP ".$res->status_line." for $conf->{location} but the content doesn't look like a status page\n";
			print color 'reset';
		}
	}
	else{
		print color 'bold red';
		print "Got HTTP ".$res->status_line." for $conf->{location}\n";
		print color 'reset';
	}

	unless ($running_apps->{Nginx}) {
		print color 'bold red';
		print "Nginx does not appear to be running\n";
		print color 'reset';
	}

	open(NXV,"nginx -V 2>&1 |") or do {
		print "Could not exec nginx\n";
		return;
	};
	
	my @conf_lines = <NXV>;
	close(NXV);
	if($?){
		print color 'bold yellow';
		print "Could not find nginx assuming it isn't installed\n";
		print color 'reset';
		return;
	}
	my $conf_line = (grep(m/^configure arguments:/,@conf_lines))[0];
	$conf_line =~ s/^configure arguments://;
	my @config_opts = split(' ', $conf_line);
	unless(grep(/--with-http_stub_status_module/,@config_opts)){
		print "Installed version of Nginx does not include status stub\n";
		return;
	}
	else{
		print "Nginx status stub available\n";
	}
	my $prefix = (grep(m/^--prefix=/,@config_opts))[0];
	$prefix =~ s/^--prefix=//;
	my $conf_path = (grep(m/^--conf-path=/,@config_opts))[0];
	$conf_path =~ s/^--conf-path=//;
	print "Prefix: $prefix\n";
	print "Base Config File: $conf_path\n";
	my (@pending, @confs);
	push @pending, $conf_path;
	while(@pending){
		push @pending, nginx_get_includes($pending[0]);
		push @confs, shift @pending;
	}
	print "All Config Files:\n";
	print "\t$_\n" for (@confs);
	nginx_find_status($_) for (@confs);
}

sub nginx_get_includes {
	my $file = shift;
	my @conf_lines = slurp_file($file);
	return () unless @conf_lines;
	my @res;
	for my $child (grep(/^\s*include\s+/,@conf_lines)){
		$child =~ s/^\s*include\s+//;
		$child =~ s/;$//;
		push @res, glob($child);
	}
	return @res;
}

sub nginx_find_status {
	my $file = shift;
	my @conf_lines = slurp_file($file);
	return () unless @conf_lines;
	my @res = grep { $conf_lines[$_-1] =~ /^\s*stub_status on;/ } 1..$#conf_lines+1;
	if (@res){
		print "Found what looks like a status stub handler in $file on line " .join(', ',@res)."\n";
		print `egrep -n -C5 '^\\s*stub_status on;' $file` if $verbose;
	}
}

