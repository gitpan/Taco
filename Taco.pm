$Taco::VERSION = '0.01';

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


=head1 DESCRIPTION

Taco is a software tool which facilitates the creation of dynamic
webpages.  It's meant to run under the Apache web server, using the
mod_perl extension.  

A Taco page is just like a regular HTML page, with one important
addition: a Taco page can contain Taco tags.  When a user requests a Taco
page, the Taco software finds all the Taco tags on the page and replaces
them with the appropriate text.  This text can come from a database, from
a discussion group, or from the query string of the Taco page, among
other places.

In fact, Taco itself doesn't define the functions you can have in a web
page.  Rather, the functionality is encapsulated in modules, which can be
plugged into Taco.  You can write your own modules or use common ones that
are already written.  The most basic module functionality is in the
Taco::Generic.pm module, which is distributed with the main Taco distribution.
All modules, including Taco::Generic, are sub-classes of Taco::Module.

For more documentation, please see the other modules in this distribution. See
Taco::Module for a description of the syntax of the tags (how to use them in a
web page), or instructions on how to write your own Taco module.  See any 
module's documentation for a description of the specific tags it defines.

=head1 AUTHOR

Ken Williams (ken@forum.swarthmore.edu)

Copyright (c) 1998 Swarthmore College. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1).

=cut
