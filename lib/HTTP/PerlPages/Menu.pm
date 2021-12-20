package HTTP::PerlPages::Menu;

sub new {
  my $class = shift;
  my $classname = ref $class || "$class";
  my $self = {
  };
  bless $self, $classname;
  return $self;
}

sub add {
  my $self = shift;
  my ($desc, $uri) = @_;
  push @{$self->{items}}, { desc => $desc, uri => $uri };
  return 1;
}

sub select {
  my $self = shift;
  my ($desc) = @_;
  foreach my $item (@{$self->{items}}) {
    if ($item->{desc} ne $desc) {
      delete $item->{selected};
    } else {
      $item->{selected} = 1;
    }
  }
}

1;
