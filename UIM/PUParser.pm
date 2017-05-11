package TAPP::UIM::PUParser;
{
  $TAPP::UIM::PUParser::VERSION = 0.001; 
}
use Carp qw/croak/;
use Try::Tiny;
use TAPP::Exception;
use TAPP::Datastructure::Utils qw/:all/;

sub new { 
  my $class = shift;
  my $self = {};
  my %args = make_hash(@_) or die "Unexpected arguement list passed to $caller, expected HASH, only 'compatibility' is a valid key";
  $self->{compatibility} = $args{compatibility};
  bless $self, $class;
}
sub errorstr    { 
   my $self = shift; 
   $self->{errorstr} = shift if @_;
   $self->{errorstr}    
}
sub exit_status { 
   my $self = shift; 
   $self->{exit_status} = shift if @_;
   $self->{exit_status};
}

sub pu_parse {
  my $self = shift;
  my ($cmd_output,$attrs,$exit_status) = @_;
  undef $$self{errorstr};
  undef $$self{exit_status};
  my %wanted = map { $_ => 1 } @$attrs;
#
#  Format results into AoH records
#  
  my ($index,$unindent,%data,@result) = (0,1,);
  /^\S.*PDS_PDS/ && ( $unindent = 0 ) foreach @$cmd_output;
  push @$cmd_output, 'END';
  foreach (@$cmd_output) {
    s/^ // if /PDS_PDS/ && $unindent;
    if (/^END$/ || /^\S.*PDS_PDS/) {
      push (@result, {errorstr => '', exit_status => 0, %data}), %data = ()
        if scalar keys %data;
      # solve for strange 'robot_core' anomolie package
      # which appears first in all package lists, but has no name attribute
      if (scalar keys %data == 0 && /^(robot_core)\s.*PDS_PDS/) { 
         $data{name} = 'robot_core';
      }
    } elsif ( /^ {0,2}(\S+)\s+PDS_(?:I|PCH)\s+\S+\s+(.*)\s*$/ ) {
      $data{$1} = $2 if (exists $wanted{$1} && ! defined $data{$1})
    } 
  }
  # Modify quote characters based-on compatibility settting
  if ($self->{compatibility}) { 
      foreach my $row (@result) { 
          foreach my $k (keys %$row) { 
              local $_ = $self->{compatibility};
              /database/ && do { $row->{$k} =~ s/'/''/g };
              /csv/ && do { $row->{$k} =~ s/"/\\"/g };
          }
      }
  }
  if ( $exit_status ) { 
    @result = (
                { 
                   errorstr    => $self->errorstr($cmd_output->[-2]), 
                   exit_status => $self->exit_status($exit_status),
                 }
               );
  }
      
  wantarray()? @result : [@result];
}
1;

