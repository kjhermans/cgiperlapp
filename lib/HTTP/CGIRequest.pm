package HTTP::CGIRequest;

my $request = HTTP::CGIRequest->new();

sub get {
  return $request;
}

##---- Class to model a CGI environment to look like an apache request ------##

sub new {
  my $class = shift;
  my $classname = ref($class) || $class;
  my $self = {
    headersout => HTTP::CGIRequestHeaders->new(),
    debug => undef,
  };
  bless $self, $classname;
  return $self;
}

sub uri {
  my $self = shift;
  if (!$self->{uri}) {
    my $uri = $ENV{REQUEST_URI};
    my $query = $ENV{QUERY_STRING};
    $uri =~ s/$query$//;
    $uri =~ s/\?$//;
    $self->{uri} = $uri;
  }
  return $self->{uri};
}

sub headers_in {
  return bless {
    'Cookie' => $ENV{HTTP_COOKIE},
    'Content-Length' => int($ENV{CONTENT_LENGTH}),
    'Content-Type' => $ENV{CONTENT_TYPE}
  }, 'HTTP::CGIRequestHeaders';
}

sub cookie {
  my $self = shift;
  if (scalar(@_)) {
    $self->headers_out('Set-Cookie', $_[0]);
  } else {
    return $self->headers_in()->{Cookie};
  }
}

sub headers_out {
  my $self = shift;
  my ($name, $value) = @_;
  if ($name && $value) {
    $self->{headersout}{$name} = $value;
  }
  return $self->{headersout};
}

sub print {
  my $self = shift;
  if (!$self->{headersgone}) {
    foreach my $key (keys(%{$self->{headersout}})) {
      print STDOUT "$key: $self->{headersout}{$key}\r\n";
      if ($self->{debug}) {
        print STDERR "$key: $self->{headersout}{$key}\r\n";
      }
    }
    print STDOUT "\r\n";
    $self->{headersgone} = 1;
  }
  print STDOUT @_;
}

sub args {
  return $ENV{QUERY_STRING};
}

sub method {
  return $ENV{REQUEST_METHOD};
}

sub content_type {
  my ($self, $arg) = @_;
  if ($arg) {
    $self->{headersout}{'Content-Type'} = $arg;
  }
  return $ENV{CONTENT_TYPE};
}

sub content_length {
  my ($self, $arg) = @_;
  if ($arg) {
    $self->{headersout}{'Content-Length'} = int($arg);
  }
  return $ENV{CONTENT_LENGTH};
}

##---- Mimic apache headers class -------------------------------------------##

package HTTP::CGIRequestHeaders;

sub new {
  my $class = shift;
  my $classname = ref($class) || $class;
  my $self = {};
  bless $self, $classname;
  return $self;
}

sub add {
  my ($self, $name, $value) = @_;
  $self->{$name} = $value;
}

sub get {
  my ($self, $name) = @_;
  return $self->{$name};
}

1;
