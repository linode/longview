package Linode::Longview::STDERRLogger;

use strict;
use warnings;

use Linode::Longview::Util;

sub TIEHANDLE {
	my $class = shift;
	bless [], $class;
}

sub PRINT {
	my $self = shift;
	return unless defined $Linode::Longview::Util::logger;
	chomp(@_);
	$Linode::Longview::Util::logger->warn(@_);
}

sub OPEN {
	my $self = shift;
}

1;
