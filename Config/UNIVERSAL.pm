package TAPP::Config::UNIVERSAL;
{
  $TAPP::Config::UNIVERSAL::VERSION = '0.001';
}
use File::Basename;
use Env qw(TAPPROOT);

my $tappconf = "$TAPPROOT/conf/.tapp.conf";
#my $tappconf = '/u01/oracle/newsvns/tapp/trunk/conf/.tapp.conf';
=pod

=head1 TAPP::Config::UNIVERSAL

Provides access to the TAPP Universal configuration definitions, contained
within tapp/conf/.global.conf. Requires the CPAN module L<Config::IniFiles>

=head1 Synopsis
  
    
    use TAPP::Config::UNIVERSAL;
    
    # Load configuration from tapp 'global.conf' shared config by default
    $unicfg = TAPP::Config::UNIVERSAL->new();
    
    # Use a different config file
   unicfg = TAPP::Config::UNIVERSAL->new( user_config => 'F:/tapp/conf/global.conf' );
    
    # Get .ini config sections merged
    my $cfg = $unicfg->get_sections( 'oracle_standard','oracle_chsops-dev' );
    
    
    
=head1 Description

The TAPP Universal configuration file stores 'default arguments' to TAPP API's. Everything
from 'max_logfile_size' to Oracle database connection parameters, are stored in the universal
config file, and MUST be used by any perl batch jobs and applications in production. The
universal file provides single location configuration across all perl-based automations.

Local 'application specific' configurations should not be stored in the Universal configuration
file and should be imported normally using Config::IniFiles or TAPP::Config.

=head1 Methods

=cut



use TAPP::Datastructure::Utils qw/:all/;
use TAPP::Exception;
use Config::IniFiles;
use File::Basename;
use Carp qw/croak/;
use File::Spec;


=pod

=head2 config ( LIST )

Returns a hash containing configurations from the Universal configuration file.

  my %config = uni_config();


Options:

=over 4

=item sections => [LIST]

=over 4

The 'sections', the values are matched against .ini file sections of the
Universal config, and only these config sections are returned in the hash. 

  my %config = uni_config( sections => ['sqllib_standard'] );

If the argument list contains a section name that does not match within the Universal
config, a fatal exception occurs.
  
  my %config = uni_config( sections => ['non-existant-section'] );
  # execution dead
     
=back  

=item local => PATH

=over 4

The 'local' argument will override the location of the Universal configuration file, such as for
local development usage.

  my %config = uni_config( local => 'filepath' );
  
=back

=back

=cut  


sub new {
  my $class = shift;
  my $self = {};
  my $caller = (caller(0))[3];
  my %args;
  my @configs;
  
  bless $self, $class;
  if (scalar @_) {
      %args = make_hash( @_ ) or
        throw TAPP::IllegalArgumentException("Invalid hash in call to $caller()\n");
  }
  $args{user_config} = $args{override_config} if $args{override_config};
  
  if ($args{user_config}) {
    if ( -f $args{user_config} ) {
      push @configs, $args{user_config};
    } else {
      throw TAPP::FileNotFoundException("Config file [$args{user_config}] not found in call to $caller()\n");
    }
  }
  unless( $args{no_universal} ) {
    unless ( -f $tappconf ) {
      throw TAPP::FileNotFoundException("Config file [$tappconf] not found in call to $caller()\n");
    } else {
      push @configs, $tappconf;
    }
  }
  $self->{cfgfiles} = \@configs;
  $self->__load_config( \@configs );
  $self;
}

sub __load_config {
  my $self = shift;
  my $caller = (caller(0))[3];
  my $cfiles = shift;
  my %all_cfgs;
  foreach my $file(@$cfiles) {
    my %ini;
    tie %ini, 'Config::IniFiles', ( -file => $file );
    if ( @Config::IniFiles::errors ) {
      my $ini_error = 'Config::IniFiles::error: ' . join ( ". ", @Config::IniFiles::errors );
      $ini_error =~ s/\n/ /g;
      $ini_error =~ s/\t//g;
      throw TAPP::Config::UNIVERSAL::ConfigParseException($ini_error. " in call to $caller()\n");
    }
    
    my %temp = ();
    ## Un-tie hash
    foreach my $k ( keys %ini ) {
      foreach my $sk ( keys %{$ini{$k}} ) {
        my $val = $ini{$k}->{$sk};
        $temp{$k}->{$sk} = $val;
      }
    }
    %all_cfgs = (%all_cfgs, %temp);
    %ini = ();
  }
  $self->{ini} = \%all_cfgs;
  $self;
}

sub get_sections {
  my $self = shift;
  my $caller = (caller(0))[3];
  my @sections = @_;
  my %ini = %{ $self->{ini} };
  my $want_all = 1 unless scalar @sections;
  @sections = keys %ini unless scalar @sections;

  my %data = ();
  foreach my $section ( @sections ) {
    throw TAPP::Config::UNIVERSAL::MissingSectionException(
        "Section [$section] not found in config file [".$self->{cfgfile}."] in call to $caller()\n"
    ) unless ref( $ini{$section} ) eq 'HASH';
    if ($want_all ) { 
      %data = (%data, $section => $ini{$section});
    } else {
      %data = (%data, %{ $ini{$section} });
    }
  }

  
  %data = scalar keys %data ? %data : ();
  return wantarray()? %data : \%data;
}

sub get_oraconn { 
  my $self = shift;
  my ($schema,$dc) = @_;
  $_ = lc $_ foreach ($schema,$dc);
  my $caller = (caller(0))[3];
  my %ini = %{ $self->{ini} };
  my $schemas =   $ini{'oracle_schemas'};
  foreach (keys %$schemas) { 
    /^(${dc}_$schema)$/ && 
       do { my $connstring = $schemas->{$1};
            my ($host,$ip,undef,$user,undef,$pass,undef,$sid) = split /[:;]/, $connstring;
            return {host => $host, ip => $ip, user => $user, sid => $sid, pass => $pass};
            
       };
   }
   return {};
}



=pod

=head1 Author

John Achee E<lt>jrachee@gmail.comE<gt>

=head1 TODO

None at this time

=head1 Bugs

None reported at this time

=head1 See Also

L<Config::IniFiles>

=cut

1;

