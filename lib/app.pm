use Digest::SHA qw( sha384 );
use MIME::Base64;

sub _encb64
{
  my $str = shift;
  my $res = encode_base64($str);
  $res =~ s/[\r\n]//g;
  return $res;
}

sub _pwdfrob
{
  my ($password) = @_;
  srand(time());
  my $seed = '';
  for (my $i=0; $i < 16; $i++) {
    $seed .= chr(rand(256));
  }
  return join(':', (
    "SHA",
    _encb64($seed),
    _encb64(sha384($seed . $password))
  ));
}

sub _pwdcheck
{
  my ($pwdstr, $pwdgiv) = @_;
  $pwdstr =~ s/^([^:]+):// || return undef;
  my $method = $1;
  if ($method eq 'plain') {
    if ($pwdstr eq $pwdgiv) {
      return 1;
    }
  } elsif ($method eq 'SHA') {
    $pwdstr =~ s/^([^:]+):// || return undef;
    my $seed = decode_base64($1);
    my $hash = decode_base64($pwdstr);
    if (sha384($seed . $pwdgiv) eq $hash) {
      return 1;
    }
    return 0;
  }
  return undef;
}

sub login
{
  my ($username, $password) = @_;
  my $users = selectall_properly(
    "select * from app_users where usr_login=?", $username
  );
  my $result = $users->[0];
  my $verify = _pwdcheck($result->{usr_password}, $password);
  if ($verify) {
    return $result;
  } else {
    return undef;
  }
}

sub set_password
{
  my ($usrid, $pwd) = @_;
  my $shapwd = _pwdfrob($pwd);
  dbh()->do(
    "update app_users set usr_password=?, usr_change_password=false" .
    " where usr_id=?", undef
    , $shapwd
    , $usrid
  );
}

1;
