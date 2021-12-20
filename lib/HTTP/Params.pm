package HTTP::Params;

use HTTP::CGIRequest;

sub push_key_value {
  my ($hash, $key, $val) = @_;
  $key =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $val =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  my $extval = $hash->{$key};
  if (!defined($extval)) {
    $hash->{$key} = $val;
  } elsif (ref($extval) eq 'ARRAY') {
    push @{$hash->{$key}}, $val;
  } else {
    $hash->{$key} = [ $extval, $val ];
  }
}

sub parse_params {
  my $query = shift;
  my $hash = shift || {};
  my @elts = split(/[;&]/, $query);
  foreach my $elt (@elts) {
    if ($elt =~ /^([^=]*)=(.*)$/) {
      push_key_value($hash, $1, $2);
    } else {
      push_key_value($hash, $elt, undef);
    }
  }
  return $hash;
}

sub process_multipart {
  my $buffer = shift;
  my $boundary = shift;
  my $hash = shift || {};
  $buffer =~ s/--$boundary--\r?\n$//g;
  my @elts = split "--".$boundary."\r\n", $buffer;
  for (my $i=0; $i<scalar @elts; $i++) {
    my $key;
    my $val;
    my $j=0;
    my $elt = $elts[$i];
    for (;;) {
      my $line = $elt;
      my $index = index($elt, "\n");
      if ($index > -1) {
        $line = substr($elt, 0, $index+1);
        $elt = substr($elt, $index+1);
      }
      $line =~ s/[ \n\r\t]+$//;
      last if (!length($line));
      if ($line =~ /^[cC]ontent-[dD]isposition: form-data/) {
        if ($line =~ /name=\"?([^\";,]+)\"?/ ) {
          $key = $1;
        }
        if ($line =~ /filename=\"?([^\";,]+)\"?/ ) {
          $val = { name => $1 };
        }
      } elsif ($line =~ /^[cC]ontent-[tT]ype: ([^; \t\r\n]+)/) {
        if ($val) {
          $val->{type} = $1;
        }
      }
    }
    $elt =~ s/\r?\n?$//;
    if ($val) {
      $val->{body} = $elt;
    } else {
      $val = $elt;
    }
    if ($key && length($key)) {
      push_key_val($hash, $key, $val);
    }
  }
  return $hash;
}

sub cgi_post_data {
  my $buf = '';
  my $l = $ENV{CONTENT_LENGTH};
  while ($l > 0) {
    my $tmp;
    my $r = 1024;
    if ($r > $l) {
      $r = $l;
    }
    last if (($r = sysread(STDIN, $tmp, $r)) <= 0);
    $l -= $r;
    $buf .= $tmp;
  }
  return $buf;
}

sub apache2_post_data {
  eval("use APR::Brigade ();1;");
  eval("use APR::Bucket ();1;");
  eval("use Apache2::Filter ();1;");
  eval("use Apache2::Const -compile => qw(MODE_READBYTES);1;");
  eval("use APR::Const    -compile => qw(SUCCESS BLOCK_READ);1;");
  eval("use constant IOBUFSIZE => 8192;1;");
  my $r = shift;
  my $bb = APR::Brigade->new($r->pool, $r->connection->bucket_alloc);
  my $data = '';
  my $seen_eos = 0;
  do {
    $r->input_filters->get_brigade(
      $bb,
      Apache2::Const::MODE_READBYTES,
      APR::Const::BLOCK_READ,
      IOBUFSIZE
    );
    for (my $b = $bb->first; $b; $b = $bb->next($b)) {
      if ($b->is_eos) {
        $seen_eos++;
        last;
      }
      if ($b->read(my $buf)) {
        $data .= $buf;
      }
      $b->remove; # optimization to reuse memory
    }
  } while (!$seen_eos);
  $bb->destroy;
  return $data;
}

sub get {
  my $request = shift || HTTP::CGIRequest::get();
  my $hash = shift || {};
  if ($request->method() =~ /get/i) {
    my $args = $request->args();
    parse_params($args, $hash);
  } elsif ($request->method() =~ /post/i) {
    my $buffer = '';
    if (UNIVERSAL::isa($request, 'HTTP::CGIRequest')) {
      eval("use CGI;1;");
      my %vars = CGI::Vars();
      foreach my $key (keys(%vars)) {
        my @values = split(/\0/, $vars{$key});
        if (scalar(@values) > 1) {
          $vars{$key} = \@values;
        } else {
          $vars{$key} = CGI::param($key);
        }
      }
      return \%vars;
    } elsif (UNIVERSAL::isa($request, 'Apache2::RequestRec')) {
      $buffer = apache2_post_data();
    }
    if ($request->content_type() =~ m|^multipart/form-data|) {
      if ($request->content_type() =~ /boundary=\"?([^\";,]+)\"?/) {
        my $boundary = $1;
        process_multipart($buffer, $boundary, $hash);
      }
    } else {
      parse_params($buffer, $hash);
    }
  }
  return $hash;
}

1;
