package TAPP::Datastructure::Utils;
{
  $TAPP::Datastructure::Utils::VERSION = '0.001';
}
use strict;
use TAPP::Exception;
=pod

=head1 TAPP::Datastructure::Utils

Subroutines to eliminate common and verbose datastructure tests and conversion routines

=head1 Synopsis
                    
    use TAPP::Datastructure::Utils qw/:var_utils/;
    # -or-
    use TAPP::Datastructure::Utils qw/:dumper_utils/;
    # -or-
    use TAPP::Datastructure::Utils qw/:all/;
    # -or for individual utils-
    use TAPP::Datastructure::Utils qw/make_hash/;
    
    
    # Var utilities ---------------------------
    
    # Safely convert an array to hash or hashref
    my %hash = make_hash( @ARGV ) or
      die "Failed to create hash";   # An exception object is thrown, see TAPP::Exception
                                     # on how to handle and use the exception object
                                     
    
    # Require that a hash has keys (exists)
    my @keys = ('foo','bar');
    my %hash = ( foo => 1, baz => 2 );
    die "Expected keys not found in hash"
      unless exists_keys( \%hash, \@keys );
    
    # Require that a hash has keys (defined)
    die "Expected keys not found or not DEFINED in hash"
      unless defined_keys( \%hash, \@keys );
    
    # Test if a list is 'hashable'. Optionally allow or disallow duplicate keys
    if ( is_hashable_list( @_ ) ) {         # Returns undef and populates 'error' if duplicate
      %args = (@_)                          # keys found
    }
    # Try this to allow duplicate key/val pairs to overwrite: 
    if ( is_hashable_list( @_, allow_duplicate_keys => 1 ) { 
      print "hashable, but some values will get clobbered!"
    }
    
    # Instead of the somewhat obscure...
    if ( ref($var) eq 'ARRAY' ) {
      # do stuff
    }
    # Try this:
    if ( is_arrayref( $var ) ) {
      # do stuff
    }
    
    # Check if your keys are contained in a HASH(REF):
    print "has expected keys" if is_href_with_keys( \%HASH, keys => ['foo','bar','baz'] );
    
    # And whether the keys have defined values:
    print "has expected keys with defined values"
      if is_href_with_defined_keys( \%HASH, keys => ['foo','bar','baz'] );
    
    # Or test that it is not only a 'type' of var, but that it has a value, or a particular key
    my $populated_ref = non_empty_ref( 
    
    
    # Dumper utilities ---------------------------
    # Obviously using the perl debugger is the ideal way of debugging perl scripts and analyzing
    # data structures, but often times you just need to get-in and get-out. Here are a couple
    # routines to help with this.
    
    # Instead of:
    use Data::Dumper qw/Dumper/;
    print Dumper( $REF ), "\n";
    
    # Try this:
    dd ( $REF );
    
    # Or dump the data and immediately exit:
    de ( $REF );
    
=head1 Description

This module contains 3 categories of datastructure handling utilities.


1. Data transformation: Conversion of list-based data types to a HASH data type with C<make_hash>

2. Data inspection: While perl is not a typed-language, tell that to the compiler if you try to
autovivicate a GLOB! :-) Sub-routines such as C<is_hashref> or C<non_empty_ref> will help to determine
the type of data structure, whether it is not empty, whether it is a hash or hash ref with a
particular key, or even if it is a hash with a key and a defined value, amoung other tests.

3. Debugging data: Short-hand utilities such as C<dd> and C<de> can be used for validating
datastructures as a debugging tool, since they're simply shortcuts to Data::Dumper::Dumper.


=head1 Methods

=cut


use parent 'Exporter';
use List::Util qw/pairmap all/;
our @VAR_UTILS = qw/
                    make_hash
                    make_arrayref
                    defined_keys
                    exists_keys
                    hashable_list
                    is_non_empty_ref
                    is_non_empty_hashref
                    is_non_empty_arrayref
                    is_arrayref
                    is_hashref
                    is_coderef
                    is_nonref_scalar
                    is_href_with_keys
                    is_href_with_defined_keys
                  /;
our @DMP_UTILS = qw/dd de/;
our @EXPORT_OK = (@VAR_UTILS,@DMP_UTILS);

our %EXPORT_TAGS = (
	var_utils    => [@VAR_UTILS],
	dumper_utils => [@DMP_UTILS],
  all          => [@EXPORT_OK],
);

our $error = '';

=pod

=head2 make_hash( * )

Convert a HASHREF, even-sized ARRAYREF, even-sized ARRAY, or empty LIST to HASH. This function is a
non-op if already a HASH.


  sub my_sub {
    my %args = make_hash(@_) or die "my_sub: Expected a hash!";
  }

  sub my_sub {
    my @args = @_;
    my %args;
    if ( scalar @args ) {
      if ( @args % 2 == 0 ) {
        %args = (@args);   # but is it really a hash? what if there are duplicate keys?
                           # what if the @args is (undef,undef) ? 
      } elisf (
        %args = ref( $args[0] ) eq 'HASH' # what if there are multiple values in @args?
                ? %{$args[0]} : ();
      }
      ...
    }
  }

Returns HASH or HASHREF depending on context

  my $hashref_wanted = make_hash( @_ ); # valid, returns a hashref instead
  my %hash_wanted = make_hash ( @_ );   # valid, returns hash
  
Empty lists are not allowed. This could be a good thing, or a bad thing, depending
on your needs. It would be a good way to check for empty lists.
  
  # These will die
  my %hash = make_hash( [] )
    or die $TAPP::Datastructure::Utils::error;
    
  my %hash = make_hash( {} )
    or die $TAPP::Datastructure::Utils::error;
    
  my %hash = make_hash()
    or die $TAPP::Datastructure::Utils::error;
    
  my %hash = make_hash( {}, allow_duplicate_keys => 1 )
    or die $TAPP::Datastructure::Utils::error;
    
  my %hash = make_hash( [], allow_duplicate_keys => 0 )
    or die $TAPP::Datastructure::Utils::error;
      
Options:

=over 4

=item allow_duplicate_keys => [1|0]

=over 4

Default 1. Allows list to contain duplicates in the 'key' position. When duplicated, the
value is set to the last assignment given in the list.

  my @list = ('foo',1,'bar',2,'bar',3);
  my %hash = make_hash(@list, allow_duplicate_keys => 1);
  print "$_ => $hash{$_} " foreach keys %hash;
  # will print 'foo => 1, bar => 3'

NOTE: If the first argument is a hashref, then duplicate keys are always allowed, since
since an anonymous hashref resolves duplicate keys at runtime before make_hash()
is called.
     
=back  

=back

=cut

sub make_hash {
  $error = '';
  
  my $caller = (caller(0))[3];
  my @list = @_;
  my @allow_dupes = ('allow_duplicate_keys',1);
  if (defined $list[$#list-1] && $list[$#list-1] eq 'allow_duplicate_keys') {
    @allow_dupes = splice(@list,-2);
  }
  my $first_arg = $list[0];
  # Convert refs to list
  {
    local $_ = ref($first_arg);
    @list =   defined $_ && /HASH/
            ? (%$first_arg)
            : defined $_ && /ARRAY/
            ? @$first_arg
            : @list;
  } 
  # Empty list
  if ( scalar @list == 0 ) {
    return;
    #throw TAPP::MissingArgumentsException( "Empty list in call to $caller()" ); 
  # Odd number of elements
  } elsif ( scalar @list % 2 != 0 ) {
    return;
    #throw TAPP::IllegalArgumentException( "Odd number of elements in call to $caller()" ); 
  } 
  # Check if hashable
  unless (is_hashable_list(@list, allow_duplicate_keys => 1)) {
    return;
    #throw TAPP::DatatypeConversionError( "Not a hashable list in call to $caller()" ); 
  }
  # Evaluate dulicate key rule
  unless ( is_hashable_list(@list,@allow_dupes) ) {
    return;
    #throw TAPP::DuplicateKeysException( "Duplicates not allowed in call to $caller()" ); 
  }
  my %hash = (@list) or return undef;
    #or throw TAPP::DatatypeConversionError( "Failed to convert list to hash, in call to $caller()" ); 
  wantarray()? %hash : \%hash
}


=pod

=head2 exists_keys ( HASHREF, ARRAYREF )

Returns true if all of the values in the arrayref exists as
keys in the hashref

  sub qux {
    my %args = (@_);
    my @required_args = ('foo','baz','bar');
    die "Required arguments missing in call to qux()"
      unless exists_keys( \%args, \@required_args );
  }

=cut

sub exists_keys {
  $error = '';
  my $caller = (caller(0))[3];
  my ($href,$aref) = @_;
  unless ( is_hashref($href)) {
    throw TAPP::IllegalArgumentException( "First argument must be a hashref in call to $caller()" ); 
  }
  unless ( is_arrayref($aref) ) {
    throw TAPP::IllegalArgumentException( "Second argument must be an arrayref in call to $caller()" ); 
  }
  return all { exists $href->{$_} } @$aref;
}


=pod

=head2 defined_keys ( HASHREF, ARRAYREF )

Returns true if all of the values in the arrayref exists as
keys in the hashref, and have defined values

  sub qux {
    my %args = (@_);
    my @required_args = ('foo','baz','bar');
    die "Required arguments missing in call to qux()"
      unless defined_keys( \%args, \@required_args );
  }

=cut

sub defined_keys {
  $error = '';
  my $caller = (caller(0))[3];  
  my ($href,$aref) = @_;
  unless ( is_hashref($href)) {
    throw TAPP::IllegalArgumentException( "First argument must be a hashref in call to $caller()" ); 
  }
  unless ( is_arrayref($aref) ) {
   throw TAPP::IllegalArgumentException( "Second argument must be an arrayref in call to $caller()" ); 
  }
  return all { defined $href->{$_} } @$aref;
}

=pod

=head2 is_hashable_list( *, allow_duplicate_keys => [1|0] )

Determines if the argument list is a hashable even pair list, optionally with no duplicate keys

  if ( is_hashable_list( @unknown_stuff ) ) {
    my %trusted_hash = (@unknown_stuff);
    ...
  }

Options:

=over 4

=item allow_duplicate_keys => [1|0]

=over 4

Default 0. Specify wheteher to allow LIST to contain duplicates in the 'key' position

  my @list = ('foo',1,'bar',2,'bar',3);
  if ( is_hashable_list(@list, allow_duplicate_keys => 1) ) {
    print "Its hashable, but bar => 2 got clobbered by bar => 3";
  }
     
=back  

=back

=cut

sub is_hashable_list {
  $error = '';
  my @list = @_;
  # hashable if empty
  return 1 if scalar @list == 0;
  # not hashable if uneven
  return unless scalar @list % 2 == 0;
  
  my $allow_dupes = 0;
  if (defined $list[$#list-1] && $list[$#list-1] eq 'allow_duplicate_keys') {
    (undef,$allow_dupes) = splice(@list,-2);
  }

  my $expected = scalar @list / 2;
  my %hash = pairmap { $a => $b } @list;
  # not hashable if dupe keys
  return if ! $allow_dupes && $expected > scalar keys %hash;
  while ( my ($k,$v) = each %hash ) {
    return unless defined $k;
    return if ref( $k );
  }
  1;
}


=pod

=head2 is_non_empty_ref( * )

Determines if the argument list contains one and only one populated HASH or ARRAY reference.
Occasionally useful if you're testing for ref type and need to 'do something' if no data is
contained in the data structure

Provides this:
  
  print "Contains a ref with data\n" if is_non_empty_ref( @_ );

Which is arguably easier to read than:
  
  if ( ref( $_[0] ) && ( ref( $_[0] ) eq 'HASH' && scalar keys %{$_[0]} )
                         || ref( $_[0] ) eq 'ARRAY' && scalar @{$_[0]} ))
  {
    print "Contains a ref with data\n" 
  }

=cut

sub is_non_empty_ref { $error = ''; is_non_empty_hashref( @_ ) || is_non_empty_arrayref ( @_ ) }



=pod

=head2 is_non_empty_hashref( * )

Same as C<is_non_empty_ref()>, except only true if argument is HASHREF

  print "Its a hashref and not empty\n" if is_non_empty_hashref(@_);

=cut

sub is_non_empty_hashref { $error = ''; is_hashref(  $_[0] ) && scalar keys %{$_[0]}  }


=pod

=head2 is_non_empty_arrayref( * )

Same as C<is_non_empty_ref()>, except only true if argument is ARRAYREF

  print "Its an arrayref and not empty\n" if is_non_empty_arrayref(@_);

=cut

sub is_non_empty_arrayref { $error = ''; is_arrayref( $_[0] ) && scalar @{$_[0]} }


=pod

=head2 is_non_empty_list( * )

Same as C<is_non_empty_ref()>, except fails if the argument is a REF, since
it is looking for a LIST or dereferenced LIST. This is not necessarily
a functional shortcut, but rather a 'readability' enhancement

Provides this:

  print "It's a LIST with a value\n" if is_non_empty_list(@_);
  
Which is marginally easier to read for novices than:

  print "It's a LIST with a value\n" if scalar @_ > 0

=cut

sub is_non_empty_list { $error = ''; scalar @_ > 0 }


=pod

=head2 is_arrayref( * )

Tests if first argument of a list is an arrayref

Provides this:

  my $array = shift if is_arrayref( @_ );
  
Instead of this:

  my $array = shift if defined $_[0] && ref( $_[0] ) eq 'ARRAY';

=cut


sub is_arrayref { $error = ''; defined $_[0] &&   ref( $_[0] ) eq 'ARRAY'   }


=pod

=head2 is_hashref( * )

Same as C<is_arrayref> for hashrefs

Provides this:

  my $href = shift if is_hashref( @_ );
  
Instead of this:

  my $href = shift if defined $_[0] && ref( $_[0] ) eq 'HASH';

=cut


sub is_hashref  { $error = ''; defined $_[0] &&   ref( $_[0] ) eq 'HASH'   }


=pod

=head2 is_coderef( * )

Same as C<is_arrayref> for code refs

Provides this:

  $sub->() if is_coderef( $sub );
  
Instead of this:

  $sub->() ref( $sub ) eq 'CODE';

=cut


sub is_coderef { defined $_[0] &&   ref( $_[0] ) eq 'CODE'  }


=pod

=head2 is_nonref_scalar( * )

Check if argument contains one value and is a SCALAR that is not a ref

Provides this:

  my $nonref = shift if is_nonref_scalar( @_ );
  
Which is slightly easier to read than:

  my $nonref = shift if scalar @_ == 1 && ! ref( $_[0] );

=cut


sub is_nonref_scalar {
          $error = '';
             scalar @_ == 1
          && ! ref( $_[0] )
        }


=pod

=head2 is_href_with_defined_keys( HREF, keys => [SCALAR,SCALAR...] )

Same as C<is_href_with_keys>, except the values are expected to be defined

Given:

  my $href = { foo => 1, bar => undef, qux => 3 };
  
Provides this:

  print "All key pairs exist and are defined\n"
    if is_href_with_defined_keys( $href, keys => ['foo','qux'] );
  
And would die if all are not defined (returns undefined when): 

  die "Some key pairs do not exist or are not defined\n"
    unless is_href_with_defined_keys( $href, keys => ['foo','bar'] ); # 'bar' not defined

  
Which is arguably easier to read than:
  die "Some key pairs do not exist or are not defined\n"
    unless ref( $href ) eq 'HASH'
      && scalar keys %$href == grep { defined $href->{$_} } qw/foo bar/;
  
  
=cut

sub is_href_with_defined_keys { $error = ''; __hash_key_check( 'defined', @_ ) }


sub __hash_key_check {
  $error = '';
  local $_ = shift; # defined or exists
	return undef unless ref( $_[0] ) eq 'HASH';
  my $hashref = shift @_;
	# key should be the last value in the array
	my $keysarray;
  (undef,$keysarray) = splice @_,-2;
	# get rid of the 'key' arg
	return undef unless ref( $keysarray ) eq 'ARRAY' && scalar @$keysarray;
  my $wanted = scalar @$keysarray;
  my $got    = /defined/ ?  +( grep { defined $hashref->{$_} } @$keysarray ) :
               /exists/  ?  +( grep { exists $hashref->{$_} } @$keysarray ) :
               -1;
  $wanted == $got;
}


=pod

=head2 is_href_with_keys( HASHREF, keys => [SCALAR,SCALAR,...] )

Check the first argument is a hashref with one or many existant key names, regardless of whether
keys point to defined values

Given:

  my %hash = ( foo => 1, qux => undef );
  
Provides this:

  print "All key pairs exist\n"
    if is_href_with_keys( \%hash, keys => ['foo','qux'] );
  
And would die if any do not exist (returns undefined when): 

  die "Some key pairs do not exist\n"
    unless is_href_with_keys( \%hash, keys => ['foo','bar'] ); # 'bar' does not exist

  
Which is arguably easier to read than (a bit contorted for fit this example):
  my $href = \%hash;
  die "Some key pairs do not exist\n"
    unless ref( $href ) eq 'HASH'
       && scalar keys %$href == grep { exists $href->{$_} } qw/foo bar/;
  
  
=cut


sub is_href_with_keys {$error = ''; __hash_key_check( 'exists', @_ ) }

sub make_arrayref {
    my @thing = @_;
    return $thing[0] if ref( $thing[0] ) eq 'ARRAY';
    return [@_];
}




#####-----------------------------------------------------------------------------------------------
#     sub dd, sub de
#     -----------------------------
#        Short-hand utilities for easy printing of data dumper calls during debugging 
##       These are not used in production code, only for development use.
##       Returns nothing, these functions print datastructures to STDOUT
###     
#####-----------------------------------------------------------------------------------------------
use Data::Dumper qw/Dumper/;




=pod

=head2 dd( LIST )

Short-hand to quickly dump variables when debugging

Provides this:

  dd \@array, \%hash;
  
Instead of this:
  
  print Data::Dumper::Dumper( \@array ), "\n";
  print Data::Dumper::Dumper( \%hash ), "\n";
  etc...
  
=cut

# Short-hand dumper
sub dd  { $error = ''; print Dumper( @_ ) }


=pod

=head2 de( LIST )

Short-hand to quickly dump variables when debugging, then break/exit immediately
after

Provides this:

  de \@array, \%hash;
  
Instead of this:
  
  print Data::Dumper::Dumper( \@array ), "\n";
  print Data::Dumper::Dumper( \%hash ), "\n";
  etc...
  
  exit;
  
=cut

# Short-hand dumper and exit
sub de { $error = ''; dd( @_ ); exit }

=pod
 
=head1 Author

John Achee E<lt>jrachee@gmail.comE<gt>

=head1 TODO

More useful data conversion and autovivication tests

Additional debugging shortcuts beyond Data::Dumper

Optional usage of Data::Dump if installed

=head1 Bugs

None reported at this time

=head1 See Also

L<Data::Dumper>

=cut


1;



