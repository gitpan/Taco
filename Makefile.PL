use ExtUtils::MakeMaker;
use strict;

# The following parameters are used to test Taco with a real Apache 
# server.  See also the INSTALL document for more info.

# Change this to the path to a mod_perl-enabled Apache web server.
my $HTTPD = "/usr/local/lib/forum/taco/httpd/tacod";
#my $HTTPD = "/path/to/httpd";

# The port the server will run on
my $PORT = 8228;

# The user the server will run as
my $USER = 'http';

# The group the server will run as
my $GROUP = 'http';

##########################################################################
################ No need to change anything below here ###################
##########################################################################
WriteMakefile(
  'NAME' => 'Taco',
  'VERSION_FROM' => 'Taco.pm', # finds $VERSION
  'dist' => { COMPRESS=>"gzip", SUFFIX=>"gz" },

  'PREREQ_PM' => {  # Modules that must be installed for Taco to run
    'Tie::LLHash' => '0.02',
  },
);

package MY;

sub test {
	# MakeMaker will use this to write the testing portion of the Makefile.
	# It's necessary to do this because we're starting up a server.
	
	my $dir = `pwd`;
	chomp $dir;

	my $out .= <<EOF;

test_pre_init:
	\$(FULLPERL) t/httpd/create_conf.pl $PORT $USER $GROUP $dir
	\$(FULLPERL) t/httpd/create_reg.pl $dir

kill_httpd:
	\$(RM_F) t/httpd/httpd.lock.*
	kill `cat t/httpd/httpd.pid`
	\$(RM_F) t/httpd/httpd.pid
	\$(RM_F) t/httpd/error_log

# I'm trying to make it so that you can do "make test SAVE_ERRORS=1"
# and then t/httpd/error_log won't be removed, but can't figure it out =(
#
#try_kill:
#	if ( "\$(SAVE_ERRORS)" ) then 
#	echo "Saving t/httpd/error_log" 
#	else 
#	\$(RM_F) t/httpd/error_log
#	endif

start_httpd: pure_all test_pre_init
	\@echo will write error_log to t/httpd/error_log
	\@echo "letting apache warm up..."
	$HTTPD -f $dir/t/httpd/httpd.conf -d $dir/t
	\@echo httpd listening on port $PORT

rehttpd:   kill_httpd start_httpd

run_tests:
	\$(FULLPERL) t/TEST.pl $PORT

test:	pure_all start_httpd run_tests kill_httpd

EOF

	return $out;
}

# We don't want to overwrite the real ServiceRegistry file, so 
# let's remove our copy right before installation.
sub install {
	my $inherited = shift->SUPER::install(@_);
	$inherited =~ s/^install ::/install :: taco_clean/m;
	my $file = 'blib/lib/Taco/ServiceRegistry.pm';

	return <<EOF;

taco_clean:
	test ! \\( -f $file \\) || rm -f $file

$inherited
EOF
}
