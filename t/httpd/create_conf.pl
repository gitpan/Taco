my $port = shift;
my $user = shift;
my $group = shift;
my $dir = shift;

my $file = "t/httpd/httpd.conf";
open (CONF, ">$file") or die $!;
print CONF <<EOF;

#Configuration directives specific to Taco
#This file is created by the create_conf.pl script.

Port $port
User $user
Group $group
ServerName localhost
DocumentRoot $dir/t/docs

ErrorLog httpd/error_log
PidFile httpd/httpd.pid
AccessConfig httpd/access.conf
ResourceConfig httpd/srm.conf
TypesConfig /dev/null
TransferLog /dev/null
ScoreBoardFile /dev/null

AddType text/html .html

# Look for Taco in ./blib/lib
PerlModule ExtUtils::testlib

PerlModule Apache::Taco

<Files ~ "\\.taco\$">
 SetHandler perl-script
 PerlHandler Apache::Taco
 PerlSetVar TacoService test_service
</Files>

<Location /status>
 SetHandler server-status
</Location>

EOF

close CONF;

chmod 0644, $file or warn "Couldn't 'chmod 0644 $file': $!";
