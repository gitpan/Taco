#!/usr/local/bin/perl

BEGIN {
	#shutdown httpd before make aborts
	$SIG{'__DIE__'} = sub {
		return unless $_[0] =~ /^Failed/i;      # Dunno what this is for
		system "kill `cat /tmp/taco_httpd.pid`";
		warn "httpd terminated\n";
	};

	use strict;
	use LWP::UserAgent;
}

my $port = shift;

open (REQUESTS, "t/requests") or die "Can't read list of tests: $!";

my $testnum;
while (<REQUESTS>) {
	chomp;
	s/(\d+)://;
	$testnum = $1;

	my $ua = new LWP::UserAgent;
	my $req = new HTTP::Request('GET', "http://localhost:$port/$_");
	my $response = $ua->request($req);

	&test_outcome($response->content, $testnum);
}


sub test_outcome {
	my $text = shift;
	my $i = shift;
	
	my $ok = ($text eq `cat t/docs.check/$i`);
	print "not " unless $ok;
	print "ok $i\n";

	print STDERR $text if ($ENV{TEST_VERBOSE} and not $ok);
}
