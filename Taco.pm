$Taco::VERSION = '0.02';

use Taco::LibLib;
use Taco::Dispatcher;
use Taco::Arg;
use Taco::Template;
use Taco::Module;
use Taco::Init;
use Taco::ServiceRegistry;

1;
__END__

=head1 NAME

Taco - Dynamic web page system

=head1 SYNOPSIS

 # In a dynamic document
 <title>[[$user_id]]s web page</title>
 Here are your favorite foods:<br>
 [[&list(driver=foods for_user=[[$user_id]] display_template=food_template)]]


 # For serving Taco web pages, put in httpd.conf
 PerlModule Apache::Taco
 <Files ~ "\.taco$">
  SetHandler perl-script
  PerlHandler Apache::Taco
 </Files>
 
 # For parsing stand-alone files, type at Unix prompt
 parse_file.pl [-s service] [-q query_string] filename
 (not ready yet, sorry)

=head1 DESCRIPTION

Taco is a software tool which facilitates the creation of dynamic
web pages.  It's meant to run under the Apache web server, using the
mod_perl extension.  

A Taco page is just like a regular HTML page, with one important addition: a
Taco page can contain Taco tags.  When a user requests a Taco page, the Taco
software finds all the Taco tags on the page and replaces them with the
appropriate text.  This text can come from a database, from a discussion
group, or from the query string, among other places.

In fact, Taco itself doesn't define the functions you can have in a web
page.  Rather, the functionality is encapsulated in modules, which can be
plugged into Taco.  You can write your own modules or use common ones that
are already written.  The most basic module functionality is in the
Taco::Generic.pm module, which is distributed with the main Taco
distribution.  All modules, including Taco::Generic, are sub-classes of
Taco::Module.

For more documentation, please see the other modules in this distribution. See
Taco::Module for a description of the syntax of the tags (how to use them in a
web page), or instructions on how to write your own Taco module.  See any Taco
module's documentation for a description of the specific tags it defines.

=head1 DOCUMENTATION

The documentation for Taco is spread out among several modules.  Here is a
summary of what each module does and what its documentation covers:

 Apache::Taco     This is the PerlHandler to use with mod_perl.  Here you'll
                  find information on how to configure a mod_perl-enabled
                  server to load Taco pages.
 
 Taco::Arg        This module implements the ArgTable and ArgLayer objects
                  which hold all the parameters in the query string, the POSTed
                  form contents, arguments passed to functions in [[tags]],
                  parameters set using the [[&set]] tag, and so on.
 
 Taco::Template   This module controls the parsing and output of Taco templates.
                  Templates are searched for [[tags]], and each tag is passed
                  to the Taco::Dispatcher module, which decides which Taco module
                  (e.g. Taco::Generic) will handle the tag.
 
 Taco::Module     This is a base class for Taco extension modules.  An extension
                  module (Taco::Generic is an example) can supply more Taco tags for
                  use in templates.
 
 Taco::ServiceRegistry
                  A Taco service is basically a set of configuration information.
                  The ServiceRegistry file contains definitional information
                  about the various services.  To add a service to Taco, add an
                  entry in the ServiceRegistry file.
 
 Taco::Dispatcher This module provides the glue between a Taco "service" and
                  the Taco modules it uses.  It also has routines that parse
                  the insides of Taco [[tags]], so the definitions of Taco syntaxes
                  are given here.
 
 Taco::Generic    This is a fairly generic Taco extension module.  It provides
                  several tags, such as [[&set]] (puts an entry in the global
                  ArgTable), [[&if]] (a conditional statement), [[&mark_me]]
                  (useful for checking checkboxes and radio buttons and selecting
                  choices in a <select> list), and so on.


=head1 AUTHOR

Ken Williams (ken@forum.swarthmore.edu)

Copyright (c) 1998 Swarthmore College. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1).

=cut
