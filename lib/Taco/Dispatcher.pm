#!/usr/bin/perl

use strict;
package Taco::Dispatcher;
use Exporter;
use vars qw(@ISA @EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(service_info current_service);

my %MODULE_NAMES;
my %MODULES;
my %MODS_SEEN;
my $SERVICE;

sub set_modules {
	my $service = shift || $SERVICE;

	$MODULES{$service} = [];

	foreach (@_) {
		unless (exists $MODS_SEEN{$_}) {
			# Create a new module object and put a reference to it in %MODULES
			$MODS_SEEN{$_} = new $_;
			die "Can't create module '$_'" unless $MODS_SEEN{$_};
		}
		push @{ $MODULE_NAMES{$service} }, $_;
		push @{ $MODULES{$service} }, $MODS_SEEN{$_};
	}
}

sub init_modules {
	foreach my $service (keys %MODULES) {
		my @mods = &get_modules($service);
		foreach my $mod (@mods) {
			$mod->init($service);
		}
	}
}

sub get_modules {
	my $service = shift || $SERVICE;
	die "No service '$service' installed" unless exists $MODULES{$service};
	return @{ $MODULES{$service} };
}

sub get_module_names {
	my $service = shift || $SERVICE;
	die "No service '$service' installed" unless exists $MODULE_NAMES{$service};
	return @{ $MODULE_NAMES{$service} };
}

sub name2module {
	my $name = shift;
	unless (exists $MODS_SEEN{$name}) {
		warn "No module '$name' active";
		return;
	}
	return $MODS_SEEN{$name};
}

sub current_service {
	# This is probably incomplete.  We probably have to make sure we 
	# have the correct configuration information read in.  Or perhaps
	# all configuration info is read upon startup.

	if (@_) {
		$SERVICE = shift();
		die "No such service '$SERVICE'" unless exists $Taco::Services::registry{$SERVICE};
		$G::params->set_arg('top', service => $SERVICE);
		Taco::Template->set_path( @{$Taco::Services::registry{$SERVICE}{'TemplatePath'}} );
	}
	return $SERVICE;
}

sub services {
	return keys %Taco::Services::registry;
}

sub service_info {
	my $attr = shift;
	my $service = shift() || $SERVICE;

	unless (exists $Taco::Services::registry{$service}) {
		warn "No such service '$service'";
		return;
	}
	return $Taco::Services::registry{$service}{$attr};
}

sub chunk_variable {
	# returns hash {type=>'$', name=>'whatever'}

	return {
		type=>shift(),
		name=>&Taco::Template::interpret(shift()),
	};
}

sub chunk_function {
	my $type = shift;
	local $_ = shift;  # the text of the tag, like "func(arg1=val1 arg2=val2)"
	my ($name, $args, @args);

	if ( /^([\w:]+) \s* \(  (\"?)  (.*)  \2  \)  /sx ) {  # Name with parentheses, optional
		($name, $args) = ($1, $3);                         # quotes, and optional arguments

	} elsif ( /^([\w:]+) \s+  (.*)  /sx ) {      # Name with whitespace, no parentheses, no 
		($name, $args) = ($1, $2);                # quotes, and optional arguments
		
	} elsif ( /^([\w:]+)/ ) {     # Name only
		$name = $1;
	} else {
		die("Can't understand function call $_");
	}
	
	# Delete whitespace
	$args =~ s/^\s+//;
	$args =~ s/\s+$//;

	my ($open, $close) = &Taco::Template::delimiters();

	while ($args =~ m/
        ([^\=]*)=                                 # The key, followed by =
        (?:
          '([^\'\\]*  (?: \\.[^\'\\]* )* )'       # Single-quoted string, with possible whitespace inside
         |
          "([^\"\\]*  (?: \\.[^\"\\]* )* )"       # Double-quoted string, with possible whitespace inside
         |
          ( \Q$open\E .*? \Q$close\E )            # Stuff surrounded by 1 pair of delimiters
         |
          (\S*)                                   # Anything else, without whitespace
        )\s*                                      # Finally, chop of trailing whitespace
      /gx) {
		my ($key, $val) = ($1, $+);
		push(@args, &Taco::Template::interpret($key), &Taco::Template::interpret($val));
	}

	return {
		type=>$type,
		name=>$name,
		args=>\@args,
	}; 
}

sub dispatch {
	# Step through the modules for this service.  Ask whether they'll do
	# this type of tag.  If so, let them do it.
	
	my $chunk = shift;
	my $debug = 0;

	# Did they ask for a certain module?  If so, just use it.
	my @modules = $chunk->{name} =~ s/^((\w+)(::\w+)*)::// ?
		(&name2module($1)) :
		&get_modules();
	warn "Current service is " . &current_service() if $debug;
	warn "Modules are (@modules)" if $debug;
	
	foreach (@modules) {
		if ( $_->has_hook($chunk) ) {
			return $_->do_hook($chunk);
		}
	}
	
	# Nothing found
	die ("Can't find function &$chunk->{name}") if ($chunk->{'type'} eq '&');
	return;
}

1;


__END__

=head1 NAME

Taco::Dispatcher.pm - Dispatches functionality in templates to modules

=head1 SYNOPSIS

This module forms the connection between services and modules.  It
keeps track of which modules each service uses, and when any [[tag]]
needs to be evaluated, Taco::Dispatcher decides which module to hand
it off to.

This module also contains "chunker" functions that Taco::Template uses
to parse the syntax of templates.  

=head1 DESCRIPTION

=over 4

=item * &chunk_function( char, $text )

Parses $text and returns a data structure in the following form.

 {
  type=>char, 
  name=>function_name,
  args=>[arg1=>val1, arg2=>val2, ...],
 }

=item * &chunk_variable( char, $text )

Parses $text and returns a data structure of the form C<{type=E<gt>char, name=E<gt>variable_name}>.
This is a simple process, since most of the time $text will not need any parsing,
and will just be inserted into the variable_name slot.

=item * &dispatch( chunk )

Takes one argument, which is a template chunk like one created by C<&chunk_whatever>.
Searches the various modules for the current service, looking for a module that claims to
handle this chunk.  If it finds one, it lets that module handle it.


=item * &set_modules( service, mod1, mod2, ... )

Each service has a list of modules that it uses.  You use the C<set_modules> function to
set this list.  It will use Perl's @INC to look for the modules, so if you want to keep
some modules in a non-standard location, do "use lib '/whatever/modules';".

=item * &init_modules()

When Taco is fired up, it will read the Taco::ServiceRegistry.pm file that contains 
definitions of the various Taco services.  After this file is read and all the services'
modules have been created, Taco will call each module's init($service) method for 
each service that uses that module.

=item * &get_modules( service )

Returns a list of references to modules that this service uses.  If service is omitted, 
it defaults to the currently active service.

See also C<get_module_names>.

=item * &get_module_names( service )

Returns a list of the names of the modules that this service uses.  If service is 
omitted, it defaults to the currently active service.

See also C<get_modules>.

=item * &name2module( mod_name )

Given a module name, returns a reference to the module object of that name.  If no
module with the given name is currently loaded, the undefined value will be returned
and a warning will be printed to STDERR.

=item * &current_service( service_name )

Get or set the currently active service.  With no arguments, this function just returns
the name of the active service.  Given the name of a service, that service will be
made the currently active service.

=item * &services()

Returns a list of all the names of services in Taco::ServiceRegistry.pm.

=item * &service_info( attribute, service )

Looks up an attribute in Taco::ServiceRegistry.pm.  If omitted, the service
will default to the currently active service.

=back

=head1 AUTHOR

Ken Williams (ken@forum.swarthmore.edu)

Copyright (c) 1998 Swarthmore College. All rights reserved.

=cut
