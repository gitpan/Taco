#!/usr/bin/perl -w

package Apache::Taco;

use strict;
use Taco;
use Taco::Init;
use LWP::UserAgent;
use Apache::Constants ':common'; # DECLINED, etc.

# This is stuff the server does upon startup.
&Taco::Init::init_services;
&Taco::Init::init_templates;


sub handler {

	$G::r = shift;
	my $filename = $G::r->filename;
	my $debug = (lc $G::r->dir_config('TacoDebug') eq 'true');

# Wrap the whole deal here in an eval to catch errors
my $result = eval {

	%ENV = $G::r->cgi_env;

	warn ("[$$]file: $filename\n") if $debug;
	&Taco::LibLib::freshen;

	&Taco::Init::make_argtable($G::r->dir_config('TacoService'), $G::r->connection->user);
	my $page_out = new Taco::Template();


	if (lc $G::r->dir_config('TacoCGI') eq 'true') {
		
		unless (-e $filename) {
			$G::r->log_error("$filename not found");
			return NOT_FOUND;
		}
		
		unless (-x $filename) {
			$G::r->log_error("Execution of $filename denied");
			return FORBIDDEN;
		}
		
		# Run the perl code in the file
		package main;
		do $filename;
		package Apache::Taco;

		die $@ if $@;
		return OK;
	}


	# Interpret the file as a template web page
	my ($notaco_host, $ssi_mod);
	if ($notaco_host = $G::r->dir_config('TacoRelayHost')) {
		my $ua = new LWP::UserAgent;
		my $req = new HTTP::Request;

		# Try getting the username and password from the user:
		my ($protected_if_zero, $remote_passwd) = $G::r->get_basic_auth_pw;
		if ($protected_if_zero == 0) {
			$req->authorization_basic($G::r->connection->user, $remote_passwd);
		}
		
		my $url = $notaco_host . $G::r->uri();
		$req->url($url);
		$req->method('GET');
	
		my $response = $ua->request($req);
		if ($response->is_success) {
			$G::r->send_http_header();

			$page_out->set_text( $response->content );
			$page_out->interpret_and_print();
		} else {
			$G::r->log_error("Couldn't fetch $url from remote server '$notaco_host'");
			print $response->error_as_HTML();
		}
		
	} elsif ($ssi_mod = $G::r->dir_config('TacoFilterMod')) {
		# Use a Perl module to parse the SSI
		my $p = $ssi_mod->new($G::r);
		$page_out->set_text( $p->output );
		$page_out->interpret_and_print();

	} else {
		# The direct method:
		$page_out->get_file( $filename );
		$page_out->output();
	}
	return OK;
}; # End of eval{}

	$G::r->log_error("$filename: $@") if $@;

	&cleanup_globals;
	&show_memory('end', $filename) if $debug;
	return $result;
}


sub show_memory {
	my $mark = shift;
	my $filename = shift;

#	my $mem = (`ps -ovsize -p $$`)[1];
#  Not cross-platform enough (no linux) =(
	warn ("[$$]Memory at $mark: <not available>");
}

sub cleanup_globals {
	# Get rid of global objects:
	%G::SHARED = ();
}

1;

__END__

=head1 NAME 

Apache::Taco.pm - mod_perl handler for Taco

=head1 SYNOPSIS

This module defines a mod_perl handler (running under the Apache web server) that
serves Taco pages.

 # In Apache's srm.conf (or similar), setup so
 # files ending in .taco get handled by Apache::Taco
 <Files ~ "\.taco$">
  SetHandler perl-script
  PerlHandler Apache::Taco
  PerlSetVar TacoRelayHost whatever.you.want/no_taco  # for SSI
 </Files>


=head1 DESCRIPTION

This module lets you serve Taco files over the World Wide Web.  It lets you write
Taco modules that take advantage of mod_perl's speed and power.

=head2 PerlSetVar parameters

When this handler runs, it takes several different parameters that can alter its
behavior.  To set any of these parameters, use the PerlSetVar command in an
appropriate Apache config file.  This may be any of httpd.conf, srm.conf, etc., or
a .htaccess file:

 PerlSetVar TacoService joes_cars

See the mod_perl documentation for more information about PerlSetVar.

=over 4

=item * TacoService <service name>

Use this to set the service that a request will run under.  See Taco::ServiceRegistry.pm
for more information about services.

=item * TacoCGI <true or false>

If set to true, Taco will interpret the file as Perl code.  The Perl code will have access
to all of Taco's internal functions.

=item * TacoRelayHost < URL prefix >

By default, Apache::Taco will just read in the file pointed to by the URL and interpret
it as a Taco template.  This prevents server-side includes, however.  If you want to 
use server-side includes, you should use either the TacoRelayHost parameter or the TacoFilterMod
parameter.

If your server is configured with the following:

  PerlSetVar TacoRelayHost http://whatever.host.edu/no_taco

and Apache::Taco gets a request at http://taco.host.edu/page.taco, it will request the URL
http://whatever.host.edu/no_taco/page.taco, and then interpret the content of that page
as a Taco template.


=item * TacoFilterMod < Perl module (class) >

If you'd rather implement SSI (or any other text processing) yourself in a Perl module,
you can use the TacoFilterMod parameter:

  PerlSetVar TacoFilterMod  MyPackage::filter

The MyPackage::filter class needs to define a new() method and an output() method, 
because it will be called like this:

    # Pass the filename and the current Apache::Request object
    my $p = MyPackage::filter->new($filename, $G::r); 
    $template->set_text( $p->output );
    $template->interpret_and_print();

It's possible that the TacoFilterMod capability can be better implemented by
using an Apache::OutputChain, but I don't know much about that yet.


=item * TacoDebug <true or false>

When this parameter is set to 'true', Apache::Taco will print a few debug statements
to Apache's error log.


=head1 SEE ALSO

Taco(3), Apache(3), mod_perl(1),
and the mod_perl web site at http://perl.apache.org/

=head1 AUTHOR

Ken Williams (ken@forum.swarthmore.edu)

Copyright (c) 1998 Swarthmore College. All rights reserved.

=cut
