#!/usr/bin/perl

use strict;
package Taco::Module;

my $debug = 0;


sub new {
	my $package = shift;
	
	my $self = {
		'hook_testers' => {
			'$' => 'has_variable',
			'&' => 'has_function',
		},
	
		'hook_doers' => {
			'$' => 'find_value',
			'&' => 'run_function',
		},

		'functions' => {},     # Derived classes declare functions here
		
		'module' => {},        # Space for derived modules to mess with
	};
	
	bless($self, $package);
	$self->declare('set_service', 'name');
	
	return $self;
}

sub init {
	# This routine is run at server startup, right after all the modules
	# are created.  See Taco::Dispatcher.pm.
	#
	# We create default values for the "ServiceDir" and "TemplatePath"
	# attributes in the ServiceRegistry.
	
	my $self = shift;
	my $service = shift;

	my $reg = \%Taco::Services::registry;
	$reg->{$service}{'ServiceDir'}   ||= "$Taco::Services::root_dir/$service";
	$reg->{$service}{'TemplatePath'} ||= ["$reg->{$service}{'ServiceDir'}/templates"];
}

# For use by sub-classes to declare functions:
sub declare {
	my $self = shift;
	my $func = shift;
	
	$self->{functions}{$func}{args} = { map {$_,1} @_ };
}



# Base methods, can be overridden in sub-classes

sub has_variable {
	my $self = shift;
	my $chunk = shift;

	# Do a lookup based on name only.
	# Until Taco::ArgTable->exists() supports more, this is all we can check.
	my ($name) = &Taco::ArgUtil::parse($chunk->{name});
	return $G::params->exists($name);
}

sub has_function {
	my $self = shift;
	my $chunk = shift;
	
	return exists $self->{functions}{ $chunk->{name} };
}

sub find_value {
	my $self = shift;
	my $chunk = shift;
	
	# Do a lookup based on name only
	# Until Taco::ArgTable->val() supports more, this is all we can check.
	my ($name) = &Taco::ArgUtil::parse($chunk->{name});
	return $G::params->val($name);
}

sub run_function {
	my $self = shift;
	my $chunk = shift;  # The parameters from the function call
	
	# Turn the list of arguments into Taco::ArgLayer format
	my $in_args = 'Taco::ArgLayer'->new_from_strings( @{$chunk->{args}} );
	
	# Save the current values of the two arglayers
	my $my_func_save    = $G::params->dup_layer('my_func');
	my $local_func_save = $G::params->dup_layer('local_func');
	
	# Clear the my_func layer
	$G::params->set_layer('my_func', 'Taco::ArgLayer'->new());

#warn "\$G::params in run_function\n";
#$G::params->show_me(1);	
	
	# Get references to the current arglayers
	my $my_func    = $G::params->get_layer('my_func');
	my $local_func = $G::params->get_layer('local_func');
	
	
	# Separate the incoming args into two piles
	my $name = $chunk->{name};
	my $to_my = $self->{functions}{$name}{args};
	my ($key, $val);
	while (($key, $val) = $in_args->each()) {
		# Call the merge method on the right layer:
		($to_my->{$key} ? $my_func : $local_func)->merge({$key=>$val});
	}
	
	
	# Run the function
	my $result = $self->$name();	
	
	# Restore the two arglayers
	$G::params->set_layer('my_func', $my_func_save);
	$G::params->set_layer('local_func', $local_func_save);
	
	return $result;
}

sub set_service {
	&Taco::Dispatcher::current_service( $G::params->val('name', 'my_func') );
}


# Public interface:

sub has_hook {
	my $self = shift;
	my $chunk = shift;
	
	# Hook character is $chunk->{type}
	my $tester;
	return unless ($tester = $self->{hook_testers}{ $chunk->{type} });
	return $self->$tester($chunk);
}

sub do_hook {
	my $self = shift;
	my $chunk = shift;
	
	# Hook character is $chunk->{type}
	my $doer = $self->{hook_doers}{ $chunk->{type} } || 'no_hook_defined';
	return $self->$doer($chunk);
}


1;
__END__

=head1 NAME

Taco::Module.pm - abstract base class for Taco modules

=head1 SYNOPSIS

A Taco module defines what should happen when Taco encounters some [[tags]] in
a template.  It can define [[&functions]], or control what happens when Taco fills
in a [[$variable]], or even define some completely new kind of [[%tag]].

This class, Taco::Module, is an abstract class from which all Taco modules
should be derived.  It also provides one function which can be used in templates,
the [[&set_service]] function.




=head1 DESCRIPTION

=head2 [[ &set_service( name=new_service ) ]]

Use this function in a template to switch the currently active service.  The
C<name> parameter must be the name of a service in the Taco::ServiceRegistry.pm
file.


=head2 Using a module

In order to use a Taco module, you need to make a Taco service that uses the module.
See Taco::ServiceRegistry for more information about adding modules to services.


=head2 Functions and Methods

=over 4

=item * new

This is the base class constructor.  To make a derived class, you need to override
the constructor like so:

 sub new {
	my $package = shift;
	my $self = new Taco::Module;

	# Declare functions:
	$self->declare('func1', qw(arg1 arg2 arg2) );
	$self->declare('rainbow', qw(red orange yellow green blue indigo gravy) );
	
	return bless ($self, $package);
 }

See also $module->declare().


=item * $module->declare( NAME, ARGS )

Use this method to make functions available to templates.  NAME is a string containing
the name of the function you wish to export.  ARGS is a list of strings, and when
your function is called in a template, parameters matching these names will not be 
propagated into lower-level templates.

Generally you'll only use the declare() method in the module's constructor.


=item * $module->init($service);

When a module is created at server startup, Taco will call its init() method.  By default
this method doesn't do anything, but overriding this method will let you read
configuration files, open databases, or whatever you need to do.  For example, the Taco::DB
module reads config.pl files for all the services that use Taco::DB.  The Taco::Generic
module sets the ServiceRegistry's 'TemplatePath' to a default value if it hasn't
been set already.


=item * $self->has_function( CHUNK )

=item * $self->has_variable( CHUNK )

=item * $self->{'hook_testers'}

When Taco encounters a [[tag]] in a template, it will step through the list of
modules and ask each module whether it can handle that tag.  The mechanism for
this asking process is handled by the C<$self-E<gt>{'hook_testers'}> hash.  A
typical C<hook_testers> hash looks like this:

   $self->{'hook_testers'} = {
      '$' => 'has_variable',
      '&' => 'has_function',
   };

You can override the C<has_variable> method and the C<has_function> method in a module 
subclass.  For instance, if you want [[$cake]] to look up the value of 'cake' in a 
database, then your C<has_variable> method should query the database to see whether 
it contains an entry for 'cake'.  This is exactly what the Taco::DB module does.

All hook_tester functions should return a boolean value (true or false).

Taco::Module contains base functions for the C<has_function> and C<has_variable> methods,
which you shouldn't need to override for simple modules.


=item * $self->find_value( CHUNK )

=item * $self->run_function( CHUNK )

=item * $self->{'hook_doers'}

Once Taco has determined that your module will handle a certain tag, it uses the
entries in the C<$self-E<gt>{'hook_doers'}> hash to let your module actually
handle the tag.

Each of the C<hook_doers> should output a single string.  This string will be
inserted into the template at the correct place.  The input to all the hook_doer
functions is a "chunk", which is a data structure like this:

  $chunk = {
     'type' => '&',
     'name' => 'list', # For example
     # perhaps more stuff depending on
     # what kind of chunk it is
  };

These chunks are the output of the Taco::Template chunker functions.  A chunker function
takes a string like [[&func(arg1=val arg2=val)]] and turns it into a data structure.
See Taco::Template for more info on chunks and chunkers.

If you add entries to the C<$self-E<gt>{'hook_testers'}> and C<$self-E<gt>{'hook_doers'}> 
hashes, you can extend the syntax of Taco templates.  For instance, to enable some kind 
of hash lookup in templates, you could do something like this:

   $self->{'hook_testers'}{'%'} = 'has_hash';
   $self->{'hook_doers'}{'%'}   = 'do_hash_lookup';

And then you'd write the C<has_hash> and C<do_hash_lookup> functions.  You'll also need
to supply a chunker for % tags.

=back

=head2 Writing Taco modules

To create a new Taco module, you'll create a Perl module that's a subclass of
Taco::Module (through direct or indirect inheritance).  You'll probably add some 
functions, so declare those in your constructor, using the declare() method.
Look at Taco::Generic and Taco::DB for examples of real Taco modules.

When you're writing a function that needs to send text to the browser (or whoever
is filling in Taco templates), you shouldn't just use print().  In fact, you
should probably _never_ print to STDOUT.  Use the $template->output() method to
output text, because sometimes it's safe to just print your text, but other times
you need to return it at the end of the routine.  For example, consider this
template:

 __________________
 [[ &list(driver=catalog_id
         display_text=[[&parse(parse_template=shower variable=value)]]
 ) ]]
 __________________

If &parse printed its output instead of returning it, then it would appear on the
page B<above> the call to &list, because &list hasn't run yet when &parse is
running.  It's all very complicated, it gives me a headache.

Fortunately, $template->output() knows when you're in one situation and when 
you're in the other.  See Taco::Template for more information about about using
$template->output() and $template->straight_output() to stream your output properly.

=head1 AUTHOR

Ken Williams (ken@forum.swarthmore.edu)

Copyright (c) 1998 Swarthmore College. All rights reserved.

=cut
