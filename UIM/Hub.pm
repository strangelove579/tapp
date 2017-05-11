package TAPP::UIM::Hub;
{
  $TAPP::UIM::Hub::VERSION = '0.001';
}
use TAPP::Config::UNIVERSAL;
use TAPP::Datastructure::Utils qw/:all/;
use TAPP::UIM::PUParser;
use TAPP::Exception;
use Scalar::Util qw/blessed/;
use Carp qw/croak/;
use POSIX qw/strftime/;
use base qw/Exporter/;
use Try::Tiny;
use Time::HiRes qw/usleep/;
use IPC::Run qw{ run timeout };


use constant HUB_LIST_MAP => [
    { label => 'name',       type => 'C', },      
    { label => 'domain',     type => 'C', },      
    { label => 'robotname',  type => 'C', },      
    { label => 'addr',       type => 'C', },      
    { label => 'ip',         type => 'C', },      
    { label => 'port',       type => 'I', },      
    { label => 'last',       type => 'T', },      
    { label => 'license',    type => 'B', },      
    { label => 'temp',       type => 'B', },      
    { label => 'sec_on',     type => 'I', },      
    { label => 'sec_ver',    type => 'C', },      
    { label => 'status',     type => 'M',
                  map => {
                            0 => 'OK',
                            1 => 'ERROR',
                            2 => 'Inactive',
                            3 => 'UNK',
                            4 => 'Maintenance',
                  },
    },
    { label => 'version',    type => 'C', },      
    { label => 'proximity',  type => 'I', },      
    { label => 'epoc_skew',  type => 'I', },      
    { label => 'synch',      type => 'B', },      
    { label => 'ssl_mode',   type => 'B', },      
    { label => 'origin',     type => 'C', },      
    { label => 'req_tused',  type => 'B', },      
    { label => 'source',     type => 'C', },
    { label => 'type',       type => 'M',
                  map => {
                           1 => 'Tunnel Server',
                           2 => 'Standard Hub',
                           8 => 'Proxy Hub',
                    },
    },     
];
                    

use constant GET_HUB_MAP => [
    { label => 'hubname',           type => 'C', },      
    { label => 'domain',            type => 'C', },      
    { label => 'version',           type => 'C', },      
    { label => 'hubaddr',           type => 'C', },      
    { label => 'hubip',             type => 'C', },      
    { label => 'log_level',         type => 'I', },      
    { label => 'log_file',          type => 'C', },      
    { label => 'license',           type => 'B', },      
    { label => 'expire',            type => 'B', },      
    { label => 'ispool',            type => 'C', },      
    { label => 'tunnel',            type => 'C', },      
    { label => 'ssl_mode',          type => 'B', },      
    { label => 'ssl_cipher',        type => 'C', },      
    { label => 'origin',            type => 'C', },      
    { label => 'ldap',              type => 'C', },      
    { label => 'ldap_version',      type => 'C', },      
    { label => 'requests',          type => 'I', },      
    { label => 'post_received',     type => 'I', },      
    { label => 'post_sent',         type => 'I', },      
    { label => 'post_dropped',      type => 'I', },      
    { label => 'sec_login_ok',      type => 'I', },      
    { label => 'sec_login_failed',  type => 'I', },      
    { label => 'sec_verify_ok',     type => 'I', },      
    { label => 'sec_verify_failed', type => 'I', },      
    { label => 'sec_on',            type => 'I', },      
    { label => 'sec_ver',           type => 'C', },      
    { label => 'uptime',            type => 'I', },      
    { label => 'started',           type => 'T', },      
    { label => 'lastrestart',       type => 'T', },      
    { label => 'nrestarts',         type => 'I', },      
    { label => 'nns_records',       type => 'I', },      
    { label => 'r_nns_records',     type => 'I', },      
    { label => 'iNameThreads',      type => 'I', },     
];

use constant ROBOT_LIST_MAP => [
    { label => 'name',             type => 'C', },      
    { label => 'addr',             type => 'C', },      
    { label => 'origin',           type => 'C', },      
    { label => 'port',             type => 'I', },      
    { label => 'ip',               type => 'C', },      
    { label => 'version',          type => 'C', },      
    { label => 'flags',            type => 'C', },      
    { label => 'ssl_mode',         type => 'B', },      
    { label => 'license',          type => 'B', },      
    { label => 'autoremove',       type => 'B', },      
    { label => 'heartbeat',        type => 'I', },      
    { label => 'created',          type => 'T', },      
    { label => 'lastupdate',       type => 'T', },      
    { label => 'last_change',      type => 'T', },      
    { label => 'last_inst_change', type => 'T', },      
    { label => 'device_id',        type => 'C', },      
    { label => 'os_major',         type => 'C', },      
    { label => 'os_minor',         type => 'C', },      
    { label => 'os_description',   type => 'C', },      
    { label => 'os_user1',         type => 'C', },      
    { label => 'os_user2',         type => 'C', },      
    { label => 'offline',          type => 'B', },      
    { label => 'status',           type => 'M',
                  map => {
                            0 => 'OK',
                            1 => 'ERROR',
                            2 => 'Inactive',
                            3 => 'UNK',
                            4 => 'Maintenance',
                  },
    },
];
  
# Ordered fieldnames
use constant HUB_LIST_FLDS   => map { $_->{label} } @{ HUB_LIST_MAP()   };
use constant GET_HUB_FLDS    => map { $_->{label} } @{ GET_HUB_MAP()        };
use constant ROBOT_LIST_FLDS => map { $_->{label} } @{ ROBOT_LIST_MAP() };

# Field types
use constant HUB_LIST_FLD_TYPE   => map { $_->{label} => $_->{type} } @{ HUB_LIST_MAP()   };
use constant GET_HUB_FLD_TYPE    => map { $_->{label} => $_->{type} } @{ GET_HUB_MAP()        };
use constant ROBOT_LIST_FLD_TYPE => map { $_->{label} => $_->{type} } @{ ROBOT_LIST_MAP() };

# Field LOVs
use constant HUB_LIST_LOV   => map {$_->{label} => $_->{map}} grep {$_->{type} eq 'M'} @{ HUB_LIST_MAP()   };
use constant ROBOT_LIST_LOV => map {$_->{label} => $_->{map}} grep {$_->{type} eq 'M'} @{ ROBOT_LIST_MAP() };

our @EXPORT = qw/
        HUB_LIST_FLDS
        GET_HUB_FLDS
        ROBOT_LIST_FLDS
        HUB_LIST_FLD_TYPE
        GET_HUB_FLD_TYPE
        ROBOT_LIST_FLD_TYPE
  /;

use constant CONFIG_SECTIONS => qw/
  uim_prod
  uim_inventory_prod
/;
my $hub_list_template   = '#NIMROOT#/bin/pu -u#USER# -p#PASS# /#DOMAIN#/#HUB#/#HUBROBOTNAME#/hub gethubs NULL';
my $robot_list_template = '#NIMROOT#/bin/pu -u#USER# -p#PASS# /#DOMAIN#/#HUB#/#HUBROBOTNAME#/hub getrobots NULL NULL';
my $get_hub_template    = '#NIMROOT#/bin/pu -u#USER# -p#PASS# /#DOMAIN#/#HUB#/#HUBROBOTNAME#/hub get_info NULL';


sub new {
    my $class = shift;
    my $self  = {};
    my $caller = (caller(0))[3];
    my %args  = ();
    my $file;
    if (scalar @_ > 0) {
      %args = make_hash( @_ ) or
        throw TAPP::IllegalArgumentException(
            "Invalid arguments, only 'user_config' is allowed in call to $caller"
        );      
    }
    bless $self, $class;
    $self->{pu_timeout}         = $args{pu_timeout}  || 30;
    $self->{throttle_ms}        = $args{throttle_ms} || 0;
    $self->__load_config( $args{user_config}  );

    $self->{pu} = TAPP::UIM::PUParser->new( compatibility => $args{output_compatibility} );
    $self;
}

sub set_throttle {
    my $self = shift;
    $self->{throttle_ms} = shift if @_;
    $self->{throttle_ms};
}

sub set_timeout {
    my $self = shift;
    $self->{pu_timeout} = shift if @_;
    $self->{pu_timeout};
}


sub __load_config {
    my $self = shift;
    my $uni;
    if ( my $file = shift() ) {
      unless ( -f $file ) {
        throw TAPP::IllegalArgumentException(
            "Invalid argument to ".__PACKAGE__."::new(), file $file does not exist"
        )
      }
      $uni = TAPP::Config::UNIVERSAL->new( user_config => $file );
    } else {
      $uni = TAPP::Config::UNIVERSAL->new();
    }
    my %ini = $uni->get_sections(CONFIG_SECTIONS());
    @{$self}{sort keys %ini} = @ini{sort keys %ini};
    1;
}
sub get_hub { 
    my $self = shift;
    my $dataref = $self->__run( $get_hub_template, [GET_HUB_FLDS()], @_ ); 
    $dataref = __convert_datatypes( $dataref, {GET_HUB_FLD_TYPE()},);
    wantarray()? @$dataref : $dataref;
}
# synonyms for get_hub
sub hubinfo { return get_hub( @_ ) }
sub gethub   { return get_hub( @_ ) }
sub get      { return get_hub( @_ ) }

sub robot_list { 
    my $self = shift;
    my $dataref = $self->__run( $robot_list_template, [ROBOT_LIST_FLDS()], @_ ); 
    $dataref = __convert_datatypes( $dataref, {ROBOT_LIST_FLD_TYPE()}, {ROBOT_LIST_LOV()} );
    wantarray()? @$dataref : $dataref;
}
# synonyms for robot_list
sub get_robots  { return robot_list( @_ ) }
sub list_robots { return robot_list( @_ ) }
sub robotlist   { return robot_list( @_ ) }
sub robots      { return robot_list( @_ ) }

sub hub_list {
    my $self = shift;
    my $dataref = $self->__run( $hub_list_template, [HUB_LIST_FLDS()], @_ ); 
    $dataref = __convert_datatypes( $dataref, {HUB_LIST_FLD_TYPE()}, {HUB_LIST_LOV()} );
    wantarray()? @$dataref : $dataref;
}
# synonyms for hub_list
sub get_hubs  { return hub_list( @_ ) }
sub list_hubs { return hub_list( @_ ) }
sub hublist   { return hub_list( @_ ) }
sub hubs      { return hub_list( @_ ) }

sub __convert_datatypes {
  my ($dataref,$type_map,$lov)  = @_;
  $lov = {} unless is_hashref( $lov );
  foreach my $href (@$dataref) {
    foreach my $k ( keys %$href ) {
      my $v = $href->{$k};
      local $_ = $type_map->{$k} or next;
      
      /T/ && do { $href->{$k} = $v eq '0' ? undef : strftime( "%m/%d/%Y %H:%M:%S", localtime($v) ); next; };
      /B/ && do { $href->{$k} = $v eq '0' ? 'No'  : $v eq '1' ? 'Yes' : 'UNK'; next; };
      /M/ && do { $href->{"${k}_desc"} = $lov->{$k}{$v} || 'UNK'; next; };
    }
  }
  # autovivicate any missing keys
  foreach my $href (@$dataref) { 
      foreach my $k (keys %$type_map) { 
        $href->{$k} = undef unless defined $href->{$k};
      }
  }
  wantarray()? @$dataref : $dataref;
}

sub __run {
    my $self = shift;
    my $caller = (caller(0))[3];
    my ($template,$attrs,@hubinfo) = @_; #here
    my %hub = make_hash( @hubinfo ) or
        throw TAPP::IllegalArgumentException(
            "Invalid arguments, hash expected in call to $caller()"
        );
    unless( defined $hub{hub} && defined $hub{hubrobotname} ) {
      throw TAPP::MissingArgumentsException( 
         "Invalid arguments to $caller(), 'hub' and 'hubrobotname' are required arguments"
      )
    }
    my ($nimroot,$domain,$userid,$passwd) = @{$self}{qw/nimroot domain userid passwd/};
    $passwd = __dehash( $passwd );
    my $cmd = $template;
    $cmd =~ s/#NIMROOT#/\L$nimroot/;
    $cmd =~ s/#DOMAIN#/$domain/;
    $cmd =~ s/#USER#/$userid/;
    $cmd =~ s/#PASS#/$passwd/;
    $cmd =~ s/#HUB#/$hub{hub}/;
    $cmd =~ s/#HUBROBOTNAME#/$hub{hubrobotname}/;
    my $cmd_display = $cmd;
    $cmd_display =~ s/(-u)\S+/${1}xxx/;
    $cmd_display=~ s/(-p)\S+/${1}xxx/;
    my ($errorstr, $exit_status) = ();
    my $dataref;
#
#  Run PU command
#
    my $pu = $self->{pu};
    try {
        usleep( $self->{throttle_ms} || 0 );
        my @command = (split(/ /,$cmd));
        my ($in,$out,$err);
        my $exit_status = 0;
        # Use IPC::Run::run to execute PU, so that we do not leave pu processes running after timeout
        # because system(), qx{}, ``, etc will all orphan the pu process and leave it running after timeout!
        
        run \@command, \$in, \$out, \$err, timeout($self->{pu_timeout})
            or do { $exit_status = 1 };
        my @output = split( /\n/, $out );        
        $dataref = $pu->pu_parse( \@output, $attrs, $exit_status );
        if ($exit_status) {
          throw TAPP::UIM::PUExecFailed(
            domain       => $domain,
            hub          => $hub{hub},
            hubrobotname => $hub{hubrobotname},
            message      => "Received a non-zero exit status when attempting to execute probe-utility command",
            command      => "$cmd_display",
            timedout     => 0,
            errorstr     => $pu->errorstr,
            exit_status  => $pu->exit_status,
          );
        }
    } catch {
      unless ( blessed ($_) && $_->can('rethrow') ) {
        if (/timeout/) {
          throw TAPP::UIM::PUExecTimeout(
            domain       => $domain,
            hub          => $hub{hub},
            hubrobotname => $hub{hubrobotname},
            message      => "Execution of probe-utility command timed out [". $self->{pu_timeout}. "]",
            command      => "$cmd_display",
            timedout     => 1,
            errorstr     => $pu->errorstr,
            exit_status  => $pu->exit_status,
          )                       
        } else {
          throw TAPP::UIM::PUExecUnhandledException(
            domain       => $domain,
            hub          => $hub{hub},
            hubrobotname => $hub{hubrobotname},
            message      => "General Exception in execution of $caller()",
            command      => "$cmd_display",
            timedout     => 0,
            errorstr     => "Unhandled Non-pu exception",
            exit_status  => 1,
          )
        }
      }
      $_->rethrow();
    };
    foreach (@$dataref) {
      $_->{domain}          ||= $domain;
      $_->{exit_status}  ||= 0;
      $_->{errorstr}     ||= undef;
      $_->{hub}             ||= $hub{hub};
      $_->{hubrobotname}    ||= $hub{hubrobotname};
      $_->{hubname}         ||= $hub{hub};
      $_->{robotname}       ||= $hub{hubrobotname};
    }
    wantarray()? @$dataref : $dataref;
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
    throw TAPP::HashException("Nothing to de-hash in call to $caller\n");
  }
  $ret;
}
sub error {
  my $self = shift;
  $self->{error} = shift if @_;
  $self->{error}
}
1;


