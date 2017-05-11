package TAPP::WebService::CSM::WSDL::Interface;
{
  $TAPP::WebService::CSM::WSDL::Interface::VERSION = '0.003';
}
use strict;
#===================================================================================================
# TAPP/WebService/CSM/WSDL/Interface.pm
#
# JSON-based WSDL interface to CSM web services
#
# Auth: achjo03, 10/11/15
#
#===================================================================================================
use base qw(Class::Accessor);

use Carp;
use TAPP::Datastructure::Utils qw/:all/;
use JSON::XS;
my $json = JSON::XS->new->allow_nonref;
use Try::Tiny;
use TAPP::Exception;

use constant WSDL_INSTANCE_VARS =>
    qw/
        method
        object
        key
        wsdl_definition
        has_ccti    
    /;
    
use constant SPEC_INSTANCE_VARS =>
    qw/
        ccti_class
        ccti_category
        ccti_type
        ccti_item
        bean
        translate_labels
        default_values
        attributes
        custom_attributes
        required_fields
        filter_fields
        filtered_out
        payload
    /;
__PACKAGE__->mk_accessors( SPEC_INSTANCE_VARS(),WSDL_INSTANCE_VARS() );

#
#  new ( LIST )
#  Instantiate and optionally receive the payload spec()
#  Spec is described below.
#
sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $self = {};
    bless $self, $class;
    my $caller = (caller(0))[3];
    if (@_) {
        my %args = make_hash(@_) or do {
            throw TAPP::IllegalArgumentException( "Unexpected argument list arguments in call to $caller()" ); 
        };
        $self->wsdl( $args{wsdl} ) if $args{wsdl};
        if (defined $args{spec} && ! defined $args{wsdl}) {
            throw TAPP::WebService::CSM::WSDLDefException( "Spec defined without wsdl in call to $caller()" );
        }
        $self->spec( $args{spec} ) if $args{spec};
    }
    $self;
}

#
#  spec ( LIST )
#  Applies the user-defined payload specification, specification
#  options are defined below in the "build_payload()" section
#
sub spec {
    my $self = shift;
    my $caller = (caller(0))[3];
    my %args = make_hash(@_) or do {
        throw TAPP::IllegalArgumentException( "Unexpected argument list arguments in call to $caller()" ); 
    }; 
    foreach my $prop ( SPEC_INSTANCE_VARS(), 'ccti' ) {
        if ( exists $args{$prop} ) {
            $self->$prop( $args{$prop} );
        }
    }
    $self->clear();
  1;
}
#
# sub wsdl { file => '' }
# sub wsdl { json_string => SCALAR }
# sub wsdl { ref => HASHREF|ARRAYREF }
#
#  Populate wsdl. Receives a file containing a JSON wsdl, 
#  a json string, a hashref, or an arrayref
# 
sub wsdl {
    my $self = shift;
    my $caller = (caller(0))[3];
    my %args = make_hash(@_) or do {
        throw TAPP::MissingArgumentsException( "Missing arguments in call to $caller()" ); 
    };
    my $file            = $args{file};
    my $wsdl_definition = $args{ref};
    my $json_string     = $args{json};
    
    # If file supplied, import wsdl json content from file
    if ( defined $file ) {
        unless ( -f $file ) {
            throw TAPP::FileNotFoundException( "WSDL file does not exist or is not accessible in call to $caller(): $file $!" ); 
        }
        if ( open(my $fh, "<", $file) ) {
            my @t = (<$fh>);
            chomp(@t);
            $json_string = join "\n", @t;
        } else {
            throw TAPP::FileIOException(  "Failed to open wsdl file for read in call to $caller(): $file $!" );
        }
    }
    
    # Convert json to ref
    if ($json_string) {
        try {
            $wsdl_definition = $json->decode( $json_string );
        } catch { 
            throw TAPP::JSONDecodeException("Unexpected error decoding WSDL json content: $_");
        };
    }
    
    # verify spec captured..
    unless ( defined $wsdl_definition && ref( $wsdl_definition) =~ /HASH|ARRAY/) {
        throw TAPP::WebService::CSM::WSDLDefException(
              "Unexpected error, WSDL spec not found in call to $caller()" 
         );
    }
    
    # If spec is arrayref, convert to hashref
    if ( ref( $wsdl_definition ) eq 'ARRAY' ) {
        $wsdl_definition = shift @$wsdl_definition;
    } elsif ( ref( $wsdl_definition ) ne 'HASH' ) {
         throw TAPP::WebService::CSM::WSDLDefException(
              "Spec is neither a hashref nor an arrayref in call to $caller()" 
         );
    }
    
    # Store the wsdl specification hashref
    $self->wsdl_definition( $wsdl_definition );
    # Generate a unique key idenitfier for this wsdl
    $self->key( $wsdl_definition->{object}. "_" . $wsdl_definition->{method} );
    $self->object($wsdl_definition->{object});
    $self->method($wsdl_definition->{method});
    # Parse attributes
    $self->attributes( $wsdl_definition->{attributes} );
    1;
}
#
# attributes ( HASHREF|ARRAYREF )
#
#   Collect attributes from WSDL, extract bean
#   into bean() if found.
#   The final attributes value will be ARRAYREF
#
sub attributes {
    my $self = shift;
    return $self->{attributes} unless @_;
    my $attributes = shift;
    my $list = $attributes;
    my $bean;
    
    # Remove the attributes from a bean hash if needed
    # and store the bean
    if (ref($attributes) eq 'HASH') {
        ($bean,$list) = each %{$attributes};
        $self->bean($bean);
    }
    # Flag that this wsdl has ccti attributes
    my ($has_ccti) = grep { /^ccti_class$/i } @$list;
    $self->has_ccti( defined $has_ccti || 0 );
    $self->{attributes} = $list;
    $self->{attributes}
}
#
# build_payload ( HASHREF )
# 
#   Builds a payload datastructure from incoming hashref data.
#   Optionally applying any of the the following transformations and rules:
#
#      - filter_fields:    Removes any fields not in this list
#      - required_fields:  Croaks on any required field not found in the
#                          dataset
#      - default_values:   Provides empty fields, with default values when
#                          defined
#      - ccti:             If a wsdl interface requires CCTI, throw an error if
#                          at least ccti_class is not defined
#      - translate_labels: Remaps field labels (hashref keys)
#      - bean:             Encloses payload into a bean if defined
#
#
##
###
sub build_payload {
    my $self = shift;
    return $self->{payload} unless @_;
    $self->{payload} = {};
    my $caller = (caller(0))[3];
    my $data = make_hash(@_) or do {
        throw TAPP::IllegalArgumentException( "Expected HASH in call to $caller()" ); 
    };
      
    # Dereference data for internal mungification
    my %ldata = %$data;
    my @attributes = @{ $self->attributes() };
    my %attr_lookup = map { $_ => 1 } @attributes;
    
    # Filter out unwanted fields
    my @filtered_out;
    my $filter_fields = $self->filter_fields;
    if (defined $filter_fields && ref($filter_fields) eq 'ARRAY'
          && scalar @$filter_fields > 0) {
        my %flookup = map { $_ => 1 } @$filter_fields;
      
        foreach ( keys %ldata ) {
            unless ( $flookup{$_} ) {
                delete $ldata{$_};
                push @filtered_out, $_;
            }
        }
      
        # Store filtered-out keys for debug
        $self->filtered_out( \@filtered_out )
          if scalar @filtered_out;
    }
  
    # Error on required fields
    my $required_fields = $self->required_fields();
    if (defined $required_fields && ref($required_fields) eq 'ARRAY'
          && scalar @$required_fields > 0) {
        my %rlookup = map { $_ => 1 } @$required_fields;
        foreach ( keys %rlookup ) {
            throw TAPP::IllegalStateException( "Required field not found: $_" )
              unless $ldata{$_}
        }
    }
    
    # Re-map any hash keys to proper wsdl attributes
    my $translate_labels = $self->translate_labels();
    if (defined $translate_labels && ref($translate_labels) eq 'HASH'
          && scalar keys %$translate_labels > 0 ) {
        foreach ( keys %ldata ) {
            next unless exists $translate_labels->{$_};
            my $val = $ldata{$_};
            my $k = $translate_labels->{$_};
            $ldata{$k} = $val;
            delete $ldata{$_};
        }
    }
    # Add CCTI to payload if required
    if ( exists $attr_lookup{'ccti_class'} && ! defined $ldata{ccti_class} ) {
        # If no local or global CCTI is passed, and the wsdl interface requires it, then
        # raise an exception
        unless( $self->ccti_class() || $ldata{ccti_class}) {
            throw TAPP::WebService::CSM::WSDLSelectException(
                "Cannot process record without CCTI Class definition" 
            );
        }
        $self->ccti_class()    && do { $ldata{ccti_class}    = $self->ccti_class()};
        $self->ccti_category() && do { $ldata{ccti_category} = $self->ccti_category()};
        $self->ccti_type()     && do { $ldata{ccti_type}     = $self->ccti_type()};
        $self->ccti_item()     && do { $ldata{ccti_item}     = $self->ccti_item()};
    }
    # Capture custom attributes
    my @custom_attributes;
    foreach ( keys %ldata ) {
        next if exists $attr_lookup{$_};
        push @custom_attributes,
          { custom_attributes => [
              { attribute_name  => $_ },
              { attribute_value => $ldata{$_} },
            ],
          };
      delete $ldata{$_};
    }
    # store custom attributes for debug
    $self->custom_attributes( \@custom_attributes ) if scalar @custom_attributes;
    
    # Load payload content
    my @payload;
    my $default_values = $self->default_values();
  
    foreach my $a ( @attributes ) {
        # First, populate payload with default value if provided
        push @payload, { $a => $default_values->{$a} } 
             if exists $default_values->{$a} && defined $default_values->{$a};
             
        # Second, populate payload with user-defined value
        push @payload, { $a => $ldata{$a} } if exists $ldata{$a} && defined $ldata{$a};
        # Third, populate custom field value which is an inner array
        if ( $a eq 'custom_attributes' ) {
           push @payload, @custom_attributes;
        }
    }
    # Encapsulate into bean if needed
    my $bean = $self->bean() if $self->bean && length( $self->bean ) > 1;
    if ($bean) {
        $self->{payload} = [{ $bean => [@payload] }];
    } else {
        $self->{payload} = [@payload];
    }
    # Return payload
    $self->{payload};
}

#
# ccti ( SCALAR )
#
#   Set the GLOBAL CCTI values, if not populated in the build_payload() call dataset
#   Acts as default value until changed or overriden
# 
sub ccti {
    my $self = shift;
    return $self->{ccti} unless @_;
    my $ccti = shift;
    $self->{ccti} = $ccti;
    # Split up CCTI into respective 4 parts
    $ccti =~ s/^[\s\/]*(.*)/$1/;
    $ccti =~ s/[\s\/]*$//;
    my($cl,$ca,$t,$i) = split "/", $ccti;
    # Store CCTI parts
    $self->ccti_class(undef);
    $self->{$_} = undef foreach qw/ccti_class ccti_category ccti_type ccti_item/;
    $self->ccti_class($cl);
    $self->ccti_category($ca) if defined $ca;
    $self->ccti_type($t) if defined $t;
    $self->ccti_item($i) if defined $i;
    $self->{ccti};
}
#
# to_string ()
#
#   Print all rules, transformations, and dataset
#
sub to_string {
    my $self = shift;
    my $out = '';
   
    $out .= "WSDL: \n";
    $out .= "-------------------------------------------------------------------------------------\n";
    $out .= $json->pretty->encode( $self->wsdl_definition() || '');
    $out .= "\n";
    
    $out .= "Attributes: \n";
    $out .= "-------------------------------------------------------------------------------------\n";
    $out .= $json->pretty->encode( $self->attributes || [] );
    $out .= "\n";
      
    $out .= "Translate labels: \n";
    $out .= "-------------------------------------------------------------------------------------\n";
    $out .= $json->pretty->encode( $self->translate_labels || {}  );
    $out .= "\n";
    
    $out .= "Default Values: \n";
    $out .= "-------------------------------------------------------------------------------------\n";
    $out .= $json->pretty->encode( $self->default_values || {} );
    $out .= "\n";
  
    $out .= "Require Fields: \n";
    $out .= "-------------------------------------------------------------------------------------\n";
    $out .= $json->pretty->encode( $self->required_fields  || [] );
    $out .= "\n";
    
    $out .= "Filter Fields: \n";
    $out .= "-------------------------------------------------------------------------------------\n";
    $out .= $json->pretty->encode( $self->filter_fields  || [] );
    $out .= "\n";  
  
    $out .= "Filtered out keys: \n";
    $out .= "-------------------------------------------------------------------------------------\n";
    $out .= $json->pretty->encode( $self->filtered_out  || [] );
    $out .= "\n";
    
    $out .= "Custom Attributes: \n";
    $out .= "-------------------------------------------------------------------------------------\n";
    $out .= $json->pretty->encode( $self->custom_attributes  || {} );
    $out .= "\n";
    
    $out .= "-------------------------------------------------------------------------------------\n";
    $out .= "Bean: ". ($self->bean || 'undef') . "\n";
    $out .= "-------------------------------------------------------------------------------------\n";
    $out .= "\n";
    
    $out .= "Global CCTI: \n";
    $out .= "-------------------------------------------------------------------------------------\n";
    $out .= "  CCTI Class: ".    ($self->ccti_class    || 'undef' ) . "\n";
    $out .= "  CCTI Category: ". ($self->ccti_category || 'undef' ) . "\n";
    $out .= "  CCTI Type: ".     ($self->ccti_type     || 'undef' ) . "\n";
    $out .= "  CCTI Item: ".     ($self->ccti_item     || 'undef' ) . "\n";
    $out .= "\n";
    
    $out .= "Payload: \n";
    $out .= $json->pretty->encode( $self->payload() || {} );
    $out .= "\n";
    
    $out;
}
#
# clear ()
# 
#   Clears the payload, preserving the parsing options
# 
sub clear { my $self = shift; undef $$self{payload} }

1;


