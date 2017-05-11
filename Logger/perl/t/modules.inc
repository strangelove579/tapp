# sample modules used in tests.t object & inheritance tests
    

########################


package Foo;
sub new { return bless {},'Foo' }
sub bar { 1 }

########################


package Bar;
our @ISA = qw/Foo/;
sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    return $self, $class;
}
    
sub baz { 1 }

########################

