package Linode::Longview::Logger;
use strict;
use warnings;

use Exporter 'import';
our @EXPORT = qw($levels);

use File::Path;
use POSIX 'strftime';
use Log::LogLite;

our $levels = {
    trace  => 6,
    debug  => 5,
    info   => 4,
    warn   => 3,
    error  => 2,
    fatal  => 1,
    logdie => 0,
};
my $LOGDIR = "/var/log/linode/";

for my $level ( keys %$levels ) {
    no strict 'refs';
    *{$level} = sub {
        my ( $self, $message ) = @_;

        my $ts = strftime( '%m/%d %T', localtime );
        $self->{logger}->write(
            sprintf( '%s %s Longview[%i] - %s', $ts, uc($level), $$, $message ),
            $levels->{$level} );
        die "$message" if $level eq 'logdie';
    };
}

sub new {
    my ( $class, $level ) = @_;
    my $self = {};

    mkpath($LOGDIR) unless (-d $LOGDIR);
    $self->{logger}
        = Log::LogLite->new( $LOGDIR . 'longview.log', $level )
        or die "Couldn't create logger object: $!";
    $self->{logger}->template("<message>\n");

    return bless $self, $class;
}

sub level {
	my ( $self, $level ) = @_;
	$self->{logger}->level($level);
}

1;
