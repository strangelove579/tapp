package TAPP::UIM::Robot;
{
  $TAPP::UIM::Robot::VERSION = '0.001';
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

use constant HUB_INFO_MAP => [
    { label => 'domain',             type => 'C', },      
    { label => 'robotname',          type => 'C', },      
    { label => 'hubdomain',          type => 'C', },      
    { label => 'hubname',            type => 'C', },      
    { label => 'hubrobotname',       type => 'C', },      
    { label => 'hubip',              type => 'C', },      
    { label => 'hubport',            type => 'I', },      
    { label => 'phub_domain',        type => 'C', },      
    { label => 'phub_name',          type => 'C', },      
    { label => 'phub_robotname',     type => 'C', },      
    { label => 'phub_ip',            type => 'C', },      
    { label => 'phub_port',          type => 'I', },      
];

use constant GET_ROBOT_MAP => [
    { label => 'robotname',          type => 'C', },      
    { label => 'robotip',            type => 'C', },      
    { label => 'hubname',            type => 'C', },      
    { label => 'hubip',              type => 'C', },      
    { label => 'domain',             type => 'C', },      
    { label => 'origin',             type => 'C', },      
    { label => 'source',             type => 'C', },      
    { label => 'robot_device_id',    type => 'C', },      
    { label => 'robot_mode',         type => 'M',
                  map => {
                            '0' => 'Normal-Reports to Hub',
                            '1' => 'Passive-Waits for Hub',
                  }
    },      
    { label => 'hubrobotname',       type => 'C', },      
    { label => 'log_level',          type => 'I', },      
    { label => 'log_file',           type => 'C', },      
    { label => 'license',            type => 'B', },      
    { label => 'requests',           type => 'I', },      
    { label => 'uptime',             type => 'I', },      
    { label => 'started',            type => 'T', },      
    { label => 'os_major',           type => 'C', },      
    { label => 'os_minor',           type => 'C', },      
    { label => 'os_version',         type => 'C', },      
    { label => 'os_description',     type => 'C', },      
    { label => 'os_user1',           type => 'C', },      
    { label => 'os_user2',           type => 'C', },      
    { label => 'workdir',            type => 'C', },      
    { label => 'current_time',       type => 'T', },      
    { label => 'access_0',           type => 'I', },      
    { label => 'access_1',           type => 'I', },      
    { label => 'access_2',           type => 'I', },      
    { label => 'access_3',           type => 'I', },      
    { label => 'access_4',           type => 'I', },      
    { label => 'timezone_diff',      type => 'I', },      
    { label => 'timezone_name',      type => 'C', },      
    { label => 'spoolport',          type => 'I', },      
    { label => 'last_inst_change',   type => 'T', },      
];

use constant PROBE_LIST_MAP => [
    { label => 'name',               type => 'C', },      
    { label => 'description',        type => 'C', },      
    { label => 'group',              type => 'C', },      
    { label => 'active',             type => 'M',
                  map => {
                            0 => 'Inactive',
                            1 => 'OK',
                            2 => 'Error',
                            3 => 'Error',
                            4 => 'Maintenance',
                            5 => 'Suspend',
                  },
    },
    { label => 'type',  type => 'M',
                  map => {
                            0 => 'on_demand',
                            1 => 'UNK',
                            2 => 'daemon',
                            3 => undef,
                  }
    },   
    { label => 'command',            type => 'C', },      
    { label => 'arguments',          type => 'C', },      
    { label => 'config',             type => 'C', },      
    { label => 'logfile',            type => 'C', },      
    { label => 'workdir',            type => 'C', },      
    { label => 'timespec',           type => 'C', },      
    { label => 'times_activated',    type => 'I', },      
    { label => 'last_action',        type => 'T', },      
    { label => 'pid',                type => 'I', },      
    { label => 'times_started',      type => 'I', },      
    { label => 'last_started',       type => 'T', },      
    { label => 'pkg_name',           type => 'C', },      
    { label => 'pkg_version',        type => 'C', },      
    { label => 'pkg_build',          type => 'I', },      
    { label => 'process_state',      type => 'C', },      
    { label => 'port',               type => 'I', },      
    { label => 'is_marketplace',     type => 'B', },      
    { label => 'marketpl_block',     type => 'I', },      
];

use constant PACKAGE_LIST_MAP => [
    { label => 'name',               type => 'C', },      
    { label => 'description',        type => 'C', },      
    { label => 'version',            type => 'C', },      
    { label => 'build',              type => 'I', },      
    { label => 'date',               type => 'C', },      
    { label => 'author',             type => 'C', },      
    { label => 'copyright',          type => 'C', },      
    { label => 'install_date',       type => 'T', },      
];


# Ordered fieldnames
use constant GET_ROBOT_FLDS    => map { $_->{label} } @{ GET_ROBOT_MAP()    };
use constant HUB_INFO_FLDS     => map { $_->{label} } @{ HUB_INFO_MAP()     };
use constant PROBE_LIST_FLDS   => map { $_->{label} } @{ PROBE_LIST_MAP()   };
use constant PACKAGE_LIST_FLDS => map { $_->{label} } @{ PACKAGE_LIST_MAP() };

# Field types
use constant GET_ROBOT_FLD_TYPE    => map { $_->{label} => $_->{type} } @{ GET_ROBOT_MAP()    };
use constant HUB_INFO_FLD_TYPE     => map { $_->{label} => $_->{type} } @{ HUB_INFO_MAP()     };
use constant PROBE_LIST_FLD_TYPE   => map { $_->{label} => $_->{type} } @{ PROBE_LIST_MAP()   };
use constant PACKAGE_LIST_FLD_TYPE => map { $_->{label} => $_->{type} } @{ PACKAGE_LIST_MAP() };

# Field LOVs
use constant GET_ROBOT_LOV  => map {$_->{label} => $_->{map}} grep {$_->{type} eq 'M'} @{ GET_ROBOT_MAP()  };
use constant PROBE_LIST_LOV => map {$_->{label} => $_->{map}} grep {$_->{type} eq 'M'} @{ PROBE_LIST_MAP() };

our @EXPORT = qw/
        GET_ROBOT_FLDS
        HUB_INFO_FLDS
        PROBE_LIST_FLDS
        PACKAGE_LIST_FLDS
        GET_ROBOT_FLD_TYPE
        HUB_INFO_FLD_TYPE
        PROBE_LIST_FLD_TYPE
        PACKAGE_LIST_FLD_TYPE
/;

use constant CONFIG_SECTIONS => qw/
  uim_prod
  uim_inventory_prod
/;

my $hub_info_template      = '#NIMROOT#/bin/pu -u#USER# -p#PASS# /#DOMAIN#/#HUB#/#ROBOTNAME#/controller gethub NULL';
my $get_robot_template     = '#NIMROOT#/bin/pu -u#USER# -p#PASS# /#DOMAIN#/#HUB#/#ROBOTNAME#/controller get_info NULL';
my $probe_list_template    = '#NIMROOT#/bin/pu -u#USER# -p#PASS# /#DOMAIN#/#HUB#/#ROBOTNAME#/controller probe_list NULL 1 NULL';
my $package_list_template  = '#NIMROOT#/bin/pu -u#USER# -p#PASS# /#DOMAIN#/#HUB#/#ROBOTNAME#/controller inst_list NULL';

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
sub get_robot { 
    my $self = shift;
    my $dataref = $self->__run( $get_robot_template, [GET_ROBOT_FLDS()], @_ ); #here 
    $dataref = __convert_datatypes( $dataref, {GET_ROBOT_FLD_TYPE()}, {GET_ROBOT_LOV()} );
    wantarray()? @$dataref : $dataref;
}
# synonyms for get_robot()
sub getrobot { return get_robot( @_ ) }
sub robotinfo { return get_robot( @_ ) }
sub get { return get_robot( @_ ) }

sub package_list { 
    my $self = shift;
    my $dataref = $self->__run( $package_list_template, [PACKAGE_LIST_FLDS()], @_ ); #here
    $dataref = __convert_datatypes( $dataref, {PACKAGE_LIST_FLD_TYPE()}, );
    wantarray()? @$dataref : $dataref;
}
# synonyms for package_list
sub get_packages  { return package_list( @_ ) }
sub list_packages { return package_list( @_ ) }
sub packagelist   { return package_list( @_ ) }
sub packages      { return package_list( @_ ) }

sub probe_list {
    my $self = shift;
    my $dataref = $self->__run( $probe_list_template, [PROBE_LIST_FLDS()], @_ ); #here
    $dataref = __convert_datatypes( $dataref, {PROBE_LIST_FLD_TYPE()}, {PROBE_LIST_LOV()} );
    wantarray()? @$dataref : $dataref; 
}
# synonyms for probe_list
sub get_probes  { return probe_list( @_ ) }
sub list_probes { return probe_list( @_ ) }
sub probelist   { return probe_list( @_ ) }
sub probes      { return probe_list( @_ ) }

sub hub_info {
    my $self = shift;
    my $dataref = $self->__run( $hub_info_template, [HUB_INFO_FLDS()], @_ ); #here
    $dataref = __convert_datatypes( $dataref, {HUB_INFO_FLD_TYPE()}, );
    wantarray()? @$dataref : $dataref;   
}

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
    my ($template,$attrs,@robotinfo) = @_;
    my %hub = make_hash( @robotinfo ) or
        throw TAPP::IllegalArgumentException(
            "Invalid arguments, hash expected in call to $caller()"
        );
    unless( defined $hub{hub} && defined $hub{robotname} && defined $hub{hubrobotname} ) {
      throw TAPP::MissingArgumentsException( 
         "Invalid arguments to $caller(), 'hub', 'hubrobotname' and 'robotname' are required arguments"
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
    $cmd =~ s/#ROBOTNAME#/$hub{robotname}/;
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
            robotname    => $hub{robotname},
            name         => $hub{robotname},
            message      => "Received a non-zero exit status when attempting to execute probe-utility command",
            command      => "$cmd_display",
            timedout     => 0,
            errorstr     => $pu->errorstr,
            exit_status  => $pu->exit_status,
          );
        }
    } catch {
      unless ( blessed $_ && $_->can('rethrow') ) {
        if (/timeout/) {
          throw TAPP::UIM::PUExecTimeout(
            domain       => $domain,
            hub          => $hub{hub},
            hubrobotname => $hub{hubrobotname},
            robotname    => $hub{robotname},
            name         => $hub{robotname},
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
            robotname    => $hub{robotname},
            name         => $hub{robotname},
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
      $_->{robotname}       ||= $hub{robotname};
    }
    
    wantarray? @$dataref : $dataref;
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
      die "Nothing to work with, in call to dehash()"; #here
    }
    $ret;
}
sub error { my $self = shift; $self->{error} = shift if @_; $self->{error} }
1;

