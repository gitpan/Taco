#!usr/bin/perl

package Taco::Init;
use strict;
use Taco::Arg;
use Taco::Template;

sub make_argtable {
	my $service = shift;
	my $user = shift;
	my $debug = 0;

	# Construct the table
	$G::params = new Taco::ArgTable;
	$G::params->set_top_layer('top');
	$G::params->insert_layer('top', 'local_func');
	$G::params->insert_layer('top', 'my_func');
	$G::params->insert_layer('top', 'user');
	$G::params->insert_layer('top', 'set');
	$G::params->insert_layer('top', 'query');
	$G::params->insert_layer('top', 'post');
	
	# Fill the table
	&Taco::Dispatcher::current_service($service) if $service;
	$G::params->set_layer('query', Taco::ArgLayer->new_from_query_string() );
	$G::params->set_layer('post', Taco::ArgLayer->new_from_post() );

	if ($user) {
		$G::params->set_arg('top', user_id => $user);
		$G::params->set_arg('user', user => $user);
	}
	
	if ($debug) {
		warn "Argtable upon creation:";
		$G::params->show_me(1);
	}
}

sub init_services {
	# Read the ServiceRegistry.pl file, and initialize the 
	# services contained in it.

	my ($k, $v);

	while (($k, $v) = each %Taco::Services::registry) {
		&Taco::Dispatcher::set_modules( $k, @{ $v->{Modules} } );
	}
	&Taco::Dispatcher::init_modules();
}

sub init_templates {
	&Taco::Template::set_chunker( '&', \&Taco::Dispatcher::chunk_function );
	&Taco::Template::set_executor( '&', \&Taco::Dispatcher::dispatch );
	&Taco::Template::set_chunker( '$', \&Taco::Dispatcher::chunk_variable );
	&Taco::Template::set_executor( '$', \&Taco::Dispatcher::dispatch );
}



1;
