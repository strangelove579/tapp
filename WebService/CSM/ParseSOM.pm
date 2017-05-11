package TAPP::WebService::CSM::ParseSOM;
{
  $TAPP::WebService::CSM::ParseSOM::VERSION = '0.002';
}
use strict;
#===================================================================================================
# TAPP/WebService/CSM/ParseSOM.pm
#
# SOAP::SOM parser for TAG CSM SOAP Interface
#
# Provides a consolidated pure-purl interface to CSM ParseSOM
# Auth: achjo03, 05/05/15
#
#===================================================================================================
use parent qw/Exporter/;
use TAPP::Datastructure::Utils qw/:all/;
use TAPP::Exception;
use JSON::XS;
use Scalar::Util qw/blessed/;
my $json = JSON::XS->new->allow_nonref;

our @EXPORT = qw/parse_som/;

my %RESPONSE_DEFAULT = (
    notes           => [],
    warnings        => [],
    responseFormat  => undef,
    responseStatus  => undef,
    responseText    => undef,
    statusCode      => undef,
    statusMessage   => undef,
);

sub parse_som {
    my $args = make_hash(@_);
    my $som             = $args->{som};# || $self->{som};
    my $require_results = $args->{require_results} || 0;

    my $response_status = $som->{_context}{_transport}{_proxy}{_status};

    if ( $response_status =~ /500/i) {
      throw TAPP::WebService::CSM::HTTPException(
          $response_status
      );
    }
    my %resp = map {
                  $_ => defined $som->valueof( "//$_" )
                        ? $som->valueof( "//$_" )
                        : $RESPONSE_DEFAULT{$_}
              } keys %RESPONSE_DEFAULT;
    $resp{is_success} = 0;
    $resp{responseText} = defined $resp{responseText}
                             ? $json->decode( $resp{responseText} )
                             : [];
                             
    $resp{responseText} = ref( $resp{responseText} )   eq 'HASH'
                              ? [$resp{responseText}]
                              : ref( $resp{responseText} ) eq 'ARRAY'
                              ? $resp{responseText}
                              : [];
    $resp{faultstring}  = '';
    $resp{fault}        = 0;
#    my $valid_return    = $resp{statusCode} eq '000' || +( $require_results &&  $resp{statusCode} eq '001' );
    my $valid_return    = $require_results && $resp{statusCode} eq '000' ? 1 : $resp{statusCode} =~ /^00/ ? 1 : 0;
   
    unless ($valid_return) {
        my $errorstr = '';
        if ($som->fault) {
            ($errorstr = $som->fault->{faultstring} ||
               'An unhandled exception occurred (fault)' ) =~ s/^\s*(.*?)\s*$/$1/;
        }

        my $errors = $som->valueof("//errors" );
        $errors = ref( $errors ) =~ /ARRAY/ ? $errors : [$errors];
        
        my $notes = $som->valueof("//notes" );
        $notes = ref( $notes ) =~ /ARRAY/ ? $notes : [$notes];
        
        foreach ( @$errors, @$notes ) {
            $errorstr .= "$_\n" if defined && /[\S]/;
        }
        
        my $msg    = "Status Code: $resp{statusCode}\n";
        $msg      .= "Status Message: $resp{statusMessage}\n" if defined $resp{statusMessage};
        $msg      .= $errorstr;

        throw TAPP::WebService::CSM::ParseSOMBadReturnStatus(
              "Invalid return status, errors returned: " . +( $msg || 'Unhandled Exception' )
        );
    }
    $resp{is_success} = 1;
    wantarray()? %resp : {%resp};
}
1;


