use lib '../pag';

use config;
use DBI;

use HTTP::CGIRequest;
use HTTP::Params;
use HTTP::State;

use HTTP::PerlPages;
use HTTP::PerlPages::Menu;

my $noheader;
my $nofooter;
my $request = HTTP::CGIRequest::get();
my $state = HTTP::State::get($request);
my $params = HTTP::Params::get($request);

my $dbh = DBI->connect($config->{dbi}{url}, $config->{dbi}{username})
          || fatal("DB Connection");

my $language = $state->{user}{usr_language} || 'EN';
my $dict = eval("use dict_$language; dict_$language();");
my $privs = {
  ## Fill in
};

eval { preheader(); };

if (!$noheader) {
  $request->content_type("text/html; charset=UTF-8");
  $request->headers_out($state->sendcookie());
  render('header.spp', { });
}

##---- functions -----------------------------------------------------------##

sub noheader
{
  $noheader = 1;
}

sub nofooter
{
  $nofooter = 1;
}

sub render {
  my ($page, $hash) = @_;
  HTTP::PerlPages::exec($request, $page, $hash, $params, $state);
}

sub state {
  return $state;
}

sub dbh {
  return $dbh;
}

sub param {
  return $params->{$_[0]};
}

sub get_param {
  return param(@_);
}

sub arrayparam {
  my $value = $params->{$_[0]};
  if (!defined($value)) {
    return [];
  }
  if (ref($value) ne 'ARRAY') {
    return [ $value ];
  }
  return $value;
}

sub params {
  return $params;
}

sub fatal {
  error(@_);
  exit(-1);
}

sub error {
  my ($msg, $ok) = @_;
  wonkadb_log(4, $msg);
  render('error.spp', { msg => $msg, ok => $ok });
}

sub message {
  my ($msg, $ok) = @_;
  render('message.spp', { msg => $msg, ok => $ok });
}

sub redirect {
  my ($page) = @_;
  render('redirect.spp', { page => $page });
}

sub require_login {
  my $dontchangepwd = shift;
  if (!($state->{authenticated})) {
    redirect('login.cgi');
    exit(0);
  } elsif (!$dontchangepwd && $state->{user}{usr_change_password}) {
    redirect('changepwd.cgi');
    exit(0);
  }
}

sub authenticate {
  my ($username, $password) = @_;
##.. do something
  $state->{authenticated} = 1;
  $state->save();
  return 1;
}

sub formid {
  ++($state->{formid});
  return $state->{formid};
}

sub validate_formid {
  my $formid = param('formid');
  if (!defined($formid)) {
    return 0;
  }
  if ($formid < $state->{formid}) {
    fatal("Form was processed already.");
  } else {
    return 1;
  }
}

sub validate_param_int {
  my $value = param(@_);
  if (!defined($value) || $value !~ /^[0-9]+$/) {
    fatal("Param '$value' is not an integer");
  }
  return $value;
}

sub validate_param_ipv4address {
  my $value = param(@_);
  if ($value !~ /^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/ ||
      $1 > 255 || $2 > 255 || $3 > 255 || $4 > 255)
  {
    fatal("Param '$value' is not a valid IPv4 address");
  }
  return $value;
}

sub get_privileges_tree {
  return $privs;
}

sub get_privileges {
  my @gp = split(/:/, $state->{user}{usr_privileges});
  return @gp;
}

sub _descend_privileges
{
  my ($p, $q, $r, $s) = @_;
  if (ref $r eq 'HASH') {
    foreach my $k (keys(%{$r})) {
      if ($s || $k eq $p) {
        $q->{$k} = 1;
        _descend_privileges($p, $q, $r->{$k}, 1);
      } else {
        _descend_privileges($p, $q, $r->{$k}, $s);
      }
    }
  } elsif (ref $r eq 'ARRAY') {
    foreach my $_p (@{$r}) { 
      if ($s || $_p eq $p) { $q->{$_p} = 1; }
    }
  }
}

sub get_privileges_all {
  my @p = get_privileges();
  my %q;
  foreach my $p (@p) { _descend_privileges($p, \%q, $privs, 0); }
  return keys(%q);
}

sub has_privilege {
  my ($action) = @_;
  my @gp = get_privileges_all();
  foreach my $gp (@gp) {
    if ($action eq $gp) {
      return 1;
    }
  }
  return undef;
}

sub require_privilege {
  my ($action) = @_;
  if (!has_privilege($action)) {
    error("You don't have the privilege to do this");
    exit 0;
  }
}

sub table_params {
  my $id = shift;
  return {
    page => param($id . '_page'),
  };
}

sub table_get {
  my $fnc = shift;
  my $id = shift;
  my $table = &$fnc(table_params($id), @_);
  $table->{id} = $id;
  return $table;
}

sub dict {
  my @args = @_;
  if (scalar(@args) eq '0') {
    return $dict;
  }
  my $key = $args[ 0 ];
  if (defined($dict->{$key})) {
    return $dict->{$key};
  } else {
    return $key;
  }
}

sub END {
  if (!$nofooter) {
    render('footer.spp');
    $state->save();
  }
}

sub logmsg
{
  my $msg = shift;
##..
}

1;
