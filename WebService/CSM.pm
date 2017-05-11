package TAPP::WebService::CSM;
{
  $TAPP::WebService::CSM::VERSION = '0.005';
}
use strict;
#===================================================================================================
# TAPP/WebService/CSM.pm
#
# SOAP::Lite wrapper for CSM web services
#
# Provides a consolidated pure-purl interface to CSM web services, obfuscating some of the
# complexity of SOAP::Lite/SOM/Data, and providing a true(r) result status of SOAP calls.
#
# The autoloader allows for the caller to use some sugary syntax for even better readability in the
# calling script, however its autoloader, so be mindful of performance 
#
# Auth: achjo03, 05/05/15
#
# Lasted Edited By: achjo03, 09/10/15 - added documentation, removed benchmarking and unimplemented
#                                       import arguments
#
#===================================================================================================
require SOAP::Lite;

use TAPP::WebService::CSM::ParseSOM;
use TAPP::Datastructure::Utils qw/:all/;
use TAPP::Exception;
use base qw(Class::Accessor);
use JSON::XS;
use Scalar::Util qw/blessed/;
use Try::Tiny;
use TAPP::Config::UNIVERSAL;

my %INIT_ARGS = (
    uri            => undef,
    autotype       => 0,
    userName       => undef,
    userPassword   => undef,
    default_ns     => 'http://wrappers.webservice.appservices.core.inteqnet.com',
    responseFormat => 'JSON',
    port           => 443,
    max_attempts   => 5,
    wait_time      => 5,
    ssl_opts => {
          verify_hostname => 0,
    },
);
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;
__PACKAGE__->mk_accessors( keys %INIT_ARGS );

#####-----------------------------------------------------------------------------------------------
#
#   sub import()
##    Handles module imports from the caller, currently only ':debug' import is supported,
##    and will enable debug in this module as well as passing +trace argument to SOAP::Lite
#####-----------------------------------------------------------------------------------------------
sub import {
    my $class = shift;
    my %imports;
    if ( @_ ) {
        SOAP::Lite->import( @_ );
    }
    1;
}

#####-----------------------------------------------------------------------------------------------
#
#   sub new() 
##    Instantiate and initialize with default properties
#####-----------------------------------------------------------------------------------------------
sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $self = {};
    my $caller = (caller(0))[3];    
    my %args = make_hash(%INIT_ARGS,@_) or do {
        throw TAPP::IllegalArgumentException( "Unexpected argument list arguments in call to $caller()" ); 
    };
    bless $self, $class;
    $self->__init(\%args);
}
#####-----------------------------------------------------------------------------------------------
#
#   sub __init() 
##    Apply input args, build and initialize SOAP::Lite object, set SSL opts,
##    endpoint and other properties
#####-----------------------------------------------------------------------------------------------
sub __init {
    my $self = shift;
    my $args = shift;
    my $caller = (caller(0))[3];
    if ($args->{env}) {
      my $section = $args->{env} =~ /staging/i ? 'csm_staging' : 'csm_prod';
      my $uni;
      if ( my $file = $args->{user_config} ) {
        unless ( -f $file ) {
          throw TAPP::IllegalArgumentException(
              "Invalid argument to ".__PACKAGE__."::new(), user_config file $file does not exist"
          )
        }
        $uni = TAPP::Config::UNIVERSAL->new( user_config => $file );
      } else {
        $uni = TAPP::Config::UNIVERSAL->new();
      }
      my %ini = $uni->get_sections($section);
      %$self = (%INIT_ARGS,%ini);
    } else {
      %$self = (%INIT_ARGS,%$args);
    }
    foreach ( keys %INIT_ARGS ) {
        next if defined $self->{$_};
        throw TAPP::IllegalStateException( "Undefined $_ for obj of type: ".__PACKAGE__ )
    }    
    $self->{soap} = new SOAP::Lite();
    if ( $self->{entity} ) {
        $self->endPoint( map { $_ => $self->{$_} } qw/entity uri port/ );
    }
    $self->{soap}->autotype($self->{autotype});
    $self->{soap}->on_action( sub { $self->{default_ns} } );
    $self->{soap}->default_ns( $self->{default_ns} );
    $self;
}
#####-----------------------------------------------------------------------------------------------
#
#   sub proxy() 
##    Set the initial endpoint - Note that SOAP12 is hardcoded here. If you need SOAP11
##    calls for some reason, you'll want to make this an argument.. 
#####-----------------------------------------------------------------------------------------------
sub proxy {
    my $self = shift;
    return $self->{proxy} unless @_;
    my $caller = (caller(0))[3];
    my $args = make_hash(@_);
    unless ( is_non_empty_hashref($args) ) {
        throw TAPP::IllegalArgumentException( "Missing or illegal arguments in call to $caller()" ); 
    }
    my $proxy =
       $args->{uri}    . ":" .
       $args->{port}   . "/servicedesk/webservices/" .
       $args->{entity} . "." .$args->{entity} . "HttpSoap12Endpoint/";
  
    $self->{soap}->proxy( $proxy );
    $self->{proxy} = $proxy;
    1;
}
#####-----------------------------------------------------------------------------------------------
#
#   sub endPoint() 
##    Similar to proxy(), endPoint() sets the endpoint AFTER the proxy has been set. Basically
##    allows the endPoint to be changed without instantiating a new CSM object, for more info
##    refer to SOAP::Lite documentation
#####-----------------------------------------------------------------------------------------------
sub endPoint {
    my $self = shift;
    return $self->{endPoint} unless @_;
    my $caller = (caller(0))[3];
    my $args = make_hash(@_) or do { 
        throw TAPP::IllegalArgumentException( "Missing or illegal arguments in call to $caller()" ); 
    };
  
    my $end_point = $args->{uri}    . ":" .
                    $args->{port}   . "/servicedesk/webservices/" .
                    $args->{entity} . "." .$args->{entity} . "HttpSoap12Endpoint/";
  
    $self->{soap}->endpoint( "$end_point newPoint" );
    $self->{endPoint} = $end_point;
    1;
}
#####-----------------------------------------------------------------------------------------------
#
#   sub call() 
##    Method wrapper of SOAP::SOM->call(), building the SOM, and executing of calls to CSM API, then
##    handling the result. Implements a loop of attempts with timeout
##    eg:  call( entity => 'method', payload => HASHREF|ARRAYREF, opts => HASHREF );
#####-----------------------------------------------------------------------------------------------
sub call {
  
    my $self = shift;
    my $caller = (caller(0))[3];
    unless ( is_non_empty_arrayref(\@_) ) {
        throw TAPP::MissingArgumentsException( "Expected ARRAY in call to $caller()" ); 
    }
    $self->{entity} = shift;
    my $method      = shift;
    my %args = make_hash(@_) or do {
        throw TAPP::IllegalArgumentException( "Illegal argument list in call to $caller()" )
    };
    $self->{payload} = [];
    my $payload = $args{payload} || [];
    my $opts    = $args{opts}    || {};
  #de( $payload );
    # Allow object properties to mutate to values set in %$opts arg
    foreach ( keys %INIT_ARGS ) {
        $self->{$_} = $opts->{$_} if defined $opts->{$_}
    }
  
    # Convert payload ref to SOAP::Data objects
    # and store in $self->{payload}
    $self->payload( $payload ) if ref( $payload );
    $self->__add_credentials();
    $payload = $self->payload();
  
    unless (defined $payload && ref( $payload ) ) {
        throw TAPP::WebService::CSM::NoPayloadException(
            "Payload not defined in call to $caller()"
        );
    }
  
    # Remember the last entity, because if we change it we need to
    # call endPoint(), this avoids a performance hit
    my $last_entity      = $self->{last_entity};
    $self->{last_entity} = $self->{entity};
  
    if ( defined $last_entity && $last_entity ne $self->{entity} ) {
        # Changing endpoints
        $self->endPoint( map { $_ => $self->{$_} } qw/entity uri port/ );
    } else {
        $self->proxy   ( map { $_ => $self->{$_} } qw/entity uri port/ );
    }
  
    my $max_attempts    = $self->{max_attempts};
  
    # Tidy up the mailbox
    undef  $self->{csm_som};
    delete $self->{csm_som};
    
    my ($som,$response);
    DO_SOAPLITE:
    for my $attempt (1 .. $max_attempts) {
        my $success;
        # Try SOAP::Lite->call();
#        print "CSM TRY:\n";
#        dd( $payload, \$method );
        try {
            $som = $self->{soap}->call( $method,  @$payload );
           
            
            $success = 1;
        } catch {
            if ($attempt < $self->{max_attempts}) {
                warn "Received error in call to SOAP::Lite: $_"
                      . "Pausing $$self{wait_time}s\n";
                sleep $self->{wait_time};
            }
            else {
                throw TAPP::WebService::CSM::SOAPCallException(
                  "Exception in call to SOAP::Lite, attempts exceeded [$max_attempts]: $_"
                );
            }
        };
        next unless $success;
        $response = {};
        # try TAPP::WebService::CSM::ParseSOM->parse();
        try {
            $response = parse_som(
                                  som             => $som,
                                  require_results => $opts->{require_results},
                            );
        } catch {
            my $error  = $_;
            if ( blessed $error && $error->can('rethrow') ) {
                $error->rethrow;
            } else { 
                throw TAPP::WebService::CSM::SOMParseException(
                   "Exception in call to TAPP::WebService::CSM::ParseSOM: $_"
                  )
            }
        };
        last;
    }
    $self->{som}      = $som;
    $self->{response} = $response;
    $response;
}
#####-----------------------------------------------------------------------------------------------
#
#   sub payload() 
##    Prepare the payload arrayref of SOAP::Data objects, for delivery to SOAP::Lite->call()
#####-----------------------------------------------------------------------------------------------
sub payload {
    my $self = shift;
    return $self->{payload} || [] if scalar @_ == 0;
    my @payload = @{ __soapify_data( make_arrayref( shift ) ) };
    my $pos     = shift || 'E';
    # Sequence matters. Add data at the beginning or end of payload array?
    if ( $pos eq 'E' ) {
        push    @{ $self->{payload} }, @payload;
    } else {
        unshift @{ $self->{payload} }, @payload ;
    }
    1;
}
sub __dehash {
    use TAPP::HaS;
    my $caller = (caller(0))[3];
    my ($hs,$ret) = @_;
    if (defined $hs) {  
      my $ths = TAPP::HaS->new();
      $ths->hashedstr($hs);
      $ret = $ths->plainstr();
    } else {
        throw TAPP::Xr22::IllegalXr22( "Illegal or undefined Xr22 in call to $caller()" )
    }
    $ret;
}
#####-----------------------------------------------------------------------------------------------
#
#   sub __soapify_data() 
##    Convert perl HASHREF or ARRAYREF data into AoH of SOAP::Data objects
#####-----------------------------------------------------------------------------------------------
sub __soapify_data {
    my ($this, $parent) = @_;
    local $_ = ref( $this );
    /ARRAY/ && do {
        my @t;
        foreach ( @$this ) {
			     my $sd = __soapify_data( $_ );
			     push @t, $sd;
		    }
        return [@t];
    };
    /HASH/  && do {
        my ($k,$v) = each %$this;
        $v = __soapify_data( $v );
		    return SOAP::Data->name($k)->value( $v ); #ref($v) eq 'ARRAY' ? @$v : $v );
    };
    $this;
}

#####-----------------------------------------------------------------------------------------------
#
#   sub __add_credentials() 
##    Push credentials into each call
#####-----------------------------------------------------------------------------------------------
sub __add_credentials {
	my $self = shift;
	my @creds = (
      {
          credentials => [
              { userName     => $self->{userName}, },
              { userPassword => __dehash($self->{userPassword}), },
          ],
      },
      {
          extendedSettings => [
              { 'responseFormat' => $self->{responseFormat} },
          ],
      }
	);
  $self->payload( \@creds, 'B' );
  1;
}
1;


