package TAPP::Logger;
{
  $TAPP::Logger::VERSION = '0.004';
}
use strict;

use base qw/Class::Accessor/;
use Sys::Syslog qw(:DEFAULT setlogsock);
use File::Path qw/make_path/;
use Carp qw/croak/;
use File::Basename qw/dirname/;
use POSIX qw/strftime/;
use TAPP::Datastructure::Utils qw/:all/;
use TAPP::Exception;

=pod

=head1 TAPP::Logger

A simple logging module with C<Syslog> failover and configurable log rotation

=head1 Synopsis
  
    use TAPP::Logger;
    
    $log = TAPP::Logger->new( filename => 'path', max_log_size => 10_000_000 );
    
    # Write a timestamped message to the log, automatically failover to SysLog
    $log->write( 'foo' );
    
    # Write a series of messages to the log
    $log->write( 'foo', 'bar', 'baz' );
    
    # Rotate logs and create a new log file created, if max_log_size is exceeded
    $log->rotateLogs();
    
    
=head1 Description

This module creates and writes timestamped messages to a log file. If the file is unreachable or
otherwise cannot be written to, it will log messages to C<SysLog> when running on *nix.

Log rotation can be performed, but is not performed by default until C<DESTROY()> is called. A
call to C<rotateLogs()> will check if C<max_log_size> has been exceeded, and if so, will rotate
the logs keeping a total of 5 preserved log files.

=cut

our %DEFAULT_ATTRS = ( 
    filename     => undef,
    max_log_size => 5_000_000,
    ERROR        => '',
    silent       => 0,
);
__PACKAGE__->mk_accessors( keys %DEFAULT_ATTRS );



=pod

=head2 new ( %HASH )

Instantiate a logger. Creates the log file and directory path if the file doesn't exist.

  $log = TAPP::Logger->new( filename => '/my/path/to/app.log' );

Arguments:

=over 4

=item filename => PATH

=over 4

Required. The file and directory structure to the file will be created if the file does not exist

=back

=item max_log_size => BYTES

=over 4

Optional, default = C<10_000_000>. When calling C<rotateLogs()>, the max size allowed before a log is
rotated

=back

=item silent => 1|0

=over 4

Optional, default 1. Puts logger on silent mode, which suppresses messages to STDOUT.

=back

=back

=cut

sub new {
  my $class = shift;
  $class = ref($class) ? ref($class) : $class;
  my $self = {};
  my $caller = (caller(0))[3];
  my %args = make_hash(@_)
    or throw TAPP::IllegalArgumentException("Hash expected in call to $caller()");
  unless ( defined $args{filename} ) {
    throw TAPP::MissingArgumentsException("'filename' is a required argument in call to $caller()")
  }
  croak "filename is a required argument in call to new()"
    unless $args{filename};
  my $dirname = dirname( $args{filename} );
  unless (-d $dirname ) {
    make_path( $dirname )
      or throw TAPP::IOException("Failed to create directory $dirname: $!, in call to $caller()");
  }
  unless ( -f $args{filename} ) {
    open(my $fh, ">", $args{filename})
      or throw TAPP::FileIOException("Failed to create file $args{filename}: $!, in call to $caller()");
    close $fh;
  }
  %{$self} = (%DEFAULT_ATTRS,%args);
  bless $self,$class;
  return $self;
}

=pod

=head2 rotateLogs()

The C<rotateLogs()> method rotates log files by first checking if the size has exceeded C<max_log_size>,
keeping a total of 5 preserved logs

    $log->rotateLogs();

Destruction of a logger object, such as when there are 0 references pointing to it, will trigger C<logRotate()>
automatically.

=cut

sub rotateLogs {
  my $self = shift;
  my $max_log_size = @_ ? shift : $self->{max_log_size};
  my $current_log = $self->{filename};
  my @log = map { "$current_log.$_" } (1..5);
  if (-s $current_log > $max_log_size) { # 5 MB
	unlink $log[4] if -e $log[4];
	my $i = @log;
	while ( $i-- ) {
	  rename $log[$i], $log[$i+1] if -e $log[$i];
	}
	rename $current_log, $log[0] if -e $current_log;
	qx(touch $current_log);
  }
  return 1;
}

=pod

=head2 write( LIST|ARRAYREF )

The C<write()> method prints an array or arrayref to the log file. Each line is prefixed by a
timestamp of the current time. Messages are echo'd to C<STDOUT> without timestamps. If the 'silent'
attribute is set on the logger object, messages are not echo'd.
    
    # Write a single message, echo'd to STDOUT
    $log->write('foo');
    
    $log = new TAPP::Logger( filename => 'path', silent => 1 );
    # Will not be echo'd to STDOUT:
    $log->write( 'foo' );
    
    # Each array value will be written on its own line:
    $log->write('foo','bar','baz');
    
    # ..which is treated the same as:
    $log->write(['foo','bar','baz']);

B<Locking>

=over 4

The logger will attempt to place an implicit lock on the file with every call to C<write()>. It does
this by calling C<flock()> on the file handle. If C<flock()> fails the write will fail and return undefined

=back

B<Buffering>

=over 4

Buffering does not occur, messages are not cached and will be written as they are received.

=back

B<Attempts>

=over 4

The C<write()> method will make many attempts to write a message to the log file, up to 100! Each failure
sleeps the logger for 30 seconds, before a re-attempt. If after 100 attempts, the write fails, an
error will be written to syslog, and C<write()> will return undefined.

=back

=cut

sub write {
  my $self = shift;
  return undef unless @_;
  my $timestamp = strftime("[%Y-%m-%d %H:%M:%S]",localtime(time()));
  my $LOG;
  $LOG = __open($self->{filename},$LOG);
  return unless $LOG;
  #unless ( flock($LOG, 2) ) {
  #  __sysLogMsg("Error obtaining exclusive flock on $$self{filename}: $!");
  #  return undef;
  #}
  my @msg = @_;
  if ( is_arrayref(@_) ) {
    @msg = @{$_[0]};
  }
  # File message
  select $LOG;
  $|++;
  print $LOG join "", (map {"$timestamp $_\n"} @msg);
  # STDOUT message
  close $LOG;  
  select STDOUT;
  $|++;
  print STDOUT join "", (map { $_ . "\n"} @msg) unless $self->{silent};
  1;
}


sub __sysLogMsg {
  return if $^O eq 'MSWin32';
  my $msg = shift || "Generic failure";
  setlogsock("unix");
  my ($pgmname) = ($0 =~ m'([^/]+)$');
  openlog("$pgmname", "", "user");
  syslog("info","$msg");
  closelog;
}

sub __open {
    my $filename = shift;
    my $openFail = "Failed to open log file $filename";
    my $LOG = shift;
    foreach my $i (1..100) {
        eval {
		    (my $logdir = $filename) =~ s/\/[^\/]*$//;
             mkdir $logdir, 0775 unless -d $logdir;
             open ($LOG, " >> $filename") || die "$!";
        };

        if ($@) {
            print $openFail ." trying again in 30 seconds\n";
            sleep(30);
        }
        else {
            return $LOG;
        }
    }
    __sysLogMsg("$openFail, tried 100 times in 30 sec intervals. Done trying...");
    return $LOG;
}


sub error {
  my $self = shift;
  return $self->{ERROR};
}

sub DESTROY {
	my $self = shift;
  $self->rotateLogs();
  1;
}

=pod

=head1 Author

John Achee E<lt>jrachee@gmail.comE<gt>

=head1 TODO

Update C<write()> to allow for configurable number of re-attempts

=head1 Bugs

None reported at this time

=head1 See Also

L<Sys::Syslog>



=cut


1;

