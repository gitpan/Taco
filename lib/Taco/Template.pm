#!/usr/bin/perl

package Taco::Template;
use strict;
use IO::File;
use Carp;
use vars qw($HOLD_IT);

my $debug = 0;
my (%chunkers, %executors);

my @FILEPATH = qw(.);
my ($open, $close) = qw( [[ ]] );
my %tally = ( $open=>1, $close=>-1 );

sub new {
	my $package = shift;
	my $text = shift;
		
	my $self = {
		'text' => $text,
		'properties' => {},
	};
	
	return bless ($self, $package);
}


sub find {
	my $package = shift;
	my $name = shift;
	my $ref = shift;

	my $template = new $package;
	if ( $G::params->exists($name . '_text') ) {
		$$ref = 'text' if defined $ref;
		$template->set_text( $G::params->val($name . '_text') );
		
	} elsif ( $G::params->exists($name . '_template') ) {
		$$ref = 'template' if defined $ref;
		$template->get_file( $G::params->val($name . '_template') )
			or croak("Couldn't get template file '" . $G::params->val($name . '_template') . "'");

	} else {
		# Couldn't find anything
		return;
	}

	return $template;
}

sub set_text {
	my $self = shift;
	$self->{text} = shift;
}

sub get_text {
	my $self = shift;
	return $self->{text};
}

sub get_file {
	my $self = shift;
	my $file = shift;
	my ($realfile, $dir, @file, $fh);
	
	$self->{'text'} = '';
	
	if ($file eq 'null') {
		# Give an empty template
		return 1;
	}

	my @path = (exists $self->{filepath} ? @{$self->{filepath}} : @FILEPATH);
	
	# Find out what file to open:
	if ($file =~ /^\//) {
		$realfile = $file;
	} else {
		foreach $dir (@path) {
			if ( -f "$dir/$file" ) {
				$realfile = "$dir/$file";
				last;
			}
		}
	}

	unless ($realfile  and  -f $realfile) {
		carp ("Can't find file '$file' in template path @path");
		return 0;
	}
	
	unless ( $fh = new IO::File($realfile) ) {
		carp ("Can't open $realfile: $!");
		return 0;
	}
	
	$self->{'text'} = join('', $fh->getlines );
	return 1;
}

sub set_path {
	my $s = shift;
	
	if (ref $s) {
		# $s is a template object, set path for this object
		$s->{filepath} = [@_];
	} else {
		# $s is a package name, set path for this package
		@FILEPATH = @_;
	}
}


sub set_property {
	my $self = shift;
	my $prop = shift;
	$self->{properties}{$prop} = shift;
}

sub get_property {
	my $self = shift;
	my $prop = shift;
	$self->{properties}{$prop};
}

sub set_chunker {
	my $char = shift;
	$chunkers{$char} = shift();
	print ("Chunkers are ", join(' ', %chunkers), "\n") if $debug;
}

sub set_executor {
	my $char = shift;
	$executors{$char} = shift;
}

sub output {
	$_[1] .= &_fill_in( ref $_[0] ? $_[0]->{text} : $_[0] );
}

sub straight_output {
	$_[1] .= &_do_output( ref $_[0] ? $_[0]->{text} : $_[0] );
}

sub interpret {
	local $HOLD_IT = 1;
	return &_fill_in( ref $_[0] ? $_[0]->{'text'} : $_[0] );
}

sub delimiters {
	return ($open, $close);
}

####### Private routines:


sub _do_output {
	if ($HOLD_IT) {
		return join('', @_);
	} else {
		print @_;
		return '';
	}
}

sub _fill_in {
	my $text = shift;
	my $out;
	
	# Build a syntax tree and execute it
	foreach my $node ( &_parse($text) ) {
		if ($node->[0] eq 'text') {
			$out .= &_do_output( $node->[1] );
		} elsif ($node->[0] eq 'tag') {
			$out .= &_do_output( $executors{$node->[1]{type}}->($node->[1]) );
		} else {
			die ("Malformed syntax tree: $node->[0]");
		}
	}
	return $out;
}

sub _parse {
	local $_ = shift;
	my ($saw, @tree, $end);

	# See if there are any opening delimiters in the text
	my $begin = -1;
	while ( / (\\*) \Q$open\E /gox ) {
		if ( (length $1) % 2 == 0 ) {
			# An even number of backslashes, so it's a real beginning delimiter
			$begin = pos() - length($open);
			last;
		}
	}
	return ( [text=>$_] ) if $begin == -1;   # No tags
	
	
	# Okay, there seem to be some tags in the text.  Let's find the first
	# one, working from the outside in.  If we succeed in finding a tag, pos()
	# will be set to the position of the closing delimiter.  Otherwise, pos() will be zero.
	my $count=1;
	while ( / (\\*) ( \Q$open\E | \Q$close\E ) /gox ) {
		if ( (length $1) % 2 == 0) {
			# An even number of backslashes, so chalk up a real delimiter
			$count += $tally{$2};
			last unless $count > 0;
		}
	}
	die ("Can't find ending $close delimiter\n") unless ($end = pos());	

	# Push it into the tree:
	push (@tree, [text=> substr($_, 0, $begin)] ) if $begin>0;  # There's some leading text

	# Get the first character & meat of the tag:
	my $gut_start = $begin + length($open);
	my $gut_length = $end - $gut_start - length($close);
	my $tag = substr($_, $gut_start, $gut_length);
	
	# Delete whitespace
	$tag =~ s/^\s+//;
	$tag =~ s/\s+$//;
	
	my $char = substr($tag, 0, 1);
	push @tree, [tag=> &_chunk_it($char, substr($tag, 1))];
	
	# Return, and recurse if there's more string left:
	return @tree, ($end < length) ? &_parse( substr $_, $end ) : ();
}

sub _chunk_it {
	# Usage: &chunk_it( char, $text );
	return $chunkers{$_[0]}->( $_[0], $_[1] );
}


###### specific template syntax:



sub ____DOC____ {}  # for BBEdit
1;


__END__

=head1 NAME

Taco::Template.pm - Taco templates

=head1 SYNOPSIS

 use Taco::Template;
 
 $template = new Taco::Template( 'Howdy, [[$name]]!' );
 $template->output($buffer);
 $string = $template->interpret;
 $string2 = &Taco::Template::interpret( 'And hello, [[$name2]]!' );
 # ... etc.

=head1 DESCRIPTION

This module is a class implementing fill-in templates for Taco.  It provides support
for streaming the output of a filled-in template.  The specific syntaxes of the
tags are not defined in this class, so it is extensible and flexible.


=head2 Functions and Methods

=over 4

=item * new Taco::Template($text);

Creates a new Template object whose content is the given text.


=item * find Taco::Template('name')

Searches $G::params for an entry called 'name_text' or 'name_template'.
Returns a template whose content is the value of 'name_text', or whose
content is the contents of the file referred to by 'name_template'.  If
neither is found, returns the undefined value.

May be called with an optional second argument, which is a reference to a
scalar variable.  This scalar will be set to the string 'text' if the
'name_text' parameter is found, or 'template' if the 'name_template'
parameter is found, or the undefined value if neither is found:

 my $template = find Taco::Template('name', \$kind);
 if ($kind eq 'text') ...

Note that if no suitable parameter is found in $G::params, no error will be
printed to STDERR.  This allows you the flexibility to write code like this:

 # Template is required:
 my $template = find Taco::Template('display')
    or die ("Couldn't find 'display_template' or 'display_text'");

 # Template is optional:
 my $template = find Taco::Template('wrapping');
 if ($template) {
    # ... do something with $template ...
 }


=item * $template->get_text()

Returns the content of the template object.

=item * $template->set_text('text blah [[$blah]]')

Sets the content of the template to the given text.

=item * $template->get_file('filename')

Puts the contents of the file 'filename' into the template's content.  If the
filename has a leading slash, it is treated as an absolute filename.  If it does
not, C<get_file> will search the directories in the template's path for the given
file.

See also C<set_path>.

=item * $template->set_path('dir1', 'dir2', ...);

Sets the path for the C<get_file> method.  If called as an object method, will set
the path for just the given template.  If called as a static class method, will set
the default path for all templates:

  Taco::Template->set_path('/etc/templates');   # sets default path
  $my_templ->set_path('/etc/templates');  # only sets path for $my_templ

=item * $template->set_property( name => 'property')

=item * $template->get_property('name')

The user of a template may wish to set some attribute of a template, and
later retrieve that attribute.  These methods let you do so.  This is useful to 
achieve small extensions to the functionality of the templates without
having to derive a new class.

=item * $template->output($buffer)

=item * &Taco::Template::output($text, $buffer)

Interprets and outputs the contents of the template.  Checks a flag to see whether
printing is okay, or whether output should be added to the end of the buffer.
Typically, output will be buffered in nested tags:

 ____________ outer.tmpl: ________________________________
 [[ &list( key=[[&parse(parse_template=inner.tmpl)]] ) ]]
 ____________ inner.tmpl: ________________________________
 this is the key's value
 _________________________________________________________

Since C<&parse> is called inside C<&list>, it must not print its output, it must return
it.  The Template class keeps track of when it's okay to print, and when a routine must
return its output instead.  In this way, output can be streamed as much as possible.

If the first argument to C<output> is a reference, then this argument will be treated
as a template object.  Otherwise, it will be treated as a string.

Here is a simple example of a routine that uses C<output>:


 sub do_something {
	my $template  = find Taco::Template('stuff') or die ("Can't find my stuff");
	my $buffer;
	
	&Taco::Template::output('<ol start=[[$num]]>', $buffer);
	# Instead of: print &Taco::Template::interpret('<ol start=[[$num]]>');

	$template->output($buffer);
	# Will append text to $buffer if necessary
	
	&Taco::Template::straight_output('</ol>', $buffer);
	
	return $buffer;
 }


=item * $template->straight_output($buffer)

=item * &Taco::Template::straight_output($text, $buffer)

Identical to C<output>, except the text will not be interpreted as a template, it
will be output directly (or appended to $buffer).  This is useful for outputting
chunks of text quickly when you know there are no tags in it:

  &Taco::Template::straight_output("</ol>\n", $buffer);


=item * $template->interpret

=item * &Taco::Template::interpret( $text )

Returns the parsed contents of the template or text.  Will not print anything (assuming
the functions called in the template are well-behaved and use C<Taco::Template::output> and
the like).

=back


=head2 Controlling template syntax and execution

=over 4

=item * &Taco::Template::set_chunker( char, \&routine );

Sets the chunker for the given character.  The chunker will be called when building
the syntax tree for a template.  A chunker routine takes two arguments: the character
(such as $ or &) of the type of template call, and the text of the template call, with
leading and trailing delimiters and whitespace removed.  For instance, with the 
following in a template:

  [[ &burp(because=have_gas) ]]

The chunker will receive '&' as its first argument, and 'burp(because=have_gas)'
as its second argument.

A chunker function should parse the text into a hash reference, which includes a 'type' field
equal to the chunker's first argument.  The rest of the hash can have whatever structure the
executor of that hook will need to execute it (see C<set_executor>).  The chunker returns
a single argument, the hash reference with the 'type' field.

Here is an example of a chunker which handles tags like C<[[ $var ]]>:

 sub chunk_variable {
   # returns {type=>'$', name=>'whatever'}

   my $type = shift;
   my $text = shift;
   return {
      type=>$type,
      name=>&Taco::Template::interpret($text),  
                   # So we can handle things like [[ $var[[$two]] ]].
                   # If we didn't need to, we could just do name=>$text.
   };
 }


=item * &Taco::Template::set_executor( char, \&routine );

Sets the executor function for the given character.  The executor will be called to
interpret the value of a template tag.  It takes one argument, a hash reference created 
by a chunker.  The executor should return a string which is the result of executing 
the given tag.

=back

=head1 SEE ALSO

Have a look at C<Taco::Dispatcher.pm> if you're want to see the chunker and executor
functions.  They govern the syntax and execution of the individual tags.


=head1 AUTHOR

Ken Williams (ken@forum.swarthmore.edu)

Copyright (c) 1998 Swarthmore College. All rights reserved.

=cut
