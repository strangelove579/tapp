package TAPP::Job::Manager;
{
  $TAPP::Job::Manager::VERSION = '0.002';
}
use strict;
=pod

=head1 TAPP::Job::Manager

Interface to the I<TAG Unified Job Scheduler>. The job scheduler releases jobs to the caller if a job is ready
for execution, based on a defined schedule.

=head1 Synopsis
  
    use TAPP::Job::Manager;
    
    # Connect to a job scheduler
    $jm = TAPP::Job::Manager->connect(
                  db     => 'tagdev',
                  job_id => '123'
            ) or die $TAPP::Job::Manager::error;
    
    # Do not execute this program if its not time to do so
    exit unless $jm->job_ready;
    
    # ...executable code..
    
    # Periodically tell the job scheduler that we're still alive
    $jm->heartbeat;
    
    # ...executable code...
    
    # Tell the job scheduler that we're finished
    $jm->finish
    
    exit;
    
    
=head1 Description

This module interfaces with the I<TAG Unified Job Scheduler>, and manages the execution time of batch jobs,
scheduled scripts and applications.

The I<TAG Unified Job Scheduler> consists of a series of functions and tables within the TAG Oracle
application schemas (tagprod, tagtest, and tagdev). The scheduler is obfuscated from the caller. 

B<Monitoring>

The scheduler also stores a 'heartbeat' for every job, and is updated in calls to C<job_ready()> and
C<heartbeat()>. The hearbeat can be monitored by UIM or any monitoring application. A call to C<job_ready()> will
automatically update the heartbeat for the job, but during execution - any long
running jobs or code blocks may cause the heartbeat to go stale, unless the C<heartbeat()> method is called often
in your code. It is advisable to make calls to heartbeat() as often as possible to avoid triggering
heartbeat-related alarms when monitoring is configured to watch this timestamp.

B<Job Manager Operations>

=over 4

C<connect()> - Establish a connection to the Job Scheduler, and load the job definition

C<job_ready()> - Asks the scheduler if this job is ready to execute based-on the schedule and enabled
                 state of the job.
                 
C<heartbeat()> - Informs the scheduler that the current job is still running

C<finished()> - Informs the scheduler that the job is finished

Any attempt to exit the program without finishing the job will die the program.

=back

B<Cron>

=over 4

Any script or application that interfaces with the I<TAG Unified Job Scheduler>, should execute
C<job_ready()> on a I<frequent interval>, so that the heartbeat does not get stale, and to ensure your
job starts on-time. This must be done by running the script or application on a short interval. Executing
on a 2 minute within cron (or Task Scheduler on windows) is advised.

=back

=head1 Methods

=cut

use TAPP::Config::UNIVERSAL;
use TAPP::Datastructure::Utils qw/:all/;
use TAPP::Exception;
use Try::Tiny;
use Scalar::Util qw/blessed/;
use TAPP::DB::Oracle; 
use Carp qw/croak/;

=pod

=head2 connect ( %HASH )

Instantiate a job manager. This establishes a connection to the I<TAG Unified Job Scheduler>, and 
loads the job definition by Job ID. Internally, it loads the TAPP universal configuration 
definitions, to extract the database instance host, user, and password stored for the database 
defined by the 'db' argument. I<The 'db' supplied MUST exist in the TAPP Universal configuration file>.
See L<TAPP::Config::UNIVERSAL> for more information about the TAPP Universal configuration file.

  $jm = TAPP::Job::Manager->connect( db => 'tagdev', job_id => '123' );

Arguments:

=over 4

=item db => SCHEMA_ID

=over 4

Required. The 'db' argument accepts a Schema ID of an oracle database housing the job scheduler
interface (procedure). Schema ID's are one of: tagprod, tagdev, tagtest, tagstage

=back

=item job_id => JOB_ID_NO

=over 4

Required. The ID of this job as stored in the schedule table within the target 'db'

=back

=item uni_config => PATH

=over 4

Optional. This module uses the TAPP Universal config file. Override the location of
file with the uni_config option

=back

=back

=cut


sub connect {
  my $class = shift;
  $class = ref($class) || $class; 
  my $self  = {};
  bless $self, $class;
  my $caller = (caller(0))[3];
  my %args   = make_hash(@_)
    or throw TAPP::IllegalArgumentException(
        "Invalid call to 'connect', only a HASH with 'force' or 'db' key is allowed in call to $caller()"
      );
  unless ( defined $args{dbh} || ( defined $args{db} && defined $args{schedule_id} )) {
      throw TAPP::MissingArgumentsException(
          "Missing arguments, 'db' and 'schedule_id' are required in call to $caller(), optionally replace db with dbh connection"
        );
  }
  $self->{schedule_id} = $args{schedule_id};
  
  if ( $args{dbh} ) { 
    $self->dbh( $args{dbh} );
  } else {  
    $self->{ora_options}     = $args{ora_options};
    #$self->__load_config( $args{user_config} );   
    $self->__db_connect( $self->{ora_options}  );
  }
  #use Data::Dumper qw/Dumper/;
  $self;
}

sub __load_config {
    my $self = shift;
    my $uni;
    my $caller = (caller(0))[3];
    if ( my $file = shift() ) {
      unless ( -f $file ) {
        throw TAPP::IllegalArgumentException(
            "Invalid argument to $caller(), file $file does not exist"
        )
      }
      $uni = TAPP::Config::UNIVERSAL->new( user_config => $file );
    } else {
      $uni = TAPP::Config::UNIVERSAL->new();
    }
    my @sections = ("oracle_standard", "oracle_" . $self->{db_name});
    my %ini = $uni->get_sections(@sections);
    $self->{cfg} = \%ini;
    1;
}

sub __db_connect {
  my $self = shift;
  my $oracle_args = shift if @_;
  $self->dbh( TAPP::DB::Oracle->connect( %$oracle_args ) );
  $self->dbh()->ping();
  $self;
}
sub dbh {
  my $self = shift;
  $self->{dbh} = shift if @_;
  $self->{dbh}
}
=pod

=head2 job_ready( %HASH )

Returns a numeric job_id from the scheduler if this job is ready to execute,
based on the job schedule defined in the I<TAG Unified Job Scheduler>. job_ready() also posts a
heartbeat(), see heartbeat() below.

  # Obey the start time as defined in the scheduler
  # When ready - updates the start time of the job, the heartbeat, and returns a
  # true value
  unless( $jm->job_ready() ){
    print "Its not time to execute this program, exiting...\n";
    exit 0;
  }
  
Optional Arguments:

=over 4

=item force => 1|0

=over 4

Force the job to start, ignoring the schedulers start time requirement. Be aware that by ignoring
the start time requirement, this will cause any active/passive HA to become active/active, which is
likely to be problematic. force should only be used in single node environments.

  # Always puts the job in a running state. Always returns a true value
  $jm->job_ready( force => 1 );

=back

=back

=cut

sub get_db_connection {
  my $self = shift;
  my $caller = (caller(0))[3];
  my $reconnected = 0;
  try {
    $self->dbh->ping;
  } catch {
      die $_ unless blessed ($_) && $_->can('rethrow');
      if ( $_->isa('TAPP::DB::Oracle::ConnectionException')) {
          try {
            $self->dbh->reconnect;
            $reconnected = 1;
          } catch {
            die $_ unless blessed ($_) && $_->can('rethrow');
            throw TAPP::Job::Manager::DBNotConnectedException(
               "Failed to reconnect to the database in $caller()"
            );  
          };
      }      
  };
  # Test connection once more, catch exceptions in the caller
  if ( $reconnected  ) {
    try { 
      my $sth = $self->dbh->exec('select * from dual');
      my $val = $sth->fetchrow_arrayref();
    } catch {
      die $_ unless blessed ($_) && $_->can('rethrow');
      throw TAPP::Job::Manager::DBNotConnectedException(
        "Failed to execute DML test after successful connection test in caller $caller()"
      );
    };
  }
  $self->dbh();
}

sub job_ready {
  my $self = shift;
  my $caller = (caller(0))[3];
  my %args = make_hash(@_) or do {
      unless (scalar @_ == 0) {
        throw TAPP::IllegalArgumentException(
            "Illegal argument in call to $caller()"
        );
      }
  };
  if ( scalar keys %args && ! defined $args{force} ) {
    throw TAPP::IllegalArgumentException(
      "Illegal argument in call to $caller(), arguments must be HASH, and only 'force' is allowed"
    );
  }  
  my $force = $args{force} ? 'Y' : 'N';
  my $dbh = $self->get_db_connection->dbh;
  my ($job_id,$answer);
  my $schedule_id = $self->{schedule_id};
  my $func = $dbh->prepare(q{
      DECLARE
          xSQLERRM VARCHAR2(2000);
      BEGIN
          :answer := tag_sch_job_get_f( :schedule_id, :force, :pid, :job_id );
      EXCEPTION
        WHEN OTHERS THEN
          xSQLERRM := SQLERRM;
          :answer := 'Unexpected PL/SQL Exception in call to tag_sch_job_get_f(): '||xSQLERRM;
      END;
  });  # exception from Oracle package will pass thru
  $func->bind_param(":schedule_id", $schedule_id);
  $func->bind_param(":force",  $force);
  $func->bind_param(":pid",  $$);
  $func->bind_param_inout(":answer", \$answer, 255);
  $func->bind_param_inout(":job_id", \$job_id, 255);
  $func->execute;
  if ( defined $answer && $answer !~ /^[01]$/ ) {
    $dbh->rollback unless $dbh->{AutoCommit};
    throw TAPP::Job::Manager::BadExitException(
      "PL/SQL procedure 'tag_sch_job_get_f() failed to exit safely. Got unexpected response: ["
      . $answer ."] in call to $caller"
    );
  }
  $dbh->commit unless $dbh->{AutoCommit};
  $self->running = 1 if int($answer) eq $answer && $answer == 1;
  $job_id;
}


=pod

=head2 heartbeat()

Informs the scheduler that the current job is still running. Internally, the job schedule
table is updated with the current date/time in the heartbeat column. This attribute of a job
is typically monitored by the production monitoring system, ie: UIM. Therefore, it is advisable
to make calls to heartbeat often within long running scripts, apps, or code blocks. it is also
advisable to tune the threshold of any monitor, to a reasonable value given the nature of a healthy
heartbeat interval.

  $jm->heartbeat()
  
=cut

sub heartbeat {
  my $self = shift;
  my $caller = (caller(0))[3];
  my $dbh = $self->get_db_connection->dbh;
  my $answer;
  my $schedule_id = $self->{schedule_id};
  my $func = $dbh->prepare(q{
      DECLARE
          xSQLERRM VARCHAR2(2000);
      BEGIN
          :answer := tag_sch_job_heartbeat_f( :schedule_id );
      EXCEPTION
        WHEN OTHERS THEN
          :answer := 'Unexpected PL/SQL Exception in call to tag_sch_job_heartbeat_f(): '||xSQLERRM;
      END;
  }); 
  $func->bind_param(":schedule_id", $schedule_id);
  $func->bind_param_inout(":answer", \$answer, 255);
  $func->execute;
  $dbh->commit unless $dbh->{AutoCommit};
  $answer eq '1' ? $answer : undef; # TODO: Throw exception here
}


=pod

=head2 finish()

Informs the scheduler that the job is finished. Internally, the schedule table is updated with a
completion date/time, and the job becomes available to the next job scheduler call for this job ID.

  $jm->finish()
  
NOTE: A failure to call to finish() method before script completion, will cause an fatal exception
in the caller.

=cut

sub finish {
  my $self = shift;
  my $caller = (caller(0))[3];
  my %args = make_hash( @_ ) or 
      throw TAPP::IllegalArgumentException(
          "Illegal argument list in call to $caller(), expected HASH"
      );
  unless ( exists $args{errored} && exists $args{errm} ) {
    throw TAPP::IllegalArgumentException(
      "Illegal argument list in call to $caller(), 'errored' and 'errm' are required"
    );
  }
  my $dbh = $self->get_db_connection->dbh;
  my $answer;
  $args{errored} = defined $args{errored} && $args{errored} eq '1' ? '1' : '0';

  my $func = $dbh->prepare(q{
      DECLARE
          xSQLERRM VARCHAR2(2000);
      BEGIN
          :answer := tag_sch_job_finish_f( :scheduler_id, :errored, :errm );
      EXCEPTION
        WHEN OTHERS THEN
          :answer := 'Unexpected PL/SQL Exception in call to tag_sch_job_finish_f(): '||xSQLERRM;
      END;
  }); 
  $func->bind_param(":errored", $args{errored});
  $func->bind_param(":errm",    $args{errm});
  $func->bind_param(":scheduler_id",  $self->{schedule_id});
  $func->bind_param_inout(":answer", \$answer, 255);
  $func->execute;
  $dbh->commit unless $dbh->{AutoCommit};
  my $result = defined $answer && $answer =~ /^[01]$/ ? 1 : 0; 
  unless ($result) {
      throw TAPP::Job::Manager::UnfinishedException(
        "Unexpected result from tag_sch_job_finish_f() database procedure [$answer], in call to $caller()"
      );
  }
  $self->running = 0;
  $result;
}

=pod

=head2 error()

Retrieve the current error for the job manager object

  $jm->finished() or die $jm->error;
  
=cut

sub error {
  my $self = shift;
  $self->{error} = shift if @_;
  $self->{error}
}
1;

sub running : lvalue { shift()->{running} }

=pod

=head1 Author

John Achee E<lt>jrachee@gmail.comE<gt>

=head1 TODO

None at this time

=head1 Bugs

None reported at this time

=head1 See Also

Database function TAGDEV.TAG_JOB_SCHEDULER_GET_JOB()

Database function TAGDEV.TAG_JOB_SCHEDULER_FINISH_JOB()

Database table TAGDEV.TAG_JOB_SCHEDULER_HEARTBEAT()

=cut

1;


