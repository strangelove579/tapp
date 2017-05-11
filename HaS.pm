package TAPP::HaS;
{
  $TAPP::HaS::VERSION = '1.001';
} # Originally written by Nathan Hilterbrand, 2012
use strict;


  sub unascii {   pack 'h*', $_[0]; }
  sub   ascii { unpack 'h*', $_[0]; }
  sub   rot47 { my $s = shift; $s =~ tr/!-~/P-~!-O/; return $s;}
  sub    xall { return join '', map{$_ ^ "\xFF"} split '', $_[0] }

  sub xl2r {
    my $s = shift;
    my @targ = split '', $s;
    unshift @targ, "\xAA";
    foreach my $i (1 .. $#targ) {
      $targ[$i] = $targ[$i] ^ $targ[$i-1];
    }
    shift @targ;
    $s = join '', @targ;
    return $s;
  }

  sub xr2l {
    my $s = shift;
    my @targ = split '', $s;
    unshift @targ, "\xAA";
    foreach my $i (0 .. $#targ-1) {
      my $idx = $#targ - $i;
      $targ[$idx] = $targ[$idx] ^ $targ[$idx-1];
    }
    shift @targ;
    $s = join '', @targ;
    return $s;
  }

  sub addrand {
    my $s = shift;
    my $rbyte = chr(int(rand(1024)) % 256);
    return $rbyte . $s;
  }

  sub remrand {
    my $s = shift;
    return substr($s, 1);

  }

  sub scramble {
    return undef unless @_;

    my $input = shift;
    my @bytes = split '', $input;

    my @out = ();
    while(@bytes) {
      push @out, pop @bytes;
      push @out, shift @bytes if @bytes;
    }

    my $out = join '', @out;
    return $out;
  }

  sub unscramble {

    return undef unless @_;

    my $input = shift;
    my @bytes = split '', $input;

    my @outbeg = ();
    my @outend = ();
    while(@bytes) {
      unshift @outend, shift @bytes;
      push @outbeg, shift @bytes if @bytes;
    }

    my $out = join '', (@outbeg, @outend);
    return $out;
  }

  sub nrzi {
    return undef unless @_;

    my $input = shift;
    my $binary = unpack("B*", $input);

    my @bits = split '', $binary;
    my @outbits = ();

    my $lastbit = "0";

    foreach my $bit (@bits) {
      my $outbit = $bit+0 ? $lastbit : 2-$lastbit-1;
      push @outbits, $outbit;
      $lastbit = $bit;
    }

    $binary = join '', @outbits;
    my $output = pack("B*", $binary);
    return $output;
  }

  sub unnrzi {
    return undef unless @_;

    my $input = shift;

    my $binary = unpack("B*", $input);

    my @bits = split '', $binary;
    my @outbits = ();

    my $lastbit = "0";
    foreach my $bit (@bits) {
      my $newbit = $bit+0 == $lastbit+0 ? "1" : "0";
      push @outbits, $newbit;
      $lastbit = $newbit;
    }

    $binary = join '', @outbits;
    my $output = pack("B*", $binary);
    return $output;

  }

  sub new {
    my $src = shift;
    my $class = (ref($src)) ? ref($src) : $src;
    my $self = {};
    bless $self, $class;
    $self->{HASHEDSTR} = undef;
    if (@_) {
      my %parms;
      if (ref($_[0]) =~ /HASH/) {
        %parms = ${$_[0]};
      } elsif (scalar @_ % 2) {
        %parms = (@_);
      } else {
        warn "new() called with an odd number of non-ref arguments";
      }
      if (%parms) {
        foreach (keys %parms) {
          my $val = $parms{$_};
          delete $parms{$_};
          $_ = uc($_);
          $parms{$_} = $val;
        }
        $self->hashedstr($parms{HASHEDSTR}) if exists $parms{HASHEDSTR};
        $self->plainstr($parms{PLAINSTR}) if exists $parms{PLAINSTR};
      }
    }
    return $self;
  }

  sub hashedstr  {
    my $self = shift;
    $self->{HASHEDSTR} = shift if @_;
    $self->{HASHEDSTR};
  }

  sub plainstr {
    my $self = shift;
    my $plainstr = "";
    if (@_) {
      my $str = shift;
      $plainstr = $str;
      if ($str) {
        $str = reverse($str);
        $str = rot47($str);
        $str = xall($str);
        $str = addrand($str);
        $str = xl2r($str);
        $str = addrand($str);
        $str = nrzi($str);
        $str = ascii($str);
        $str = uc($str);
        $str = scramble($str);

        $self->{HASHEDSTR} = $str;
      }
    }
    my $str = $self->{HASHEDSTR};
    if ($str) {
      $str = unscramble($str);
      $str = unascii($str);
      $str = unnrzi($str);
      $str = remrand($str);
      $str = xr2l($str);
      $str = remrand($str);
      $str = xall($str);
      $str = rot47($str);
      $str = reverse($str);
      $plainstr = $str;
    }
    $plainstr;
  }

1;




