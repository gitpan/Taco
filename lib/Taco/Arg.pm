use strict;
use Tie::LLHash; # For ordered hashes - the hash of layers is ordered.


###############################################################
package Taco::ArgTable;
use Carp;
# A structured set of arguments to pass around
sub ______ArgTable____ {} # For BBEdit Popup menu
###############################################################

sub new {
	my $pkg = shift;
	my $self = {};

	tie (%{$self->{layers}}, 'Tie::LLHash') or die $!; # A linked list of layers
	return bless ($self, $pkg);
}

sub exists {
	my $self = shift;
	my $name = shift;
	
	my $layer = $self->layer_containing($name, @_);
	return unless defined $layer;
	return 1;
}

sub set_arg {
	my $self = shift;
	my $layer = &Taco::ArgLayerName::to_string( shift() );
	
	croak ("No such layer '$layer'") unless $self->layer_exists($layer);

	# Pass it to the layer:
	return $self->{layers}{$layer}->set_arg(@_);
}

sub add_arg {
	my $self = shift;
	my $layer = shift;
	$layer = &Taco::ArgLayerName::to_string( $layer );
	
	croak ("No such layer $layer") unless $self->layer_exists($layer);

	# Pass it to the layer:
	return $self->{layers}{$layer}->add_arg(@_);
}


sub layer_names {
	my $self = shift;
	return keys %{$self->{layers}};
}

sub dup_layer {
	return $_[0]->{layers}{$_[1]}->dup();
}

sub get_layer {
	return $_[0]->{layers}{$_[1]};
}

sub set_layer {
	$_[0]->{layers}{$_[1]} = $_[2];
}

sub delete_layer {
	delete $_[0]->{layers}{ &Taco::ArgLayerName::to_string($_[1]) };
}


sub new_temp {
	# Note: this context test doesn't work under Devel::DProf!!!
	croak ("Can't call new_temp in a void context") unless defined wantarray;

	my $self = shift;
	my $after_layer = shift;
	croak ("No layer insertion point specified for new_temp") unless defined $after_layer;

		
	# Create a name for the new layer
	my $i = 0;
	$i++ while (exists $self->{layers}{"lyr$i"});
	my $new_name = "lyr$i";
	
	# Create the new layer
	my $new_value = 'Taco::ArgLayer'->new();
	(tied %{$self->{layers}})->insert($new_name, $new_value, $after_layer);
	
	# Fill 'er up
	while ( @_ ) {
		$self->{layers}{$new_name}->add_arg( splice @_, 0, 2 );
	}

	return new Taco::ArgLayerName($new_name, $self);
}

sub set_top_layer {
	my $self = shift;
	my ($new_name);

	if (@_) {
		# Use the name they give us
		$new_name = shift;
	} else {
		# Create a new name
		my $i = 0;
		$i++ while (exists $self->{layers}{"lyr$i"});
		$new_name = "lyr$i";
	}
	
	my $new_value = 'Taco::ArgLayer'->new();
	(tied %{$self->{layers}})->first($new_name, $new_value);
	
	return;
}

sub insert_layer {
	# Put a new layer in the ArgTable
	# Usage: $table->insert_layer('put after layer', 'new layer name');
	#             or to generate a new name automatically:
	#        $new_name = $table->insert_layer('put after layer');
	
	my $self = shift;
	my $after_layer = shift;
	my ($new_name);

	if (@_) {
		# Use the name they give us
		$new_name = shift;
	} else {
		# Create a new name
		my $i = 0;
		$i++ while (exists $self->{layers}{"lyr$i"});
		$new_name = "lyr$i";
	}
	
	my $new_value = 'Taco::ArgLayer'->new();
	(tied %{$self->{layers}})->insert($new_name, $new_value, $after_layer);
	
	return $new_name;
}

sub layer_exists {
	my $self = shift;
	my $layer_name = shift;
	return exists $self->{layers}{$layer_name};
}

sub layer_containing {
	my $self = shift;
	my $key = shift;
	my @layers = ( @_ ? @_ : $self->layer_names );

	foreach (@layers) {
		unless ($self->layer_exists($_)) {
			warn "No such layer $_";
			next;
		}
	
		# Check to see whether the layer has this key
		if ($self->{layers}{$_}->exists($key)) {
			return $_;
		}
	}
	return;
}

sub keys {
	my $self = shift;
	my @layers = ( @_ ? @_ : $self->layer_names );
	my %hash = ();

	foreach my $layer (@layers) {
		%hash = (%hash, map {$_,1} $self->{layers}{$layer}->keys());
	}

	return keys %hash;
}

sub show_me {
	my $self = shift;
	my $verbose = shift;
	my ($k, $v);
	
	while (($k, $v) = each %{$self->{layers}}) {
		print STDERR "<$k>\n";
		$v->show_me if $verbose;
	}
}

sub to_hash {
	my $self = shift;
	my $name_only = shift;
	my @returns;
	
	foreach my $layer (reverse $self->layer_names) {
		push @returns, $self->{layers}{$layer}->to_hash($name_only);
	}
	return @returns;
}
sub to_query_string {
	croak ("to_query_string not implemented yet");
}
sub to_arg_string {
	croak ("to_arg_string not implemented yet");
}

sub val      { my $s = shift; scalar $s->_access('val',    @_) }
sub vals     { my $s = shift;       ($s->_access('vals',   @_))}
sub group    { my $s = shift; scalar $s->_access('group',  @_) }
sub groups   { my $s = shift;       ($s->_access('groups', @_))}
sub type     { my $s = shift; scalar $s->_access('type',   @_) }
sub types    { my $s = shift;       ($s->_access('types',  @_))}
sub place    { my $s = shift; scalar $s->_access('place',  @_) }
sub places   { my $s = shift;       ($s->_access('places', @_))}
sub get_arg  { my $s = shift; scalar $s->_access('get_arg', @_)  }
sub get_args { my $s = shift;       ($s->_access('get_args', @_))}


sub _access {
	my $self = shift;
	my $att = shift;
	my $key = shift;

	my $layer = $self->layer_containing($key, @_);
	return unless defined $layer;
	return $self->{layers}{$layer}->$att($key, @_);
}


###############################################################
package Taco::ArgLayer;
use Carp;
# A layer in an ArgTable
sub ______ArgLayer____ {} # For BBEdit Popup menu
###############################################################

sub new {
	my $pkg = shift;
	
	# If they gave us a data structure, bless it into an ArgLayer.  
	# Otherwise, bless a new hashref.

	$pkg = ref $pkg if ref $pkg;
	if (@_) {
		return bless $_[0], $pkg;
	} else {
		return bless {}, $pkg;
	}
}

sub new_from_strings {
	my $pkg = shift;

	# Call parse with the current arguments in @_, and make the result
	# a new ArgLayer.

	return bless { &Taco::ArgUtil::parse }, $pkg;
}

sub new_from_query_string {
	my $pkg = shift;
	return bless { &Taco::ArgUtil::parse_query_string }, $pkg;
}

sub new_from_post {
	my $pkg = shift;
	return bless { &Taco::ArgUtil::parse_post }, $pkg;
}

sub dup {
	my $self = shift;
	my $dup = $self->new;
	%$dup = %$self;
	return $dup;
}

sub exists {
	return exists $_[0]->{$_[1]};
}

sub delete {
	return delete $_[0]->{$_[1]};
}

sub get_arg {
	my ($self, $name) = @_;
	return $self->{$name}[-1];
}

sub get_args {
	my ($self, $name) = @_;
	return @{ $self->{$name} };
}

sub set_arg {
	my $self = shift;
	my ($name, $val);
	
	while (@_) {
		$name = shift;
		$val = shift;
		$self->{$name} = (ref $val ? [ $val ] : [ {'val' => $val} ]);
	}
}

sub add_arg {
	# Usage:
	# $layer->add_arg('name', 'value');
	# $layer->add_arg('name', {val=>...});
	#
	# Adds this arg to the end of this layer's 'name' node
	# The 'name' node doesn't have to exist already.
	# See also set_arg() and merge().

	my $self = shift;
	my ($name, $val);
	
	while (@_) {
		$name = shift;
		$val = shift;
		push @{$self->{$name}}, (ref $val ? $val : {'val' => $val});
	}
}

sub merge {
	# Usage:
	# $layer->merge($inArgLayer);
	#   $inArgLayer has to have the data structure of an ArgLayer, but it
	#   doesn't have to actually _be_ an Arglayer.  So you can call it like this:
	# $layer->merge({ 'key1'=>[{value=>...}, {value2=>...},...] });
	
	my $self = shift;
	my $inArgLayer = shift;
	
	my ($k, $v);
	while (($k, $v) = each %$inArgLayer) {
		push ( @{$self->{$k}}, @$v );
	}
}

sub keys {
	return keys %{$_[0]};
}

sub each {
	my $self = shift;
	return each %$self;
}

sub show_me {
	my $self = shift;
	
	my ($k, $v, $k2, $v2);
	while (($k, $v) = each %$self) {
	
		warn "  $k:\n";
		foreach (@$v) {  
			warn "    ->$_->{val}\n";
		}
	}
}

sub to_hash {
	my $self = shift;
	my $name_only = shift;
	
	my ($name, $node, @returns);
	my ($place, $group, $type);
	while (($name, $node) = each %$self) {
		push (@returns, map {&Taco::ArgUtil::unparse($name, $_, $name_only)} @$node);
	}
	return @returns;
}

sub to_query_string {
	my $self = shift;
	my @list = &Taco::ArgUtil::url_encode( $self->to_hash($_[0]) );  # Name only?
	
	
	my ($k, $v, $out);
	while (($k, $v) = splice(@list, 0, 2)) {
		$out .= "$k=$v";
		$out .= "&" if @list;
	}
	return $out;
}

sub to_arg_string {
	my $self = shift;
	my @list = $self->to_hash($_[0]);  # Name only?
	# ...
	croak("to_arg_string not implemented yet");
}

sub val    { my $s = shift; $s->_access('val',    @_) }
sub vals   { my $s = shift; $s->_access('vals',   @_) }
sub group  { my $s = shift; $s->_access('group',  @_) }
sub groups { my $s = shift; $s->_access('groups', @_) }
sub type   { my $s = shift; $s->_access('type',   @_) }
sub types  { my $s = shift; $s->_access('types',  @_) }
sub place  { my $s = shift; $s->_access('place',  @_) }
sub places { my $s = shift; $s->_access('places', @_) }


sub _access {
	my $self = shift;
	my $att = shift;  # val, vals, group, ...
	my $key = shift;
	
	if ($att =~ s/s$//) {
		return map( $_->{$att}, @{ $self->{$key} } );
	} else {
#		print STDERR "Returning $self->{$key}[-1]{$att}\n";
		return $self->{$key}[-1]{$att};
	}

}


###############################################################
package Taco::ArgLayerName;
# Returned by Taco::ArgTable->insert_layer
# Exists for its DESTROY function.
sub ____ArgLayerName___ {} # For BBEdit Popup menu
###############################################################

sub new {
	my $package = shift;
	
	my $self = {
		name => shift,
		table => shift,
	};

	return bless( $self, $package );
}

sub DESTROY {
	my $self = shift;
	
	# Remove this layer name from the ArgTable
	$self->{table}->delete_layer( $self->{'name'} );
}

sub name {
	my $s = shift;
	return $s->{'name'};
}

sub to_string {
	my $obj = shift;
	return ( ref $obj ? $obj->{'name'} : $obj );
}

###############################################################
package Taco::ArgUtil;
# Utility functions for argument parsing
sub ______ArgUtil____ {} # For BBEdit Popup menu
###############################################################

sub unparse {
	# Usage:
	# &unparse(name, [{'val'=>'val1','type'=>'','group'=>'1'}, bool $name_only);
	#
	# Translates a record in ArgLayer format to texty hash format.

	my ($name, $record, $name_only) = @_;
	
	if ($name_only) {
		return ($name, $record->{'val'});
	} else {
		my $place = ($record->{place} ne '' ? "$record->{place}-" : '');
		my $group = ($record->{group} ne '' ? ".$record->{group}" : '');
		my $type  = $record->{type};
		
		return ("$place$name$group$type", $record->{'val'});
	}
}

sub parse {
	# Usage: @parameter_objects = $params->parse(@parameters_list);
	#
	# Translates a texty hash to ArgLayer format.

	# Given input of the type ('param1.1', 'val1', 'param2+', 'val2', ...),
	# returns output of the type ('param1', {val=>'val1', type=>'',  group=>'1', place=>''},
	#										'param2', {val=>'val2', type=>'+', group=>'',  place=>''}, 
	#                              ...),
	# which is the format of an ArgLayer.

	my ($type, $group, %output, $key, $val, $place);

	# The following characters can come at the end of a parameter name 
	# and signify something meaningful.  For instance:
	# 'date<' => '19960209' and 'date.1<' => '19960410'  each have the special_char '<'.
	# Special chars will show up in the 'type' field of each param.

	my $special_chars = '.<>+!~#';

	while (@_) {
		$key = shift @_;
		$val = shift(@_) . '';
		
		# Do the backslash un-quotation:
		$key =~ s/\\(.)/ &unescape($1) /eg;
		$val =~ s/\\(.)/ &unescape($1) /eg;
		
		next if $val eq '{ignore}';
		
		$place = $type = $group = undef;
      $place = $1  if  ($key =~ s/^(\w)-//);
      $type = $1  if  ($key =~ s/([$special_chars]*)$//);
      $group = $1  if  ($key =~ s/\.(\d+)$//);

		push (@{$output{$key}}, {val=>$val, type=>$type, group=>$group, place=>$place});
	}

	return %output;
}

sub parse_query_string {
	my $string = ( @_ ? shift : $ENV{'QUERY_STRING'} );
	return &parse( &url_unencode( split /[&=]/, $string ) );
}

sub parse_post {
	# Usage: @post = &parse_post;
	# Parses the query string and POSTed form input into key=value pairs.

	my (@returns, $raw_post);

	return () unless ($ENV{'REQUEST_METHOD'} eq 'POST');

	read(STDIN, $raw_post, $ENV{'CONTENT_LENGTH'});
	return &parse( &url_unencode( split /[&=]/, $raw_post ) );
}

sub parse_arg_string {
	my $string = shift;
	my @returns;

	$string =~ s/^\s+//;

	while ($string =~ m/
	     ([^\=]*)=												# the key
			(?:'([^\'\\]*  (?: \\.[^\'\\]* )* )'\s*	# quoted string, with possible whitespace inside
			|(\S*)\s*											# anything else, without whitespace
			)/gx) {

		push(@returns, $1, $+);

	}

	return &parse( @returns );
}

sub url_unencode {
	# Translate "the+stuff%21" to "the stuff!"
	my (@returns, $item);
	while (@_) {
		$item = shift;
		$item =~ tr/+/ /;
		$item =~ s/%(..)/pack('c',hex $1)/ges;
		
		push (@returns, $item);
	}
	return (wantarray ? @returns : $returns[0]);
}

sub url_encode {
	# Translate "the stuff!" to "the+stuff%21"
	my (@returns, $item);
	while (@_) {
		$item = shift;
		$item =~ s/([^\w \.])/ '%' . sprintf('%02X',ord $1) /ges;
		$item =~ tr/ /+/;
		
		push @returns, $item;
	}
	return (wantarray ? @returns : $returns[0]);
}

sub unescape {
	my $char = shift;
	if ($char eq 'n') {
		return "\n";
	} else {
		return $char;
	}
}

1;

__END__

=head1 NAME

Taco::Arg.pm - Taco argument management

=head1 SYNOPSIS

This module has three packages in it:

 Taco::ArgTable        -A class implementing a table of arguments
 Taco::ArgLayer        -A class implementing one layer in an ArgTable
 Taco::ArgUtil         -Utility functions for managing arguments

 # In a Taco tag's implementation function:
 my $flavor = $G::params->val('flavor');
 my $shoe_size = $G::params->val('shoe_size', 'my_func'); # Look only in the
                                                          # layer called "my_func"

=head1 DESCRIPTION

The Taco::Arg module contains classes that implement a table of arguments.
It's somewhat like a 2-dimensional hash.  Whenever you put a [[&tag(arg=value)]] in a
Taco template, Taco will parse the tag for you, put the arguments into the
ArgTable (the global ArgTable is $G::params), and then run your function.  While your
function is running, it has access to the $G::params object, which lets it get
or set parameters, insert new ArgLayers, etc.

=head1 The ArgTable Class

=over 4

=item * new Taco::ArgTable

Returns a new empty ArgTable object.

=item * $table->insert_layer

Puts a new empty ArgLayer in the table.  The first argument is the layer after which 
you want the new layer to appear.  The second argument, if present, is the
name of the new layer.  If the second argument is not present, a new name will
be invented.

Returns the name of the new ArgLayer.

=item * $table->new_temp(layer_name, key, value, key, value, ...)

Puts a new temporary layer in the ArgTable, right after the layer called layer_name.
This method returns an object of class Taco::ArgLayerName.  This is a special object -
when it goes out of scope, the layer associated with it will be deleted from the ArgTable.
Because the scoping of this object is so significant, calling $table->new_temp in a void
context (not assigning the result to a value) will cause Taco to die.  So don't do that.
If you don't want the layer to expire automatically, then you should probably use
$table->insert_layer instead.


=item * $table->exists(key)

Returns true if the given argument is the name of a key in the table.  Takes an optional list
of layers to look in.

=item * $table->set_arg(layer, key, value, key, value, ...)

Sets the given keys to the given values in the given layer.  See also ArgLayer::set_arg.

=item * $table->add_arg(layer, key, value, key, value, ...)

Adds the given keys, with the given values, to the given layer.  See also ArgLayer::add_arg.

=item * $table->layer_names

Returns the current list of layer names, in order of highest priority to lowest.

=item * $table->get_layer(layer_name)

Returns the ArgLayer object called layer_name.

=item * $table->set_layer(layer_name, layer)

Replaces the layer called layer_name with the given layer.  The table must already
have a layer called layer_name.

=item * $table->delete_layer(layer_name)

Deletes the layer called layer_name from the table.

=item * $table->layer_exists(layer_name)

Returns true if there is a layer called layer_name in the table.  See also C<exists>
to see whether a key exists in the table.

=item * $table->layer_containing(key)

Returns the name of the layer containing the given key, or undef if no layers
contain the given key.

=item * $table->keys

Returns a list of all the keys in the table.  Can take an optional list of layer
names, in which case all the keys in those layers are returned, in no particular
order.

=item * $table->show_me(verbose)

Prints the names of the layers in an ArgTable to STDERR, in order from highest
priority to lowest.  If the verbose argument is true, each layer's ->show_me 
method will also be called, so you'll see all the data in the ArgTable.

=item * $table->to_hash(names_only)

Returns the table's data in a list of key=>value pairs.  If names_only is true,
the keys returned will just be the names of the keys in the table.  Otherwise 
the keys will be of the form "param-flavor.3*+", where 'param' is the 'place',
'3' is the 'group', and '*+' is the type of the 'flavor' key.  If none of these
fancy things have values, setting the names_only flag will have no effect.

Not implemented yet.

=item * $table->to_query_string(names_only)

Similar to to_hash, but returns the data in the form of an URL query string.

Not implemented yet.

=item * $table->to_arg_string(names_only)

Similar to to_hash, but returns the data in the form of a template function
argument string.

Not implemented yet.

=head2

Simple Access methods

The following convenience methods can be used to look up table data more
easily. They all share two characteristics:  they take a key as input,
with an optional list of layers to look for the data in.  And they can
be called in either the singular or plural form (i.e. $table->val(key)
or $table->vals(key) ).  

When they are called in the singular form, they return a single scalar
value corresponding to the highest priority key of the given name.  When
they are called in the plural form, they return a list of scalars
corresponding to the values in the highest layer containing a key of the
given name.

All these routines return the undefined value if no layer contains the given
key.

=item * $table->val(key)

Looks up the key in the table and returns the value.  See also ArgLayer::val.

=item * $table->group(key)

Looks up the key in the table and returns the group.  See also ArgLayer::group.

=item * $table->type(key)

Looks up the key in the table and returns the type.  See also ArgLayer::type.

=item * $table->place(key)

Looks up the key in the table and returns the place.  See also ArgLayer::place.

=item * $table->get_arg(key)

Looks up the key in the table and returns a hash structure containing
the group, type, place, and value.  See also ArgLayer::get_arg.


=back

=head1 The ArgLayer Class

An ArgLayer is a layer in an ArgTable.  Here is its underlying data structure (don't assume
that this is the structure of %$layer if $layer is an ArgLayer object, but it will 
be in $layer somewhere).  This is provided for you as a conceptual aid.

 {'flavor' => [
      {
         'val' => 'vanilla',
         'type' => '*',
         'group' => '1',
         'place' => '',
      },
   
      {
         'val' => 'chocolate',
         'type' => '*',
         'group' => '1',
         'place' => 'param',
      },
      
      {
         'val' => 'strawberry',
         'type' => '*',
         'group' => '',
         'place' => '',
      },
   ],
 
 'color' => [
      {
         'val' => 'red',
         'type' => '*',
         'group' => '',
         'place' => '',
      },
   
      {
         'val' => 'blue',
         'type' => '*',
         'group' => '',
         'place' => '',
      },
   ],
 };

The entries for 'flavor' and 'color' will be referred to here as "nodes."


=head2 Methods

=over 4

=item * new Taco::ArgLayer

=item * new Taco::ArgLayer(%hash)

=item * new Taco::ArgLayer(@hash)

Returns a new ArgLayer object.  If a list is given as input, it will be taken as a list
of key-value pairs and used to create the ArgLayer.  In this case, &Taco::ArgUtil::parse will
parse the incoming data.


=item * $layer->dup()

Returns a copy of the ArgLayer object.  The data in the copy is not linked to the data in
the original, so if you change the data in one, the other will not be changed.


=item * $layer->exists( $key )

Returns a boolean value based on whether the given key exists in the ArgLayer.


=item * $layer->delete( $key )

Deletes all entries with the given name from the ArgLayer.


=item * $layer->get_args( $key )

Returns a list of all entries in the ArgLayer for the given key.

=item * $layer->get_arg( $key )

Same as $layer->get_args, but returns a scalar, which is the last element called
C<$key> in the ArgLayer.



=item * $layer->set_arg('name', 'value', name, value, ...)

=item * $layer->set_arg('name', {val=>...}, name, value, ...)

Sets the values of the given keys in the ArgLayer.  Clears all args in this layer with these names!
The named nodes don't have to exist already.  See also add_arg() and merge().



=item * $layer->add_arg('name', 'value', name, value, ...)

=item * $layer->add_arg('name', {val=>...}, name, value, ...)

Adds these args to the end of this layer's given nodes.   There don't have to be
nodes with these names already.  See also set_arg() and merge().



=item * $layer->merge( $layer2 )

Pushes the contents of the ArgLayer $layer2 into $layer.  The data in $layer2 will be
put at the end of each node of $layer.


=item * $layer->keys()

Returns a list containing the names of all the keys in the layer, in no particular order.

=item * $layer->each()

Similar to Perl's C<each> function for iterating over hashes, you can use it like this:

 while (($key, $value) = $layer->each) {
    # $key is a string
    # $value is a list of hashes
 }


=item * $layer->show_me()

Prints a representation of the data in an ArgLayer to STDERR.  

=item * $layer->to_hash( $name_only )

Returns the layer's data in a list of key-value pairs.  If names_only is true,
the keys returned will just be the names of the keys in the table.  Otherwise 
the keys will be of the form "param-flavor.3*+", where 'param' is the 'place',
'3' is the 'group', and '*+' is the type of the 'flavor' key.  If none of these
fancy things have values, setting the names_only flag will have no effect.


=item * $layer->to_query_string( $name_only

Similar to to_hash, but returns the data in the form of an URL query string.

Not implemented yet.

=item * $layer->to_arg_string(names_only)

Similar to to_hash, but returns the data in the form of a template function
argument string.

Not implemented yet.


=item * $layer->val('flavor')

=item * $layer->group('flavor')

=item * $layer->type('flavor')

=item * $layer->place('flavor')

Documentation not written yet, see also C<$ArgTable->val('flavor')>, etc.  It's very similar.


=head1 The ArgUtil Functions

All these functions are in the namespace Taco::ArgUtil.  For example, you'd call
the C<unparse> function by doing C<&Taco::ArgUtil::unparse(...)>

=over 4

=item * unparse(name, ref, name_only)

The inverse of &Taco::ArgUtil::parse, unparse translates a node in an ArgLayer to texty-hash format.

 name        - a string, the name of the node.
 ref         - a data structure in the format described below.
 name_only   - a boolean value: if true, omits the group, type, and place 
               information in the returned hash.  Prints all info by default.

The 'ref' argument must be a reference to a list of hash references:

 $ref = [
    {'val' => 'beans',
     'group' => '3',
     'type'  => '*+',
     'place' => 'param',
    },
 
    {'val' => 'cheesecake',
     'type'  => '~',
    },

    {'val' => 'cheezo',
    },
 ];
 
 %hash = &Taco::ArgUtil::unparse('food', $ref);
 # Returns ('param-food.3*+' => 'beans', 'food~' => 'cheesecake', 'food' => 'cheezo').

=item * parse(name, ref, name_only)

=item * parse_query_string

=item * parse_post

=item * parse_arg_string

=item * url_unencode

Translates "the+stuff%21" to "the stuff!"

=item * url_encode

Translates "the stuff!" to "the+stuff%21"


=back

=head1 AUTHOR

Ken Williams (ken@forum.swarthmore.edu)

Copyright (c) 1998 Swarthmore College. All rights reserved.

=cut
