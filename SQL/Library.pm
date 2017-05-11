package TAPP::SQL::Library;
{
  $TAPP::SQL::Library::VERSION = '0.003';
}
use strict;

use Carp qw/carp cluck croak/;
use Data::Structure::Util qw/unbless/;
use JSON::XS;
use TAPP::SQL::Library::Statement;
use TAPP::Datastructure::Utils qw/:var_utils :dumper_utils/;
use TAPP::Exception;
use Scalar::Util qw/blessed/;
use TAPP::DB::Oracle;

my $json = JSON::XS->new->allow_nonref;

my @ATTRS = qw/id sql description name/;
my %filekeys = (
    id            => qr/^\s*\[([^\-]+?)\-(.+?)\s*\]\s*$/i,
    description   => qr/^\s*description:\s*(.*?)\s*$/i,
    sql_statement => qr/^\s*(sql)/i,
);

my @INIT_ARGS = (qw/
  library_files
  dbh
/);

our $error = '';

sub new {
  my $class = shift;
  $class = ref($class) || $class;
  my $caller = (caller(0))[3];
  my $self = {};
  my %args = (@_);
#use Data::Dumper;
#rint Dumper(\%args);
#exit;
  bless $self, $class;
  my $keys = scalar keys %args;
  if ($keys && $keys % 2 == 0) {
    %$self = map { $_ => $args{$_} } @INIT_ARGS;
  }
  
  unless ( is_arrayref( $self->{library_files} ) ) {
    throw TAPP::IllegalArgumentException(
      "Library_files argument is required, and must be an arrayref in call to $caller()"
    );
  }
  my %ora_options = is_non_empty_hashref($args{ora_options})
                     ? %{$args{ora_options}}
                     : ();
  #%ora_options = (%ora_options, user_config => $args{user_config}) if $args{user_config};
  $self->{dbh}  = TAPP::DB::Oracle->connect( %ora_options );  
  $self->load_libraries();
  $self;
}

sub dbh {
  my $self = shift;
  $self->{dbh} = shift if @_;
  $self->{dbh};
}
sub get_template { 
  my $self = shift;
  return $self->sql_statement( @_ );
}

sub sql_statement {
  my $self = shift;
  my $caller = (caller(0))[3];
  my $key = shift;
  my $id = $self->{keymap}{$key};
  unless (defined $id) {
    throw TAPP::SQL::Library::NoIDDefinedException(
        "ID $id is not defined in the library in call to $caller()"
    );
  }  
  $self->{active_sql_statement} = $id;
  $self->{sql_templates}{$id};
}

sub list_sql_statements {
  my $self = shift;
  my @list = $self->__list('sql_statement');
  wantarray()? @list : \@list
}
sub list_names {
  my $self = shift;
  my @list = $self->__list('name');
  wantarray()? @list : \@list
}
sub list_ids {
  my $self = shift;
  my @list = $self->__list('id');
  wantarray()? @list : \@list
}
sub list_keys {
  my $self = shift;
  my @list = $self->__list('key');
  wantarray()? @list : \@list
}
sub list_bind_variables {
  my $self = shift;
  shift;
  my $by_what = shift;
  my %list = map  { $_->[0] => $_->[1] }
             sort { $a->[0] cmp $b->[0] }
             map  { 
                    my $key = $by_what eq 'name' ? $self->{sql_templates}{$_}->name :
                              $by_what eq 'id'   ? $self->{sql_templates}{$_}->id :
                              $self->{sql_templates}{$_}->id;
                    [ $key,  $self->{sql_templates}{$_}->bind_variables ]
                  } keys %{$self->{sql_templates}};
  
  %list = () unless scalar keys %list;
  %list = map { $_ => ref($list{$_}) eq 'ARRAY' ? $list{$_} : [] } keys %list;
  wantarray()? %list : \%list
}
sub __list {
  my $self = shift;
  local $_ = shift;
  my @list;
  if (/key/) {
    @list = sort map { $self->{sql_templates}{$_}->key } keys %{$self->{sql_templates}};  
  } elsif (/id/) {
    @list = sort map {  $self->{sql_templates}{$_}->id } keys %{$self->{sql_templates}};
  } elsif (/name/) {
    @list = map  { $_->[1] }
             sort { $a->[0] cmp $b->[0] }
             map  { [ $self->{sql_templates}{$_}->id, $self->{sql_templates}{$_}->name ] }
             keys %{$self->{sql_templates}};
  } elsif (/sql_statement/) {
    @list = map  { $_->[1] }
             sort { $a->[0] cmp $b->[0] }
             map  { [ $self->{sql_templates}{$_}->id, $self->{sql_templates}{$_}->sql ] }
             keys %{$self->{sql_templates}};
  } 
  @list = () unless scalar @list;
  wantarray()? @list : \@list
}

sub __push_statement {
  my $self = shift;

  my %sql_template = %{shift()};


  my $sql_instance = TAPP::SQL::Library::Statement->new( %sql_template, dbh => $self->{dbh} );
  $self->{sql_templates}{$sql_template{id}} = $sql_instance;
  my $id =  $sql_instance->id;
  $self->{keymap}{$sql_instance->key} =
    $self->{namemap}{$sql_template{name}} = $id;
  1;
}

sub load_libraries {
    my $self = shift;
    my @libraries = @{$self->{library_files}};

    my %sql_template;

    foreach my $file ( @libraries ) {

        open(my $fh, "<", $file)
          or throw TAPP::FileIOException( "Failed to open library file [$file]: $!" );

        my $lslurp;

        while (<$fh>) {
            next if /^\s*$/ || /^\s*#/ || /^\s*--/;
            chomp;

            # SQL starts on this line
            /$filekeys{sql_statement}/ && do {
              $lslurp = 1, $sql_template{sql} = '', next
            };

            # ID field on this line
            /$filekeys{id}/  && do {
                my ($id,$name) = ($1,$2);
                $self->__push_statement( \%sql_template ) if scalar keys %sql_template;
                undef %sql_template;
                %sql_template = map { $_ => '' } @ATTRS;
                @sql_template{qw/id name/} = ($id,$name);
                $lslurp = 0;
                next;
            };
            /$filekeys{description}/i && ! $lslurp && do { $sql_template{description} = $1; next };

            $sql_template{sql} .= $_ ."\n", next if $lslurp;
        }
        close $fh;
    }
    $self->__push_statement( \%sql_template ) if scalar keys %sql_template;
    1;
}

sub to_string {
    my $self = shift;
    dd( $self );
    #serialize( $self );
    #my $out = '';
    #foreach my $s ( sort { $a->id <=> $b->id } map { $self->{sql_templates}{$_} } keys %{$self->{sql_templates}} )
    #{
    #    $out .= "===============================================================================\n";
    #    $out .= sprintf ( "ID: %s,  Name: %s,  Key: %s\n", $s->id, $s->name, $s->key );
    #    $out .= sprintf ( "Trace Desc: %s\n", $s->description );
    #    $out .= "SQL: \n";
    #    $out .= $s->sql;
    #    $out .= "\n";
    #    $out .= "===============================================================================\n\n";
    #}
    #$out;

}


sub serialize {
  my $obj = shift;
  my $class = ref $obj;
  unbless $obj;
  my $rslt = $json->pretty->encode($obj);
  bless $obj, $class;
  return $rslt;
}

sub deserialize {
  my ($jsonobj, $class) = @_;
  my $obj = $json->decode($jsonobj);
  return bless($obj, $class);
}
1;

