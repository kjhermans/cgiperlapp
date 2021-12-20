package HTTP::PerlPages;

use HTTP::State;
use HTTP::Params;

use Digest::MD5;
use Cwd;

my %pages_loaded;
my $mode = $ENV{GATEWAY_INTERFACE} ? 'CGI' : 'OBJECT';
our $debug = 0;
my $usestate = 0;
my $headersgone = 0; ## Only used for CGI, not to be set by you.

sub mode {
  my $m = shift;
  if (!$m) {
    return $mode;
  }
  if ($m =~ /cgi/i) {
    $mode = 'CGI';
  } else {
    $mode = 'OBJECT';
  }
}

sub parse {
  my ($path, $digest) = @_;
  my @spath = stat($path);
  my $tempdir = $ENV{TEMP} || '/tmp';
  my $sep = '/';
  if ($tempdir =~ /^[a-zA-Z]:\\/) {  ## We're on windows
    $sep = '\\';
  }
  $tempdir =~ s/$sep$//;
  my $cachepath = "$tempdir$sep" . "perlpages_$digest";
  if ($debug) { print STDERR "Path '$path' cachepath '$cachepath'\n"; }
  my @scache = stat($cachepath);
  my $code;
  if (!$scache[9] || $scache[9] < $spath[9]) {
    if ($debug) { print STDERR "Parsing '$path' anew.\n"; }
    my $code = __parse($path, $cachepath, $digest);
    return (wantarray ? ($code, $cachepath) : $code);
  } elsif (!$pages_loaded{$path}) {
    if ($debug) { print STDERR "Loading '$cachepath' cache.\n"; }
    my $code = __suckfile($cachepath);
    return (wantarray ? ($code, $cachepath) : $code);
  } else {
    return undef;
  }
}

sub output {
  my ($path, $pass, $params, $state) = @_;
  my $realpath = __resolve($path);
  if (!$realpath) {
    return __error("Could not resolve '$path'.");
  }
  my $digest = Digest::MD5::md5_hex($realpath);
  my $func = "main::perlpage_$digest";
  my $out = HTTP::PerlPages->out();
  my ($code, $cachepath) = parse($realpath, $digest);
  if ($code) {
    my $r = eval($code);
    if (!defined($r)) {
      $out->print(__error("Loading error in '$path' ('$cachepath'); $@\n"));
      return (wantarray ? ($out->{buffer}, 0) : $out->{buffer});
    }
    $pages_loaded{$realpath} = 1;
  }
  if ($mode eq 'CGI') {
    if (!$params) { $params = __cgi_params(); }
    if (!$state && $usestate) { $state = __cgi_state(); }
  }
  my $r = eval { &$func($out, $path, $pass, $params, $state); };
  if (!defined($r)) { 
    $out->print(__error("Running error in '$path' ('$cachepath'); $@\n"));
  } elsif ($r == 0) {
    $out->print(__error("Running exception in '$path' ('$cachepath'); $@\n"));
  }
  return (wantarray ? ($out->{buffer}, $r) : $out->{buffer});
}

sub exec {
  my $req = shift || HTTP::CGIRequest::get();
  my ($output, $r) = output(@_);
  $req->print($output);
  return $r;
}

##---- Handle for output ---------------------------------------------------##

sub out {
  my $class = shift;
  my $classname = ref($class) || $class;
  my $self = { buffer => '' };
  return bless($self, $classname);
}

sub print {
  my $self = shift;
  foreach my $arg (@_) {
    $self->{buffer} .= $arg;
  }
}

##---- private code --------------------------------------------------------##

sub __cgi_params {
  my $params = HTTP::Params::get();
}

sub __cgi_state {
  my $state = HTTP::State::get();
}

sub __resolve {
  my $path = shift;
  if (!(-f $path)) {
    if ($path !~ /^\//) {
      foreach $inc (@INC) {
        if (-f "$inc/$path") {
          $path = "$inc/$path";
          last;
        }
        if (-f "$inc/HTTP/PerlPages/$path") {
          $path = "$inc/HTTP/PerlPages/$path";
          last;
        }
      }
    }
  }
  $path = __realpath($path);
  return (-f $path ? $path : undef);
}

sub __realpath {
  my $path = shift;
  if ($path !~ /^\//) {
    my $cwd = getcwd();
    if ($path && $cwd) {
      my $sep = '/';
      if ($cwd =~ /^[a-zA-Z]:\\/) { ## We're on windows
        $sep = '\\';
      }
      $cwd =~ s/$sep$//;
      my $realpath = "$cwd$sep$path";
      while (1) { last if (!($realpath =~ s/\/[^$sep]+$sep\.\.$sep/$sep/)); }
      while (1) { last if (!($realpath =~ s/\.$sep//)); }
      return $realpath;
    } elsif ($debug) {
      print STDERR "Could not find realpath for '$path'.\n";
    }
  }
  return $path;
}

sub __suckfile {
  my $path = shift;
  if (open(FILE, "< $path")) {
    binmode FILE;
    my $text = '';
    my $buf;
    while (sysread(FILE, $buf, 1024) > 0) {
      $text .= $buf;
    }
    close FILE;
    return $text;
  }
  return undef;
}

sub __parse {
  my $path = shift;
  my $cachepath = shift;
  my $digest = shift;
  my $text = __suckfile($path);
  my $code = '';
  my @tokens = __tokenize($text);
  foreach my $token (@tokens) {
    if ($token->{type} eq 'html') {
      $code .= "  \$out->print(\"" . __escape($token->{text}) . "\");\n";
    } elsif ($token->{type} eq 'perl') {
      $code .= $token->{text};
    } elsif ($token->{type} eq 'escape') {
      $code .= "  \$out->print(html_escape($token->{text}));\n";
    } elsif ($token->{type} eq 'expr') {
      $code .= "  \$out->print($token->{text});\n";
    } elsif ($token->{type} eq 'directive') {
      $code .= __encode_directive($token);
    } elsif ($token->{type} eq 'error') {
      print STDERR "ERROR: $token->{text}\n";
    }
  }
  $code =
    "package main;\n" .
    "use HTTP::PerlPages;\n" .
    "use HTTP::PerlPages::Util;\n" .
    "my \$originalpath = '$path';\n" .
    "my \$compiletime = " . time() . ";\n" .
    "sub perlpage_$digest {\n" .
    "  my (\$out, \$path, \$pass, \$params, \$state) = \@_;\n" .
    $code .
    "  return 1;\n" .
    "\n}\n1;\n";
  my $fh;
  if (open($fh, "> $cachepath")) {
    print $fh $code;
    close($fh);
  }
  return $code;
}

sub __encode_directive {
  my $token = shift;
  if ($token->{directive} eq 'include') {
    my $path = $token->{args};
    return
     "  my \$__str =\n" .
     "    HTTP::PerlPages::output(\"$path\", \$pass, \$params, \$state);\n" .
     "  \$out->print(\$__str);\n";
  } elsif ($token->{directive} eq 'require') {
    my $code = '';
    my @names = split(/[^a-zA-Z0-9_]+/, $token->{args});
    foreach my $name (@names) {
      $code .= "  my \$$name = \$pass->{'$name'};\n" .
               "  if (!defined(\$$name)) {\n" .
               "     \$out->print(\"Developer: '$name' Required.\");\n" .
               "     return 0;\n" .
               "  }\n";
    }
    return $code;
  } elsif ($token->{directive} eq 'declare') {
    my $code = '';
    my @names = split(/[^a-zA-Z0-9_]+/, $token->{args});
    foreach my $name (@names) {
      $code .= "  my \$$name = \$pass->{'$name'};\n";
    }
    return $code;
  } else {
    return "## Unknown directive '$token->{directive}'\n";
  }
}

sub __escape {
  my $str = shift;
  $str =~ s/([\\"])/\\$1/g;
#  $str =~ s/\$\$/\\\$/g;
#  $str =~ s/@/\\@/g;
#  $str =~ s/%/\\%/g;
  $str =~ s/\$/\\\$/g;
  $str =~ s/\@/\\\@/g;
  $str =~ s/\%/\\\%/g;
  return $str;
}

sub __pass_string {
  my $text = shift;
  my $delim = shift;
  my $string = '';
  while ($text =~ s/^(.)//s) {
    my $char = $1;
    $string .= $char;
    if ($char eq '\\' && $text =~ s/^(.)//s) {
      $string .= $1;
    } elsif ($char eq $delim) {
      return ($text, $string);
    }
  }
  return ('', $string);
}

sub __pass_code {
  my $text = shift;
  my $code = '';
  my $type = 'perl';
  if ($text =~ s/^=//) {
    $type = 'escape';
  } elsif ($text =~ s/^!//) {
    $type = 'expr';
  }
  while ($text =~ s/^(.)//s) {
    my $char = $1;
    if ($char eq '\'' || $char eq '"') {
      my $string;
      ($text, $string) = __pass_string($text, $char);
      $code .= $char . $string;
    } elsif ($char eq '%' && $text =~ s/^>//) {
      return ($text, { type => $type, text => $code });
    } else {
      $code .= $char;
    }
  }
  return ('', { type => $type, text => $code });
}

sub __pass_directive {
  my $text = shift;
  if ($text =~ s/^(\w+)\s+//) {
    my $directive = $1;
    my $args = '';
    while ($text =~ s/^(.)//s) {
      my $char = $1;
      if ($char eq '#' && $text =~ s/^>//) {
        $args =~ s/^\s+//;
        $args =~ s/\s+$//;
        return (
          $text,
          { type => 'directive', directive => $directive, args => $args }
        );
      }
      $args .= $char;
    }
    return ('', { type => 'error', text => 'No end of directive section' });
  } else {
    return ('', { type => 'error', text => 'unspecified directive' });
  }
}

sub __tokenize {
  my $text = shift;
  my @tokens;
  my $html = '';
  while (length($text)) {
    $text =~ s/^(.)//s;
    my $char = $1;
    if ($char eq '<' && $text =~ s/^%//) {
      my $token;
      if (length($html)) { push @tokens, { type => 'html', text => $html }; }
      ($text, $token) = __pass_code($text);
      push @tokens, $token;
      $html = '';
    } elsif ($char eq '<' && $text =~ s/^#//) {
      my $token;
      if (length($html)) { push @tokens, { type => 'html', text => $html }; }
      ($text, $token) = __pass_directive($text);
      push @tokens, $token;
      $html = '';
    } else {
      $html .= $char;
    }
  }
  if (length($html)) { push @tokens, { type => 'html', text => $html }; }
  return @tokens;
}

sub __error {
  my $msg = shift;
  warn $msg;
  if ($debug) {
    return $msg;
  } else {
    return 'An error has occurred.';
  }
}

1;

__END__

=head1 NAME

HTTP::PerlPages - a parsing library for perl pages.

=head1 SYNOPSIS

PerlPages reverses the perl vs. html balance normally found in perl CGI scripts;
we start off assuming text is html, until we meet special tokens.  Then
we proceed as perl.  Until we meet a counter token, then we switch to html
again.  The advantage is simple; your code looks a lot more like the end result.
Designers are happy, prototypers are happy.  You just have to be a bit
careful to separate out the application logic.  But that is exactly where
you can show off your library building skills.

=head1 FUNCTIONS

HTTP::PerlPages::exec(request, path, pass, params, state);

HTTP::PerlPages::output(path, pass, params, state);

path is the path to the perlpage.  If it's not found immediately, it is
looked for in the directories specified in @INC.
pass is a hash-reference of name/value pairs that must be passed as variables
to the perlpage.  For example, if I pass { 'foo' => 'bar' } to a perlpage,
the perlpage can then assume it has a variable called $foo in its scope.

=head1 SPECIAL TOKENS

	<% perl code %>
	<%= escaped perl expression %>
        <%! perl expression %>
	<#include #>
	<#require #>
	<#declare #>

Everything in between <% and %> embeds perl.
Everything in between <%= and %> will be seen by the parser as to be
embedded inside a print(HTTP::PerlPages::Util::html_escape());
Stuff in between <# and #> embeds special indicators for
the parser to modify its behaviour.  They are:

	<#include PATH #>
	<#require ARRAYREF, HASHREF #>

The include pragma is used to include other files, that will be treated
in the exact same fashion as the original file; as a perlpage namely with
the same amount and value of variables.

	<#include ../pages/foo.pp #>

The require pragma is used to specify that this page requires certain
variables to exist upon execution.  Not providing these variables to
the page will result in an execution error.  The variable names are
provided as the contents of a literal array reference (check merely for
existence) or a literal hash reference (checks the value of a variable
(the key) against a regular expression (the value)).

	<#require { formid => "[0-9]+" } #>

=head1 FILES

The library generates files inside /tmp, called 'perlpage_' plus the
MD5 sum of the realpath of the original page.
These files are, of course, subject to tmpwatch, and they can also be
removed at will by an administrator.

=head1 BUGS

Many, probably.

=head1 DATE

08 November 2006

=head1 AUTHOR

kees@pink-frog.com
