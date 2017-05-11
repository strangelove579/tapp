package TAPP::WebService::CSM::SOM;
{
  $TAPP::WebService::CSM::SOM::VERSION = '0.001';
}
use strict;
#===================================================================================================
# TAPP/WebService/CSM/SOM.pm
#
# SOAP::SOM wrapper for TAG CSM SOAP Interface
#
# Provides a consolidated pure-purl interface to CSM SOM
# Auth: achjo03, 05/05/15
#
#===================================================================================================

use base qw(Class::Accessor);

use Data::Dumper qw/Dumper/;
sub d { print Dumper( shift() ), "\n"; }

use Carp qw/carp croak confess/;
use Readonly;
use JSON::XS;

my $json = JSON::XS->new->allow_nonref;

my @RESPONSE_ATTRS = qw/
    responseFormat
    responseStatus
    responseText
    statusCode
    statusMessage
/;

my @FAULT_ATTRS = qw/
    fault
    faultstring
/;

my @ERR_ATTRS = qw/
    error_string
    timeout
/;

__PACKAGE__->mk_accessors( @RESPONSE_ATTRS, @FAULT_ATTRS, @ERR_ATTRS, 'csmsom', 'som');

sub setResponse {
    my $self = shift;
    $self->{responseText} = $json->decode($self->{responseText} ) || '';
    $self->{responseText}
}

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $self = {};
    my $args = scalar @_ > 1 ? {@_} : shift;
    $self->{som} = $args->{som} if $args->{som};
    $self->{require_results} = 0;
    bless $self, $class;
}
sub is_success { shift()->{is_success} }

sub reduce_som {
    my $self = shift;
    my $args = {@_};
    my $som = $args->{som} || $self->{som};
    my $require_results = $args->{require_results} || 0;

    my $response_status = $som->{_context}{_transport}{_proxy}{_status};

    if ( $response_status =~ /500 internal server error/i) {
      $self->{error_string} =  __PACKAGE__. ": " . $response_status;
      carp $self->{error_string};
      return $self;
    }
    
    $self->{$_} = $som->valueof( "//$_" ) foreach @RESPONSE_ATTRS;
    $self->{responseText} =  defined $self->{responseText}
                             ? $json->decode( $self->{responseText} )
                             : [];
    $self->{responseText} = ref( $self->{responseText} ) =~ /HASH/
                            ? [$self->{responseText}]
                            : $self->{responseText};

    $self->{faultstring}  ||= '';
    $self->{fault}        = $som->fault || 0;


    if ($som->fault) {
        ( $self->{faultstring} = $som->fault->{faultstring} ||
           'An unhandled exception occurred (fault)' ) =~ s/^\s*(.*?)\s*$/$1/;
    }
    # build error list as a scalar

    my $errors = $som->valueof("//errors" );
    $errors = ref( $errors ) =~ /ARRAY/ ? $errors : [$errors];

    my $errorstr = '';
    foreach ( @$errors ) {
        $errorstr .= "$_\n" if defined && /[\S]/;
    }
    $errorstr .= $self->{faultstring} if $self->{faultstring};
 
    # append status message, if some unwanted status was returned
    unless (
        # unless... successful response with results
        $self->statusCode() eq '000'
        || (
        # or.. successful response without results - and we weren't requiring results...
               $self->statusCode() eq '001'
               && $require_results != 1
            )
       ) {
        $errorstr .= "Status: [" . $self->statusCode() . "] - ". $self->statusMessage()   . " \n"
    }

    # store error string
    $errorstr =~ s/\n$//;
    $self->error_string( length $errorstr ? "Error: $errorstr" : '' );
    $self->{is_success} = length ($self->error_string()) ? 0 : 1;
    # Store the original message
    $self->{som}     = $som;
    $self;
}
sub error_string { return shift()->{error_string} || '' }
sub som { return shift()->{som} }
1;

