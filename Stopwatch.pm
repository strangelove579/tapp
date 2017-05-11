package TAPP::Stopwatch;
{
  $TAPP::Stopwatch::VERSION = '0.001';
}
use strict;
use Carp;

# time divisors
my ($divisor_week,$divisor_day,$divisor_hour,$divisor_min) =
     (7*24*60*60, 24*60*60, 60*60, 60);

sub new {
  my $class = shift;
  return bless { }, $class;
}

sub stop  {
  my $self = shift;
  my $start;
  my ($label,$pause_only) = @_;
  if ($label) {
    $start = $self->{$label}{start};
    delete $self->{$label}{start} unless $pause_only;
    $self->{$label}{elapsed} = time() - $start;
    $self->{chain_label} = $label;
  } else {
    $start = $self->{start};
    delete $$self{start} unless $pause_only;
    $self->{elapsed} = time() - $start;
    $self->{chain_label} = undef;    
  }
  $self;
}

sub elapsed {
  my $self = shift;
  my ($label,$time) = (@_);
  if ($label) {
     $time = time() - $self->{$label}{start};
     $self->stop( $label, 1 );
  } else {
     $time = time() - $self->{start};
     $self->stop( undef, 1 );
  }
  $self;
}
sub format_time {
  my $self = shift;
  $self->print( shift() );
}

sub print_seconds {
  my $self = shift;
  my ($start);
  my $elapsed_in = shift() if @_;
  
  my $label = $self->{chain_label};
  my $elapsed;
  if ( $elapsed_in )  {
    $elapsed = $elapsed_in; 
  } elsif ($label) {
    $elapsed = $self->{$label}{elapsed};
  } else {
    $elapsed = $self->{elapsed};
  }
  $elapsed;
}


sub print {
  my $self = shift;
  my $elapsed = $self->print_seconds(@_);
  my ($weeks,$days,$hours,$minutes,$seconds) =
                           $self->time_parts( $elapsed );
  sprintf( "%.2d:%.2d:%.2d", $hours,$minutes,$seconds);
}

sub time_parts {
  my $self = shift;
  my $elapsed = shift;
  my ($weeks,$days,$hours,$minutes,$seconds,$remaining);
  
  $weeks     = int($elapsed / $divisor_week);
  $remaining =     $elapsed % $divisor_week;
  
  $days      = int($remaining / $divisor_day);
  $remaining =     $remaining % $divisor_day;
  $hours     = int($remaining / $divisor_hour);
  $remaining =     $remaining % $divisor_hour;
  $minutes   = int($remaining / $divisor_min);
  $seconds   =     $remaining % $divisor_min;
  
  return ( $weeks,$days,$hours,$minutes,$seconds );
}

sub start {
  my $self = shift;
  my ($label,$start) = @_;
  if ($label) {
    delete $$self{$label}{start};;
    $self->{$label}{start} = time();
  } else {
    delete $$self{start};;
    $self->{start} = time();
  }
  1;
}


sub pretty_print {
  my $self = shift;
  my $chainlabel = $self->{chain_label};
  
  my $elapsed    = defined $chainlabel
                 ? $self->{$chainlabel}{elapsed}
                 : $self->{elapsed};
                 
  my ($weeks,$days,$hours,$minutes,$seconds) =
    $self->time_parts ( $elapsed );
  my $formatted = "${seconds}s";
  $formatted = "${minutes}m ". $formatted if $minutes > 0;
  $formatted = "${hours}m ". $formatted if $hours > 0;
  $formatted = "${days}m ". $formatted if $days > 0;
  $formatted = "${weeks}m ". $formatted if $weeks > 0;
  $formatted;
}
1;

