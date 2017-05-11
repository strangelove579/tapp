#!/usr/bin/perl

  use v5.16;
  no warnings;
  no strict;
    
  require('modules.inc');
  
  package main;
  use Test::More tests => our $test_count = 13;
  use Try::Tiny;
  use subs qw/hr/;

  # -------------------------------------------------------
  #   MAIN
  # -------------------------------------------------------
  # Test::More functions and behaviors
  # -------------------------------------------------------



  #
  # is($val, $val2, $name)
  #    Equality test of values (scalars)
  #
  my $x = 'Foo';
  is ($x, 'Foo', testName('Test1 - is($x is 1)'));
  hr "====================================================================";




  #
  # isnt($val, $val2, $name)
  #    Inequality test of values (scalars)
  #
  my $y = 'Baz';
  isnt ($x, $y, testName('Test2 - isnt($x is 1)'));
  hr "====================================================================";



  #
  # require_ok( $module_name )
  #    Module import test - Test successful
  #    import of <module>
  #
  my $module = "JSON::XS";
  require_ok( $module );
  hr "====================================================================";




  #
  # diag( 'some description of an error' )
  #    Print an error formatted to Test::More
  #    output
  #
  try { 
      my $bad_module = "Foo::Bar::Baz";
      require_ok( $bad_module );
  } catch {
      diag($_);
  };
  hr "====================================================================";




  #
  # cmp_ok( $val1, $op, $val2, $testname )
  #    Numeric comparisons
  #    
  my ($got,$expected) = (12345,12345);
  cmp_ok(
      $got, '==', $expected,
      testName('Test4 - cmp_ok($value1 == $value2)')
  );
  hr "====================================================================";




  #
  # like( $string, qr/$expr/, $testname )
  #   Match a string against a regex
  like(
      '123abc', qr/^123/,
      testName('Regex - like(123abc =~ /^123/)')
  );
  hr "====================================================================";




  #
  # unlike( $string, qr/$expr/, $testname )
  #   Match a string against a regex for inequality
  # 
  unlike(
     '123abc', qr/^abc/,
     testName('Regex - unlike(123abc !~ /^abc/)')
  );
  hr "====================================================================";



  #
  # is_deeply( $complex_datastructure, $complex_datastructure2, $testname )
  #   Complex Datastructure Equality
  #     
  is_deeply(
      { tag => { newname => 'Internal Applications' } },
      { tag => { newname => 'Internal Applications' } },
      testName('Datastructure - is_deeply(hashref1 = hashref2)')
  );
  hr "====================================================================";



  #
  # Object has method(s)
  #
  # can_ok( $object, @methods )
  #   Does an object provide these methods
  #         
  can_ok('Foo', ('new','bar'));
  hr "====================================================================";



  #
  # isa_ok( $obj, '<module>', '<object name>'
  #   Object is instanceOf module
  #         
  #
  my $bar = new Bar();
  isa_ok($bar,'Bar');
  hr "====================================================================";



  #
  # isa_ok( $obj, '<parent_module>', '<object name>' )
  #   Object inheritance
  #         
  # 
  isa_ok($bar,'Foo','bar');
  hr "====================================================================";



  #
  # pass( $why )
  #   Explicitly pass a test for more complex tests
  #         
  # 
  pass('Explicitly passing this test');
  hr "====================================================================";




  #
  # fail( $why )
  #   Explicitly fail a test for more complex tests
  #         
  #
  say "Fail this test:";
  fail('Explicitly failing a test');
  hr "====================================================================";



  #
  # BAIL_OUT( $why )
  #   Force-end a test
  #         
  # BAIL_OUT('Max errors reached! Doh!");
  
  
  
  
  #
  # done_testing( $test_count )
  #   Test::More scripts must explicitly finish a test with
  #   done_testing(), or dont - but the final output wont provide
  #   a summary
  #         
  done_testing($test_count);

  # -------------------------------------------------------
  #   END MAIN
  # -------------------------------------------------------


  # 
  # Subs
  #   Some unrelated but useful utility routines
  #
  # Stopwatch routines
  # Time your tests and overall script for performance
  # testing
  # ------------------------------------------------------
  # swStart() - starts a timer
  # swStop()  - returns elapsed time
  # 


  Stopwatch: {
      use Time::HiRes qw/gettimeofday tv_interval/;
      my ($tStart,$tEnd,$tElapsed);
      #
      # swStart();
      # Start the stopwatch, no return val;
      sub swStart { __swInit; $tStart = [gettimeofday] }

      #
      # $elapsed = swStop();
      # Stop the stopwatch, returns elapsed time in milliseconds
      sub swStop {
          $tElapsed = tv_interval(
            $tStart,
            $tEnd = [gettimeofday]
          )
      }

      # do not call directly-
      sub __swInit  {
        ($tStart,$tEnd,$tElapsed) = ()
      }

  }


  #
  # testName( SCALAR );
  #   This routine originally did some more interesting
  #   formatting, but ultimately worked better as a single
  #   scalar
  # -------------------------------------------------------
  sub testName { "@_" }
  sub hr { say "@_" }
  __END__
  
