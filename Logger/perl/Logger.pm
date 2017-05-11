package Logger;


    # Logger.pm
    # jachee 3/21/17
    #
    # A simple log file writer, with automatic log rotation and backup log tracking, and other
    # moderately useful configuration options

    # Options are listed below in %INIT_VARS

    # Log rotation
    # -------------------------------------------------------------------------------------------
    # Performs automatic log rotation at N bytes where N is the initialization
    # argument "max_size".

    # Size not tracked with stat() or -s filesize calls to shell
    # It monitors the size by counting incoming bytes, moderately improves performance

    # Log rotation can be forced using the force_rotation() method, if somehow
    # that would ever be needed..

    # Flexible Log statements
    # -------------------------------------------------------------------------------------------
    # Both scalars, arrayrefs, or a mix of both, can be passed to the write() method.
    # Arrayrefs are dereferenced on arrival

    # TODO: file locking
    # TODO: write errors to syslog on failure (unix)
    # TODO: unicode support
    # TODO: convert these comments to POD

    BEGIN {
        our $VERSION = '0.001';
    }

    use Carp qw/carp croak/;
    use File::Copy;
    use POSIX qw/strftime/;
    use File::Basename;

    # Object init parameters for call to new()
    our %INIT_VARS = (
        file              => undef,                 # REQURED. Basename of log file

        max_size          => 5_000_000,             # Maximum log size before automated
                                                    # log rotation is triggered

        max_backup_files  => 5,                     # Number of logs to keep. Logs are
                                                    # removed in 'FILO' order
        timestamps        => 1,                     # Prefix all log entries with timestamps

        ts_format         => "%m/%d/%Y %H:%M:%S",   # Timestamp strftime() format

        chomp_lines       => 1,                     # Cleanup extra newlines before write

        filesize          => 0,                     # Byte size is monitored in code (not through
                                                    # expensive stat() access with -s file)

        echo_stdout       => 0,                     # Echo log messages to the terminal STDOUT
    );

    # Create getter/setter methods for all instance vars
    use base qw(Class::Accessor);
    Logger->mk_accessors(
        keys %INIT_VARS );



    sub new {
        my $class = shift;
        croak "Error: ".__PACKAGE__." - Invalid arguments to new()"
          if scalar @_ % 2 != 0;

        my $self = {};
        %$self = map { $_ => $INIT_VARS{$_} } keys %INIT_VARS;
        %$self = (%$self,@_);

        my $f = $self->{file};

        # 'file' is the only required argument to new()
        unless (defined $f) {
            carp "Error: [".__PACKAGE__."]  - 'file' is a required argument"
        }
        bless $self, $class;

        # Get the current filesize if file exists (needed for log
        # rotation automation)
        $self->{filesize} = -s $f || 0;

        # create file if it doesnt exist
        $self->__make_logfile() unless -f $f;
        return $self;
    }


    # Write to log
    sub write {
        my $self = shift;
        my ($f,$want_ts,$tsfmt,$want_chomp,$max_size) =
          @{$self}{qw/file timestamps ts_format chomp_lines max_size/};

        my $prefix = $want_ts ? strftime("[$tsfmt] ", localtime(time())) : "";

        # write() accepts mixed scalars and arrayrefs. Multiple dimensions
        # of arrayrefs aren't supported

        my @lines =   # chomp and add a single newline char
                      map {
                         if ($want_chomp) {
                             chomp($_);
                             $_ .= "\n"
                         }
                         $_
                      }
                      # Add timestamps if wanted
                      map { $prefix . $_ }
                      # Drop empty lines
                      grep { defined $_ && length($_) && /\S/ }
                      # Unwrap arrayrefs
                      map { ref($_) && /ARRAY/  ? @{$_} :
                                     ! ref($_)  ?  ($_) : ()
                      }
                      @_;

        return if scalar @lines == 0;

        # Sanity check - Ensure the last char of each line is \n
        foreach (@lines) {
            $_ .= "\n" unless /\n$/;
        }

        eval {

            # Print lines to log
            foreach (@lines) {
                # Rotate logs if byte counnt exceeds max_size threshold
                $self->__rotate()
                    if $self->{filesize} > $max_size;

                open (my $fh, ">>", $f) || die "failed open";
                select ($fh);
                # Auto-flush buffer
                $|++;
                print $fh $_;
                close $fh;
                # Increment byte count
                $self->{filesize} += length($_);
                select(STDOUT);
                # Auto-flush STDOUT buffer
                $|++;
                print $_ if $self->{echo_stdout};
            }
        };
        if ($@) {
            if ($@ =~ /failed open/) {
              # TODO: Send the below message to syslog when unix
              carp "Error: [".__PACKAGE__."]  -  " .
                   "Failed to open file for write [$f]: $@";
            } else {
              carp "Error: [".__PACKAGE__."]  - Failed to " .
                   "write to file [$f]: $@";
            }
        }
    }



    #
    #  Private subs
    ##



    # Log rotation need not be called, however the caller has the option
    # to force the rotation event with force_rotation()
    sub force_rotation { shift()->__rotate(); }

    sub __rotate {
        my $self = shift;
        my $max_files = $self->{max_backup_files};
        my $f = $self->{file};
        my $extra_file = "$f.".($max_files+ 1);

        # All possible log filenames
        my @files = map { $_ == 0 ? $f : "$f.$_" } (0 .. $max_files);

        # Rotate in reverse order of file age. Log 4 becomes 5,
        # 3 becomes 4, etc..
        foreach (reverse(0 .. $#files)) {
            my $f1 = $_ == 0 ? $f : $f . "." . $_;
            my $f2 = $f. "." . ($_+1);
            next unless -f $f1;
            move ($f1,$f2) or die "$!";
        }
        unlink $f;

        # The write() method will create the missing base file, this line
        # exists for continuity, and because it isn't hurtin nobody...
        $self->__make_logfile() unless -f $f;
        $self->{filesize} = 0;

        # If log count is exceeded, drop the oldest (FILO)
        unlink $extra_file if -f $extra_file;
    }


    sub __make_logfile {
        my $self = shift;
        my $f = $self->{file};
        eval {
            open (my $fh, "> $f");
        };
        if ($@) {

            # TODO: Send log message to syslog on faiure (unix)
            carp "Error: [".__PACKAGE__."]  - Failed to " .
                 "create log file [$f]: $!";
        }
        1;
    }

    1;


