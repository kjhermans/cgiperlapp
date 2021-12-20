#!/usr/bin/perl -I../lib

sub preheader
{
  state()->{authenticated} = undef;
  state()->{user} = undef;
  state()->{pe_id} = undef;
}

use common;

my $username = param('username');
my $password = param('password');

if ($username && $password) {
  my $user = wonkadb_login($username, $password);
  if ($user) {
    state()->{authenticated} = 1;
    state()->{user} = $user;
    logmsg(2,
      "User $user->{usr_login} / $user->{usr_gecos} logged in", $user->{usr_id}
    );
    foreach my $pref (@{$user->{prefs}}) {
      if ($pref->{name} =~ /^([a-z]+)_refresh$/) {
        state()->{$1}{refresh} = $pref->{value};
      }
    }
    message('Logged in', 'main.cgi');
  } else {
    error('Login failed', 'login.cgi');
  }
} else {
  render('login.spp');
}

1;
