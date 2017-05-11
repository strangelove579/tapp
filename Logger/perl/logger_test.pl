#!/usr/bin/perl
    # Test script for Logger.pm

    # Each test is wrapped in code blocks. Code block execution is enabled/disabled
    # through use of a DO_TEST hash of booleans per test.

    # Thats it, this simple method of testing isn't automating validation...
    # for this particular use case it would be unnecessarily difficult as it would
    # have to read and parse log content, which is a moving  target across multipole runs
    # + persistent files. Therefore, testing consist of - Run it, Check for errors on STDERR/STDOUT,
    # examine the statements in the log..
    use v5.20;

    use strict;
    use warnings;
    $|++;

    use Data::Dumper qw/Dumper/;
    use autodie;
    use File::Basename;


    use Logger;

    # Instantiate Logger
    my $logfile = 'test.log';
    my $log = Logger->new( file => $logfile, echo_stdout => 0 );


    # %DO_TEST is used to enable/disable individual tests
    # Flip the bits to execute various tests
    my %DO_TEST = (
            SIMPLE            => 1,  # creates the file and writes a single line

            ARRAYREFS         => 1,  # passes in arrayrefs, which get dereferenced and printed to
                                     # log 1 scalar per line

            MIXED_DATA        => 1,  # pass scalars mixed with arrayrefs mixed with scalars ...etc

            ACCESSORS         => 1,  # use accessors to retrieve instance variable values,
                                     # auto created by Class::Accessor

            TIMESTAMPS        => 1,  # munge timestamp formats, see that it implements the changes

            FORCE_ROTATION    => 1,  # tell Logger to rotate logs based on log rotation settings

            ROTATION          => 1,  # Let Logger automatically rotate logs based on settings

            ROTATE_PAST_END   => 1,  # Feed the Logger enough data to exceed the max bytes across all logs
                                     # and backup logs to see that the file list doesn't get wacky

            JUNK_PRESERVATION => 1,  # disable line chomping mainly, to see that junk format data is preserved.
                                     # Not a great feature, but maybe theres a use case?
    );

    # chunk_o_bytes:
    # A large string that will be used to grow the
    # log files at a faster rate, for the log rotation tests
    #
    # When the chunk is written to the log, the first line should
    # be prefixed with a timestamp and the remaining lines will not
    # have a timestamp
    #
    # The bytes are sentences in the __DATA__ section at the end of this script
    my $chunk_o_bytes = do {local $/=undef; (<DATA>)};


    SIMPLE: {

      last unless $DO_TEST{SIMPLE};
      # simple test
      # creates a log if one doesn't exist
      # write a line of text...
      say "Starting test 'SIMPLE'";
      $log->write("test");

    }

    ARRAYREFS: {

      last unless $DO_TEST{ARRAYREFS};
      # Try writing arrayrefs
      say "Starting test 'ARRAYREFS'";

      $log->write( ['line of text in arrayref',
                    'another line of text in arrayref'] );


    }

    MIXED_DATA: {

      last unless $DO_TEST{MIXED_DATA};
      # Now try writing a mix of scalars and arrayrefs
      say "Starting test 'MIXED_DATA'";

      $log->write( 'scalar line of text',
                   ['arrayref text', 'arrayref text2 '] ,
                   'more scalar', ['more arrayref'] );


    }

    ACCESSORS: {

      last unless $DO_TEST{ACCESSORS};
    # Try getting instance var values using
    # accessors created with Class::Accessor
      say "Starting test 'ACCESSORS'";

      say $log->file();
      say $log->max_size();
      say $log->filesize();

    }

    TIMESTAMPS: {

      last unless $DO_TEST{TIMESTAMPS};
    # Adjust timestamp format

      say "Starting test 'TIMESTAMPS'";

      $log->ts_format("%d-%m-%Y %H:%M:%S");
      $log->write("foo");
      $log->write("bar");


    }


    FORCE_ROTATION: {

      last unless $DO_TEST{FORCE_ROTATION};
      # test log rotation
      # by forcing it
      #
      say "Starting test 'FORCE_ROTATION'";

      $log->force_rotation();
      list_logFiles();

    }
    ROTATION: {

      last unless $DO_TEST{ROTATION};
      # test automatic log rotation
      # 21 MB should trigger rollover 4 times
      #
      say "Starting test 'ROTATION'";

      log_dump( size => 21_000_000 );
      list_logFiles();
    }



    ROTATE_PAST_END: {

      last unless $DO_TEST{ROTATE_PAST_END};
      # test log rotation
      # 35 MB should trigger rollover 7 times,
      # therefore 2 files should rotate out
      #
      say "Starting test 'ROTATE_PAST_END'";

      log_dump( size => 35_000_000 );
      list_logFiles();
    }

    JUNK_PRESERVATION: {

      last unless $DO_TEST{JUNK_PRESERVATION};
      # Turn off chomp() and send junky lines
      # to the log with poorly hanled newline chars
      #
      say "Starting test 'JUNK_PRESERVATION'";

      $log->chomp_lines(0);

      # send junk to the log
      $log->write("test test test

      ");

      $log->write("line 1","","","\n","line 2\n",
                   ['foo','bar\n','baz','','qux']);

    }
    say "Done.";


    sub list_logFiles {
      my $dir = dirname($logfile);
      opendir (my $dh, $dir);
      say "Log List:";
      foreach (readdir($dh)) {
        chomp;
        say $_ if /^$logfile/;
      }
      1;
    }
    # Write blocks of data to log
    sub log_dump {
      my %args = (@_);
      my $size = $args{size};
      my $bytes = 0;
      do {
          $log->write($chunk_o_bytes);
          $bytes += length($chunk_o_bytes)
      } until ($bytes >= $size);
      say "Wrote $bytes bytes to log";
      1;
    }

__DATA__
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
The quick brown fox jumps over the lazy dog
