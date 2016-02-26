#!/usr/bin/env perl

use v5.18;
use strict;
use warnings;

use FindBin qw($Bin);
use File::Glob ':bsd_glob';
use Getopt::Long;

my $path = "$Bin/../var/";
my $DEBUG;
my $expiration = 30;
my $period = 10;
my $global_destination = 'self';

GetOptions( 'dest=s' => \$global_destination , 'p=i' => \$period, 'd'=>\$DEBUG , 'path=s' => \$path, 't=i' => \$expiration );

# Ignore Control C
# allow exabgp to send us a SIGTERM when it is time
# $SIG{'INT'} = sub {};

# make STDOUT unbuffered
select STDOUT; $| = 1;


my %ips;

while (1) {
	my @list = bsd_glob("$path/*.txt");
	for my $filename (sort @list) {
		open(my $f,"<",$filename) or die $!;
		$DEBUG && say STDERR "opened $filename";
		my @lines = map { ($_ =~ /^\s*#/)? () : $_ } (<$f>)  ;
		chomp( @lines );	
		close $filename;
		for my $line (sort @lines) {
			next unless ( $line =~ /^\d+\.\d+\.\d+\.\d+$/);
			if( exists( $ips{ $line } ) ) {
				#do nothing, already announced	
				$DEBUG && say STDERR "$line already exists";
			}
			else {
				say "announce route $line/32 next-hop $global_destination";
				$DEBUG && say STDERR "$line announced";
			}
			$ips{ $line } = time;
			# cleanup
			
		}
	}
	# garbage collect
	for my $entry ( sort keys %ips ) {
		if ( time - $ips{ $entry } > $expiration ) {
			delete $ips{ $entry };
			say "withdraw route $entry/32 next-hop $global_destination";
			$DEBUG && say STDERR "withdrawing $entry";
		}
	}
	sleep $period
}
