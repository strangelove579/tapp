package TAPP::WebService::CSM::WSDL::Autoload;
{
  $TAPP::WebService::CSM::WSDL::Autoload::VERSION = '0.003';
}
use strict;
#===================================================================================================
# TAPP/WebService/CSM/WSDL/Autoload.pm
#
# WSDL-esque interface to CSM web services
#
# Auth: achjo03, 10/11/15
#
#===================================================================================================
use parent qw/TAPP::WebService::CSM/;
use TAPP::WebService::CSM::WSDL::Interface;
use TAPP::Datastructure::Utils qw/:all/;
use TAPP::Exception;


#
# new ( HASH )
#
#   connection arg is required.
#   connection is passed to SUPER ( TAPP::Webservice::CSM )
#   wsdl interface and spec optional, passed to add_wsdl_interface()
#
sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $self = {};
    my $caller = (caller(0))[3];
    my %csm_args = ();
    my %args = make_hash(@_) or do {
        throw TAPP::IllegalArgumentException( "Unexpected argument list arguments in call to $caller()" ); 
    };
    if ( scalar keys %args ) {

        $self = $class->TAPP::WebService::CSM::new(%args);
    } else {
        $self = $class->TAPP::WebService::CSM::new();
    }
    bless $self, $class;
    if ( defined $args{wsdl}) {
        $self->add_wsdl_interface( %args );  
    }
    $self;
}
#
# to_string ()
#
#   Convert the current WSDL Interface object content
#    including interface, spec and payload to string
#
sub to_string {
    my $self = shift;
    my $interface = $self->{this_interface};
    $interface->to_string();
}
#
# add_wsdl_interface ( HASH )
#
#  Add a named wsdl interface to the stack, optionally including parser spec
# 
sub add_wsdl_interface {
    my $self = shift;
    my $caller = (caller(0))[3];
    my %args = make_hash(@_) or do {
        throw TAPP::IllegalArgumentException( "Unexpected argument list arguments in call to $caller()" ); 
    };
  
    my $name = $args{name};
    if ( exists $self->{interfaces}{$name}) {
      throw TAPP::WebService::CSM::WSDLDefException(
          "Cannot add WSDL with the same name as an existing WSDL. Delete the WSDL before re-adding"
        );
    }
    delete $args{name};
    $self->key( $name );
        
    # Add wsdl template
    my $wsdl = TAPP::WebService::CSM::WSDL::Interface->new( %args  );
    $self->__key_interface($name, $wsdl);
    $self->__key_dataset($name, {} );
    1;
}
#
# remove_wsdl_interface ( SCALAR )
#
#  Removes a wsdl from the stack by name
# 
sub remove_wsdl_interface {
    my $self = shift;
    my $name = shift;
    delete $$self{interfaces}{$name};
    delete $$self{datasets}{$name};
    1;
}
#
# load_data ( HASHREF )
#
#  Loads a hashref of data into wsdl interface to retreive a properly
#  formed payload for call to TAPP::WebService::CSM::call()
# 
sub load_data {
    my $self = shift;
    my $interface = $self->{this_interface};
    my $data = shift;
    #de( $data );
    $self->{this_dataset} = $interface->build_payload( $data );
    $self;
}
#
# send ( HASHREF )
# 
#   Makes call to TAPP::WebService::CSM::call()
#   Passes Interface, Method, payload/data and optionally accepts a hashref of options
# 
sub send {
    my $self = shift;
    my $caller = (caller(0))[3];
    my $opts;
    if (@_) {
      my %args = make_hash(@_) or do {
        throw TAPP::IllegalArgumentException( "Unexpected HASH in call to $caller()" ); 
      };
      $opts = {%args};
    }
    # Get the current selected interface and dataset
    my $interface = $self->{this_interface};
    my $dataset   = $self->{this_dataset};
    
    # Croak if no dataset
    unless ( defined $dataset && ref($dataset) ) { 
        throw TAPP::WebService::CSM::NoPayloadException (
            "Payload exception in $caller(), Playload cannot be empty in call to CSM->call()"
        );
    }
    
      
    # Localize dataset, it could be hash or array...
    # We do this so its impossible to re-submit the same record
    # without rebuilding the payload...
    my (@dataset,%dataset);
    my $dataset_type = ref($dataset);
    if ( $dataset_type eq 'HASH') {
       %dataset = %$dataset;
    } else {
        @dataset = @$dataset;
    }
    # Clean up...
    # Clear the payload
    $interface->clear();
    # Delete the current dataset
    $self->{this_dataset} = {};
    # Delete the reference from the set
    my $key = $self->key();
    $self->{datasets}{$key} = {};
    # Done cleaning up...
    
    # Get object and method from wsdl
    my $object = $interface->object();
    my $method = $interface->method();
    unless ( $object && $method ) { 
      throw TAPP::WebService::CSM::Exception (
          "Cannot deliver dataset to CSM with unknown 'object' or 'method'"
        );
    }
    # Make opts an empty hashref if no opts provided
    $opts = {} unless defined $opts && ref($opts);
    # Make call to CSM, return soap message object
    #de( \$object, \$method, \@dataset, \%dataset, $opts );
    $self->SUPER::call(
          $object => $method,
          payload => $dataset_type eq 'HASH' ? \%dataset : \@dataset,
          opts    => $opts
    );
}
#
# select ( SCALAR )
#
#  Select a WSDL Interface by key, making it the
#  active wsdl (also toggles the matching payload object)
# 
sub select {
    my $self = shift;
    my $name = shift;
    
    unless ( exists $self->{interfaces}{$name} && defined $self->{interfaces}{$name} ) {
        throw TAPP::WebService::CSM::WSDLSelectException(
            "Tried to select a WSDL by a name that isn't registered: ". ($name || 'undef')
          );
    }
    $self->{this_interface} = $self->{interfaces}{$name};
    $self->{this_dataset} = $self->{datasets}{$name} || {};
    $self->{key} = $name;
    1;
}
#
# sub __key_interface ( HASH )
#
#  Push wsdl interface object onto the stack keyed by name
# 
sub __key_interface {
    my $self = shift;
    my ($key,$interface) = @_;
    $self->{interfaces}{$key} = $interface;
    $self->{this_interface} = $interface;
    1;
}
#
# sub __key_dataset ( HASH )
#
#  Push a dataset object onto the stack keyed by name
# 
sub __key_dataset {
    my $self = shift;
    my ($key,$dataset) = shift;
    $self->{datasets}{$key} = $dataset;
    $self->{this_dataset}   = $dataset;
    1;
}
#
# sub key ( SCALAR )
#
#  Set the current selected interface key
# 
sub key {
    my $self = shift;
    $self->{key} = shift if @_;
    $self->{key};
}

sub __this_interface {
  my $self = shift;
  $self->{this_interface} = shift if @_;
  $self->{this_interface}
}

sub __get_current_interface {
    my $self = shift;
    my ($caller) = @_;
    unless ( defined  $self->{this_interface}) {
        throw TAPP::WebService::CSM::AutoloadException(
           "Call to $caller with no active wsdl"
        );
    }
    $self->{this_interface};
}
#
# Interface methods to TAPP::WebService::CSM::WSDL::Interface
#  May subclass it in the future, for now data is accessed through the below methods
# 
sub ccti {
    my $self = shift;
    my $i = $self->__get_current_interface((caller(0))[3]);
    $i->ccti( shift() ) if @_;
    $i->ccti();
}
sub ccti_class {
    my $self = shift;
    my $i = $self->__get_current_interface((caller(0))[3]);
    $i->ccti_class( shift() ) if @_;
    $i->ccti_class();
}
sub ccti_category {
    my $self = shift;
    my $i = $self->__get_current_interface((caller(0))[3]);
    $i->ccti_category( shift ) if @_;
    $i->ccti_category();
}
sub ccti_type {
    my $self = shift;
    my $i = $self->__get_current_interface((caller(0))[3]);
    $i->ccti_type( shift ) if @_;
    $i->ccti_type();
}
sub ccti_item {
    my $self = shift;
    my $i = $self->__get_current_interface((caller(0))[3]);
    $i->ccti_item( shift ) if @_;
    $i->ccti_item();
}
sub translate_labels {
    my $self = shift;
    my $i = $self->__get_current_interface((caller(0))[3]);
    $i->translate_labels( shift ) if @_;
    $i->translate_labels();
}
sub default_values {
    my $self = shift;
    my $i = $self->__get_current_interface((caller(0))[3]);
    $i->default_values( shift ) if @_;
    $i->default_values();
}
sub custom_attributes {
    my $self = shift;
    my $i = $self->__get_current_interface((caller(0))[3]);
    $i->custom_attributes( shift ) if @_;
    $i->custom_attributes();
}
sub attributes {
    my $self = shift;
    my $i = $self->__get_current_interface((caller(0))[3]);
    $i->attributes( shift ) if @_;
    $i->attributes();
}
sub bean {
    my $self = shift;
    my $i = $self->__get_current_interface((caller(0))[3]);
    $i->bean( shift ) if @_;
    $i->bean();
}
sub filter_fields {
    my $self = shift;
    my $i = $self->__get_current_interface((caller(0))[3]);
    $i->filter_fields( shift ) if @_;
    $i->filter_fields();
}
sub required_fields {
    my $self = shift;
    my $i = $self->__get_current_interface((caller(0))[3]);
    $i->required_fields( shift ) if @_;
    $i->required_fields();
}
1;


