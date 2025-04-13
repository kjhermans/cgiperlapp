sub login
{
  my ($username, $password) = @_;
  my $users = selectall_properly(
    "select * from panne_users where usr_login=?", $username
  );
  my $result = $users->[0];
  return $result;
}

1;
