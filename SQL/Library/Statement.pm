package TAPP::SQL::Library::Statement;
{
  $TAPP::SQL::Library::Statement::VERSION = '0.003';
}
use strict;
########################################################################
     
=head1 NAME 

TAPP::SQL::Library::Statement - Statement object for an individual SQL hash in a LibSQL object                          

=head1 SYNOPSIS


  use TAPP::SQL::Library::Statement;
  
  # -- code! --
  
  
  
=head1 DESCRIPTION

C<TAPP::SQL::Library::Statement> does stuff, <fill me in!>



=cut
######################## P O D - E N D #################################
use TAPP::Datastructure::Utils qw/:var_utils :dumper_utils/;
use TAPP::Exception;
use Carp qw/carp cluck croak/;
use POSIX qw/strftime/;
use Try::Tiny;
use Scalar::Util qw/blessed/;

sub new {
  my $class = shift;
  my $self = {};
  my %args = (@_);
  %$self = (%$self,%args);
  bless $self, $class;
  my $statement = $self->sql;
  $self->{sql_template} = $statement;
  ($self->{sql_oneliner} = $statement) =~ s/\n/!!nl!!/msg;
  $self;
}
sub sql  {
    my $self = shift;
    if (@_) {
      $self->{sql} = shift;
      if (defined $self->{sql}) {
          $self->{sql} =~ s/\t/        /g;
      }
    }
    $self->{sql};
}
sub id         : lvalue { shift()->{id} }
sub name       : lvalue { shift()->{name} }
sub description : lvalue { shift()->{description} }
sub key { my $self = shift; $self->{id}.'-'.$self->{name} }
sub dbh { return shift->{dbh} }
sub remap {
  my ($data,$remaps) = @_;
  my @epoch_fields = ref ($remaps->{epoch_fields}) eq 'ARRAY' ? @{$remaps->{epoch_fields} } : ();
  my %epoch_check = map { $_ => 1 } @epoch_fields;
  my $date_format = $data->{epoch_to} || "%m/%d/%Y %H:%M:%S";
  my @operations = (qw/undef_to epoch_to quote_to/);
  for my $k(keys %$data) {
      for (@operations ) {
        /^undef_to$/     && do {
          $data->{$k} = defined $data->{$k} ? $data->{$k} : 'null'
        };
        /^epoch_to$/ && $epoch_check{$k}   && do {
          $data->{$k}= strftime $date_format, localtime($data->{$k})
        };
        /^quote_to$/     && do {
          my $q = defined $remaps->{$_} ?  $remaps->{$_} : "'";
          $data->{$k} =~ s/'/$q/g;
        };
      }
  }
  $data
}


sub bind_variables {
  my $self = shift;
  local $_ = $self->{sql_oneliner};
  my @keys = ();
  # pull words starting with '$', unless escaped '\$'
  # allow words with mix of alpha-numeric, underscore
  # hash-sign (if escaped) and/or dollarsign if escaped
  # the below are valid bind variable names:
  
  #  $username
  #  $pas\$word
  #  $count_\#
  #  $DB_\$REC_\#COUNT
  
  while (m{[^\\]\$((?:\w|\\\$|\\\#)+)}msg) {
    (my $k = $1) =~ /\\/g;
    push @keys, $1;
  }
  @keys = () unless scalar @keys;
  wantarray() ? @keys : [@keys];
}

sub prepare {
  my $self = shift;

  my %args;

  if ( ref($_[0]) eq 'HASH' ) { 
     %args = %{$_[0]};
  } else { 
     %args = (@_);
  }
  
  die "invalid arguments to prepare(), requires HASH"  unless scalar keys %args;
  my $data = $args{bind};
  my $remaps = $args{remap};

  my $dbh = $self->{dbh};
  my $sql_statement = $self->{sql_template};
  my $name = $self->name;
  my $sql_oneliner = $self->{sql_oneliner};

  local $_ = $sql_oneliner;
  my $keys = $self->bind_variables();
  $keys = [] unless defined $keys && ref($keys) eq 'ARRAY';
  for my $k (@$keys) {


    $$data{$k} = defined $$data{$k} && length( $$data{$k} ) > 0 
                   ? $$data{$k} 
                   : 'null';
      my $val = $$data{$k};
      $sql_oneliner =~ s{\$$k}{$val}msi;    
  }
  $sql_oneliner =~ s/'null'/null/g;
  $sql_oneliner =~ s/##FILTERS##/AND (1=1)/;
  ($sql_statement = $sql_oneliner ) =~ s/!!nl!!/\n/g;
  $self->sql( $sql_statement );
  $self;
}
sub run {
  my $self = shift;
  my $caller = (caller(0))[3];
  my $attempts = 100;
  my $result;
  EXEC:
  {
    try { 
      $result = $self->{dbh}->exec( $self->sql );
      $self->{sql} = $self->{sql_template};
    } catch { 
      die $_ unless blessed $_ && $_->can('rethrow');
      if ($_->isa("TAPP::DB::Oracle::ConnectionException")) {
         sleep 6;
         $self->{dbh}->reconnect();
         redo EXEC unless $attempts--;
         die "Failed to re-acquire dropped DB connection after 5 minutes, in call to $caller";
      } 
      $_->rethrow;
   };
 }
 $result;
}
         
sub rows_affected {
  my $self = shift;
  $self->{dbh}->rows()
}

1;

