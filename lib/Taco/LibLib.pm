#!/usr/bin/perl

use strict;
package Taco::LibLib;

my %CODEFILES; # What files are registered
my %TIMES;     # The time of last slurpage for each file
my $debug = 0;


sub register {
	# Make sure the file has an entry in %CODEFILES, then
	# make a datestamp for it:
	foreach my $file (@_) {
		&get($file);
		$CODEFILES{$file} = 1;  # Keep a list of registered files
		
		unless (exists $TIMES{$file}) {
			$TIMES{$file} = (stat $INC{$file})[9];
		}
	}
}

sub get {
	package main;
	require $_[0];
	package Taco::LibLib;
}

sub freshen {
	my ($file, $last_mod);
	
	foreach $file (keys %CODEFILES) {

		unless (-e $INC{$file}) {
			# It's been moved or removed
			warn "$file no longer exists at $INC{$file}, will try to re-register" if $debug;
			warn "cwd is ", `pwd` if $debug;
			delete $INC{$file};
			delete $CODEFILES{$file};
			&register($file);
		}
		$last_mod = (stat $INC{$file})[9];
		
		if ($last_mod > $TIMES{$file}) {
			warn "[$$] recompiling $INC{$file}, last touched at $last_mod" if $debug;
			delete $INC{$file};

			&get($file);

			$TIMES{$file} = $last_mod;
		}
		
	}
}

1;

__END__

=head1 NAME

Taco::LibLib.pm - keep Perl files fresh

=head1 SYNOPSIS

Under normal mod_perl, Perl files will only get compiled when the server starts
up.  Any later changes you make to code files will not take effect until you
restart the server.

To avoid this behavior, put LibLib::register($file); instead of require $file; 
in your code.

This is similar to Apache::StatInc, but for some reason I'm using this instead.

=head1 DESCRIPTION

=over 4

=item * register()

 Usage: &Taco::LibLib::register('file1.pl', 'file2.pl', ...);

Use this function instead of "require 'file1.pl'", and your files
will be magically compiled again whenever they get modified.

You do not need to call freshen_codefiles() after register_codefiles().
Files will be freshened automatically.


=item * freshen()

 Usage: &Taco::LibLib::freshen();

Checks to see whether any code files have been modified since we last
pulled them in.  If so, we pull them in again.

=back

=head1 AUTHOR

Ken Williams (ken@forum.swarthmore.edu)

Copyright (c) 1998 Swarthmore College. All rights reserved.

=cut
