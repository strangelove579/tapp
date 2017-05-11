package TAPP::DB::Oracle;
{
  $TAPP::DB::Oracle::VERSION = '0.004';
}
use strict;
use TAPP::Exception;
use TAPP::Config::UNIVERSAL;
use Env qw(ORACLE_HOME LD_LIBRARY_PATH);
=pod

=head1 TAPP::DB::Oracle

A TAPP standardized interface to L<DBD::Oracle>. All exceptions caught, no die's. TAPP Global.conf
integrated. Cached connections and reconnect on failure. Single interface for Select, DML, and
PL/SQL.

=head1 Synopsis
  
    use TAPP::DB::Oracle;
    
    # Instantiate with connect, same as DBD Oracle
    # connections do not require TNS name, native libraries are used.
    $ora = TAPP::DB::Oracle->connect(
              user             => 'user',         # Required
              pass             => 'encrypted',    # Required, TAPP::HaS encryption string
              sid              => 'sid'           # Required
              host             => 'hostname',     # Required
        ) or die $TAPP::DB::Oracle::error;
  

=head1 Description

The C<TAPP::DB::Oracle> module is yet another L<DBD::Oracle> wrapper. However it comes with some
benefits over many similar modules. All methods that would normally C<die> on error, will not fail
in C<TAPP::DB::Oracle>. Connections always use the C<connect_cached()> method, so C<DBD::Oracle> with
*usually* reconnect with unintentionally disconnected. The C<exec()> method can be used for any
type of transaction (Select, DML, PL/SQL) and will return a cursor when 'Select'ing, otherwise
a boolean if not. You can pull the L<DBD::Oracle> connection directly to use functionality not provided,
while maintaining the C<TAPP::DB::Oracle> attribute content within the dbh object.

=head1 Methods

=cut



use DBD::Oracle;
use Scalar::Util qw/blessed/;
use Carp qw/carp cluck croak/;
use Try::Tiny;
use Data::Dumper qw/Dumper/;
use TAPP::Datastructure::Utils qw/:all/;

my @REQUIRED_PROPS = (
    qw/
            host     
            sid        
            user     
            pass
      /
);

my %UNIVERSAL_CONFIG_PROPS = (
  no_universal => 0,
  user_config => undef,  
);

my %OPTIONAL_PROPS = (
  oracle_home          => $ORACLE_HOME,
  ld_library_path      => $LD_LIBRARY_PATH,
  port                 => 1521,
  trace                => 0,
);
my %CONNECTION_OPTS = (
  AutoCommit   => 1,
  ora_verbose  => 'SKIP unless defined',  # trace = 9
  RaiseError   => 0,
  PrintError   => 0,
);

our %ALL_PROPS = map { $_ => undef } @REQUIRED_PROPS;
%ALL_PROPS = (%ALL_PROPS,%OPTIONAL_PROPS,%CONNECTION_OPTS,%UNIVERSAL_CONFIG_PROPS);

our $error = '';




=pod

=head2 connect( %HASH )

The C<connect()> method allows the following options. It also allows for .ini format files
containing the below options. Required fields are marked as such below. The password 'pass' must
be supplied as a valid hash compiled by L<TAPP::HaS>

The C<connect()> class method will write class errors: C<$TAPP::DB::Oracle::error>

    $ora = TAPP::DB::Oracle->connect(
              user             => 'user',         # Required
              pass             => 'encrypted',    # Required, TAPP::HaS encrypted string
              sid              => 'sid'           # Required
              host             => 'hostname',     # Required
              oracle_home      => 'path',         # Optional, default: $ENV{ORACLE_HOME}
              ld_library_path  => 'searchpath',   # Optional, default: $ENV{LD_LIBRARY_PATH}
              port             => ####            # Optional, default: 1521
              trace            => 0,              # Optional, default 0, pass-through to DBD::Oracle
              ora_verbose      => 0,              # Optional, default 0, pass-through to DBD::Oracle
              AutoCommit       => 1,              # Optional, default 1, pass-through to DBD::Oracle
              RaiseError       => 1,              # Optional, default 1, pass-through to DBD::Oracle
              PrintError       => 1,              # Optional, default 1, pass-through to DBD::Oracle              
        ) or die $TAPP::DB::Oracle::error;

The connect() class method will write class errors: $TAPP::DB::Oracle::error

    $ora = TAPP::DB::Oracle->connect( ... ) or die $TAPP::DB::Oracle:error;

OPTIONS:

=over 4

=item user

=over 4

The Oracle schema name

=back

=item pass

=over 4

A valid hash compiled by C<TAPP::HaS>

=back

=item sid

=over 4

SID or Service Name of the Oracle instance

=back

=item host

=over 4

Hostname where the instance resides

=back

=item oracle_home

=over 4

Optional, provide oracle_home if the C<$ENV{ORACLE_HOME}> variable is not set

=back

=item ld_library_path

=over 4

Optional, provide C<ld_library_path> if the C<$ENV{LD_LIBRARY_PATH}> variable is not set

=back

=item port

=over 4

Optional, default 1521

=back

=item trace

=over 4

Optional, enable tracing at the C<DBD::Oracle> layer

=back

=item ora_verbose

=over 4 

Optional, enable verbose errors at the C<DBD::Oracle> layer. Default 0

=back

=item AutoCommit

=over 4

Optional, pass-thru to L<DBD::Oracle>. Can also enable with C<$ora-E<gt>dbh-E<gt>{AutoCommit}>. Default 1

=back

=item RaiseError

=over 4

Optional, pass-thru to L<DBD::Oracle>. Triggers 'die' exceptions.
Can also enable with C<$ora-E<gt>dbh-E<gt>{RaiseError}>. Default 1


=back

=item PrintError

=over 4

Optional, pass-thru to C<DBD::Oracle>. Can also enable with C<$ora-E<gt>dbh-E<gt>{PrintError}>. Default 1

=back

=back

=cut

sub connect {
  my $class;
  my $self = {};
  my $error  = '';
  my $caller = (caller(0))[3];
  
  if (blessed( $_[0] ) && blessed( $_[0] ) eq __PACKAGE__) {
    $self = shift;
  } else {
    $class = shift;
    $class = ref($class) || $class;
    my %args = make_hash( @_ ) or
      throw TAPP::MissingArgumentsException (
        "Missing or mal-formed arguments in call to $caller(), expected HASH or HASHREF"
      );
#      use Data::Dumper qw/Dumper/;
 #   my %args = - 
    my %full_props = map { $_ => defined $args{$_} ? $args{$_} : $ALL_PROPS{$_} } keys %ALL_PROPS;
#    print Dumper( \%full_props); exit;
 #   print Dumper( $self ); exit;
    my %ini;
#    if ( $args{db} ) {
      my %opts;
 #     %opts = (%opts, no_universal => 1) if $args{no_universal};
 #     %opts = (%opts, user_config => $args{user_config}) if $args{user_config};
#      my $cfg = new TAPP::Config::UNIVERSAL( %opts );
     # my @sections = ('meta','oracle_standard','oracle_schemas');
#      %ini = $cfg->get_sections( @sections );
#      my $conn_hash = $ini{$args{db}};
      #%$self = (%full_props,%$conn_hash);
  #  } #else { 
      %$self = %full_props;
   #   %$self = (%full_props,user_config => $args{user_config}) 
    #     if $args{user_config};
  #  }
    bless $self, $class;
  }
  my $need_reconnect = $self->dbh() ? 0  : 1;
  return $self unless $need_reconnect;

  my %conn_props = map { $_ => $self->{$_} } keys %CONNECTION_OPTS;
  delete $conn_props{ora_verbose}
    if $conn_props{ora_verbose} =~ /SKIP/;
   
  my $conn_str = "dbi:Oracle:";
  $conn_str .= "$_=". $self->{$_} . ";" foreach qw/host sid port/;

  # Get ORACLE_HOME from the environment by default then fallback to config
  $ORACLE_HOME ||= $self->{oracle_home};

  # Define LD_LIBRARY_PATH if undef, else append to the path using ':' prefix
  $LD_LIBRARY_PATH  = defined $LD_LIBRARY_PATH ? $LD_LIBRARY_PATH . ':' : ''; 
  $LD_LIBRARY_PATH  .= $self->{ld_library_path};
  #print Dumper($self);
#exit; 
   my @conn_array = (
         $conn_str,
         $self->{user},
         __dehash($self->{pass}),
         \%conn_props,
      );
#  print Dumper(\@conn_array), "\n";
#  exit if $self->{user} eq 'sjc185p';

  try {
    $self->{dbh} = DBI->connect_cached( @conn_array ) or die $DBI::errstr;
  } catch {
    chomp;
    if (/SQL-01000/i) {
    } else {
      $self->is_connected() = 0;
      throw TAPP::DB::Oracle::ConnectionException(
            "Oracle Connection Failure in call to $caller(): $_\n"
      );
    }
  };
  # Ping test
  $self->ping();
  $self->is_connected() = 1;
  $self;
}

=pod

=head2 dbh()

Acquire the C<DBD::Oracle> connection directly to execute any features not directly provided by
C<TAPP::DB::Oracle>

=cut

sub dbh { 
  my $self = shift;
  $self->{dbh}
}

=pod

=head2 ping()

The C<ping()> method provides some indication of performance, network, or listener issues
It will not die the caller, errors should be checked with C<error()>

  try {
     $ora->ping() or die $ora->error();
  } catch {
     print "Ping Failed: $_";
  };

=cut


sub ping { 
  my $self = shift;
  my $caller = (caller(0))[3];
  unless ($self->dbh()) {
    $self->is_connected() = 0;
    throw TAPP::DB::Oracle::ConnectionException(
      "Not connected to oracle in call to $caller()\n"
    );
  }  
  try { 
    $self->{dbh}->ping() or die $DBI::errstr;
  } catch {
    chomp;
    throw TAPP::DB::Oracle::PingException("Ping() failed in call to $caller(): $_\n");
  };
  1;
}

=pod

=head2 begin_work()

Perform multi-statement transactions by first calling begin_work(). This is only necessary when 
C<AutoCommit> is enabled, as it will disable autocommit and start a multi-statement 
transaction that must be committed or rolled-back when finished.

Be aware that begin_work() will have no effect if AutoCommit is not enabled

In its simplest form:

  $ora->begin_work();
  $ora->exec( 'insert...' );
  $ora->exec( 'insert...' );
  $ora->exec( 'insert...' );
  $ora->finish();
  
However, rolling back a transaction on error is the better method of performing transactions:

  try {
    $ora->begin_work()        or die $ora->error();
    $ora->exec( 'insert...' ) or die $ora->error();
    $ora->exec( 'insert...' ) or die $ora->error();
    $ora->exec( 'insert...' ) or die $ora->error();
    $ora->finish()            or die $ora->error();
  } catch {
    $ora->rollback();
    print "ERROR: " . $_, "\n";
  };


=cut


sub begin_work {
    my $self = shift;
    my $caller = (caller(0))[3];
    unless ($self->dbh()) {
      $self->is_connected() = 0;
      throw TAPP::DB::Oracle::ConnectionException(
        "Not connected to oracle in call to $caller()\n"
      );
    }
    return 1 unless $self->{dbh}->{AutoCommit};
    try { 
        $self->{dbh}->begin_work() or die $DBI::errstr;
    } catch {
      chomp;
      throw TAPP::DB::Oracle::TransactionException( $_. "\n");
    }; 
    1;
}

=pod


=head2 finish()

Complete a transaction, or otherwise close a statement handler. Automatically re-enables AutoCommit
if it was set to true upon calling C<begin_work()>

  $ora->finish() or die $ora->error();

=cut

sub finish {
    my $self = shift;
    my $caller = (caller(0))[3];
    unless ($self->dbh()) {
      $self->is_connected() = 0; 
      throw TAPP::DB::Oracle::ConnectionException(
        "Not connected to oracle in call to $caller()\n"
      );
    }
    return 1 if $self->{dbh}->{AutoCommit};
    my $finished = 0;
    try { 
       if ($self->{sth}) { 
         $self->{sth}->finish() or die $DBI::errstr;
         $self->commit unless $self->dbh()->{AutoCommit};    
         $finished = 1;
       }
    } catch {
       throw TAPP::DB::Oracle::TransactionException(
        "Failed to close statement handler in call to $caller()\n"
      );
    };   
    return $finished;
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

=pod

=head2 exec( SCALAR )

SELECT - Executing Select statements will sets C<LongTruncOk> automatically,
as well as C<LongReadLen> to 5000, and returns a cursor (statement handler)
Errors are instance errors

  $cursor = $ora->exec( 'select ... from ...' ) or die $ora->error();
  while (my $row = $cursor->fetchrow_hashref() ) { 
    ...
  }
  
DML - calling C<exec()> on C<DML> or C<PL/SQL> will return a boolean result, for C<DML> operations, the
C<rows()> method will return the number of rows affected

  $result = $ora->exec( "update table set foo = 'bar' where baz = 'qux'" ) or die $ora->error();
  print "Rows Affected: " . $ora->rows();

=cut

sub exec {
    my $self = shift;
    my $caller = (caller(0))[3];
    my $dbh;
    unless ($dbh = $self->dbh()) {
      $self->is_connected() = 0;
      throw TAPP::DB::Oracle::ConnectionException(
        "Not connected to oracle in call to $caller()\n"
      );
    }
    my $SQL = shift;
    my $want_cursor = 1 if $SQL =~ /^\s*select/msgi;
    $self->finish() if $self->{sth};
    $self->{sth} = undef;

    try {
      $self->{sth} = $self->{dbh}->prepare($SQL) or die $DBI::errstr;
    } catch {
      chomp;    
      throw TAPP::DB::Oracle::PrepareSQLException(
        message => "Failed to prepare SQL Statement in call to $caller(): $_",
        sql => $SQL,
      );
    };
      
    $self->{sth}->{'LongTruncOk'} = 1;
    $self->{sth}->{'LongReadLen'} = 5000;
    try {
      $self->{sth}->execute() or die $DBI::errstr;
    } catch {
      chomp;
      throw TAPP::DB::Oracle::SQLException(
          message => "Failed to execute SQL statement in call to $caller(): $_",
          sql     => $SQL,
      );
    };
    $want_cursor ? $self->{sth} : 1;
}

=pod

=head2 rows()

Returns a row count after executing C<DML>, returns 0 for C<SELECT> statements

  $ora->exec( "update foo set bar = 'baz'" );
  print $ora->rows() . " rows updated.\n";
  # returns affected row count
  
  $ora->exec( "select bar from foo" );
  print $ora->rows() . " rows returned.\n";
  # will always return 0
    

=cut

sub rows { 
    my $self = shift;
    my $caller = (caller(0))[3];
    unless ($self->dbh()) {
      $self->is_connected() = 0;
      throw TAPP::DB::Oracle::ConnectionException(
        "Not connected to oracle in call to $caller()\n"
      );
    }   
    return -1 unless $self->{sth};
    return $self->{sth}->rows();
}


=pod

=head2 is_connected()

Test if C<DBD::Oracle> connection is alive. One of several methods.

  $ora->is_connected() or try {
    $ora->reconnect() or die $TAPP:DB::Oracle::error;
  } catch {
    print $_,"\n";
  };

=cut


sub is_connected : lvalue { return shift()->{is_connected} }

=pod

=head2 reconnect()

Reconnect your session using the same arguments as the last C<connect()> invocation

  unless ( $ora->ping() ) {
    $ora->reconnect() or die $TAPP:DB::Oracle::error;
  }

=cut


sub reconnect {
    my $self = shift;
    if ( $self->{dbh} ) {
        $self->finish();
        $self->disconnect();
    }    
    $self->connect();
    1;
}

=pod

=head2 disconnect()

Disconnect current connection

  $ora->disconnect() or die $ora->error()

=cut

sub disconnect {
  my $self = shift;
  return 1 unless $self->{dbh};
  $self->finish() if $self->{sth};
  $self->commit() unless $self->{dbh}->{AutoCommit};
  $self->{dbh}->disconnect;
  undef $self->{dbh};
  $self->is_connected() = 0;
  1;
}

=pod

=head2 rollback()

Rollback the current transaction. Warning is thrown on useless C<rollback()> when C<AutoCommit> is true

  $ora->rollback() or die $ora->error();

=cut

sub rollback {
    my $self = shift;
    my $caller = (caller(0))[3];
    unless ($self->dbh()) {
      $self->is_connected() = 0;
      throw TAPP::DB::Oracle::ConnectionException(
        "Not connected to oracle in call to $caller()\n"
      );
    }    
    unless ($self->{dbh}->{AutoCommit}) {
      try {
        $self->{dbh}->rollback or die $DBI::errstr;
      } catch {
        chomp;      
        throw TAPP::DB::Oracle::TransactionException(
          "Failed to rollback transaction in call to $caller(): $_\n"
        );
      }
    }
    $self->{in_transaction} = 0;      
    1;
}

=pod

=head2 commit()

Commit the current transaction. Warning is thrown on useless C<commit()> when C<AutoCommit> is true

  $ora->commit() or die $ora->error();

=cut

sub commit {
    my $self = shift;
    my $caller = (caller(0))[3];
    unless ($self->dbh()) {
      $self->is_connected() = 0;
      throw TAPP::DB::Oracle::ConnectionException(
        "Not connected to oracle in call to $caller()\n"
      );
    }
    return 1 if $self->{dbh}->{AutoCommit};
    try { 
      $self->{dbh}->commit or die $DBI::errstr;
    } catch { 
      chomp;    
      throw TAPP::DB::Oracle::TransactionException(
          "Failed to commit to the database in call to $caller(): $_\n"
      );
    };
    1;
}

sub DESTROY {
  my $self = shift;
  $self->disconnect() if $self->{dbh}  
}

=pod
  
=head1 Author

John Achee E<lt>jrachee@gmail.comE<gt>

=head1 TODO

Add support to use C<exec()> for parameterized PL/SQL

Add support to pass statement-handler options to C<exec()>

Allow any L<DBI> or L<DBD::Oracle> option to be passed through in calls to C<connect()>


=head1 Bugs

None reported at this time

=head1 See Also

L<DBI>

L<DBD::Oracle>

L<TAPP::Datastructure::Utils>

=cut

1;



