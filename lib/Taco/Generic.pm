#!/usr/bin/perl

package Taco::Generic;

use strict;
use Taco::Module;
use Safe;
use vars qw(@ISA $VERSION);

@ISA = qw(Taco::Module);
$VERSION = '0.01';

my $debug = 0;

sub new {
	my $package = shift;
	my $self = new Taco::Module;

	# Declare functions:
	$self->declare('if', qw(condition true_text false_text true_template false_template) );
	$self->declare('set', qw(name value) );
	$self->declare('query', qw(trailing) );
	$self->declare('parse', qw(parse_template parse_text) );
	$self->declare('mark_me', qw(param mark match_type) );
	
	# Set up the safe place for the &if function
	$self->{module}{safe} = new Safe('Cleveland');
	$self->{module}{safe}->permit_only(':base_core');

	return bless ($self, $package);
}


sub if {
	my $self = shift;
	my ($varname, $pre);
	my $debug = 0;

	# Do variable interpolation on the parameters:
	my $cond = $G::params->val('condition', 'my_func');
	$cond =~ s/(?:([^\\])|^)\$([\w-]+)/ {
					($pre, $varname) = ($1, $2);
					$Cleveland::vars{$varname} = &Taco::Dispatcher::dispatch({name=>$varname, type=>'$'});
					$pre . "\$vars{'" . $varname . "'}";
				} /eg;
	$cond =~ s/\\\$(\w+)/\$$1/g;
	warn "condition is $cond" if $debug;
	
	# Evaluate the condition
	my $result = $self->{module}{safe}->reval($cond);
	die ("Error in eval-ing condition '$cond': $@") if $@;
	%Cleveland::vars = ();

	# Create the local variable for templates
	# Evaporates at end of &if, when $scope goes away
	my $scope = $G::params->new_temp('top', result => $result);

	# Process the result
	my $template = find Taco::Template( $result ? 'true' : 'false' );
	return unless $template;

	my $buffer;
	$template->output($buffer);
	return $buffer;
}


sub set {
	# Only look in the my_func layer
	my $key = $G::params->val('name', 'my_func');
	my $val = $G::params->get_arg('value', 'my_func');
	
	$G::params->set_arg('set', $key, $val);

	return '';
}

sub query {
	return if $ENV{'QUERY_STRING'} eq '';

	my $buffer = '';
	&Taco::Template::straight_output(
		$ENV{'QUERY_STRING'} . $G::params->val('trailing'), $buffer
	);
	
	return $buffer;
}

sub parse {
	my $template = find Taco::Template("parse");
	my $buffer = '';
	
	$template->output($buffer);
	return $buffer;
}



sub mark_me {
	my $self = shift;

	my ($name, $type, @to_look_in);
	unless ($name = $G::params->val('param')) {
		&gripe("Improper usage of \&mark_me: no parameter");
		return;
	}

	my $asked_value = $G::params->val('value');
	my $output = "name=\"$name\" value=\"$asked_value\"";

	{
		my $object;
		($name, $object) = &Taco::ArgUtil::parse($name);
		$type = $object->[0]{'type'};
	}

	if ($type) {
		# Only match in a parameter of the same type
		foreach ($G::params->vals($name)) {
			if ($_->{'type'} eq $type) {
				push(@to_look_in, $_->{'val'});
			}
		}
	} else {
		@to_look_in = ($G::params->vals($name));
	}
	
	return $self->do_marking($output, $asked_value, \@to_look_in );
}


sub do_marking {
	my ($self, $string, $test, $list) = @_;
	my $type = $G::params->val('match_type');
	my $mark = $G::params->val('mark');

	if ($type eq '~') {
		$string .= " $mark" if grep(/\Q$test/, @$list);
	} elsif ($type eq '<') {
		$string .= " $mark" if grep($_ lt $test, @$list);
	} elsif ($type eq '>') {
		$string .= " $mark" if grep($_ gt $test, @$list);
	} elsif ($type eq '!') {
		$string .= " $mark" if grep($_ ne $test, @$list);
	} else {
		$string .= " $mark" if grep($_ eq $test, @$list);
	}
	
	my $buffer;
	&Taco::Template::straight_output($string, $buffer);
	return $buffer;
}


1;
__END__

=head1 NAME

Taco::Generic.pm - Generic Taco template functions

=head1 SYNOPSIS

These are generic functions that any Taco template may want to have
available to it.

  [[&query]]
  [[&parse]]
  [[&set]]
  [[&if]]
  [[&mark_me]]

=head1 DESCRIPTION

The general syntax for any of these functions is:

 [[&name(arg1=val1 arg2='value two' ...)]
   or
 [[&name arg1=val1 arg2=[[&name2 arg="value two" ]] ...]
   or
 [[ &name ]]

Whitespace is optional at the beginning and end of the tag.  A tag may
be spread across several lines, which is useful if you've got lots of 
arguments you're passing to the function.  See the documentation for
Taco::Template for more information about the syntax.  If you really
want the juicy details you can look at the file t/docs/syntax.taco in the 
distribution package - it has lots of valid syntaxes for function calls.

=over 4

=item * [[&query(trailing=&)]]

This function will return the query string (verbatim).  The value of the
C<trailing> parameter will be appended if the query string exists (is 
not the empty string), which is useful in situations like this:

  <a href=page.taco?[[&query(trailing=&)]]flavor=cheese>Cheese City</a>

If there's a query string (for example, "key=value"), this will appear as:

  <a href=page.taco?key=value&flavor=cheese>Cheese City</a>

Otherwise it will appear as:

  <a href=page.taco?flavor=cheese>Cheese City</a>


The only localized parameter is C<trailing>.

=item * [[&parse(parse_template=whatever)]]

This will parse a template and insert its output here.  If you specify the 
C<parse_template> parameter, it will look for the named template in the
template directories.  In this way, it is similar to a server-side include.

You can also use C<[[&parse(parse_text="verbatim text")]]>, though this
is rarely useful.

Taco will use the value of the C<TemplatePath> attribute in the 
Taco::ServiceRegistry to look for your templates.  See also 
Taco::ServiceRegistry.

Localized parameters are C<parse_template> and C<parse_text>.


=item * [[&set(name=flavor value=raspberry)]]

The above function call will set the "flavor" entry to "raspberry" in the
'set' layer of the global parameter table.  It will not output anything.

Localized parameters are C<name> and C<value>.

For more information about parameter tables, see Taco::Arg(3).

=item * [[&if(condition='$var eq "hello"' 
              true_text='it is hello' 
              false_template=no_match)]]

Use this function to write a conditional statement and output some text
or a template based on the result.  The condition can be any Perl expression
that will compile under Safe.pm's ":base_core" option.  This means
that you're restricted to a small subset of Perl expressions, so check the
error log if your template blows up - it might have an unallowable Perl
expression in it.  Furthermore, the condition parameter must be present
in the function call itself, so you can't put ...&condition=1&field=... in 
the query string.

Using the Safe.pm module gives some protection against web users changing 
the query string and doing something very bad to your system.

The C<true_text> and C<true_template> parameters specify what should be output
if the condition evaluates to true.  You can use the special variable C<$result>
in your text (or template) to get the actual result of the evaluated condition.

Likewise, the C<false_text> and C<false_template> parameters specify what should 
be output if the condition evaluates to false.  C<$result> is still available, 
though it's probably not very interesting.


Localized parameters are C<condition>, C<true_text>, C<true_template>,
C<false_text>, and C<false_template>.

=back

=head1 SEE ALSO

Taco(3), Taco::Template(3), Taco::Module(3)

=head1 TO DO

 It would be nice to have an [[&elsif]] tag or some similar idea.


=head1 AUTHOR

Ken Williams (ken@forum.swarthmore.edu)

Copyright (c) 1998 Swarthmore College. All rights reserved.

=cut
