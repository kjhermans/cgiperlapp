#!/usr/bin/perl -I../lib

use common;

require_login(1);

my $pwd1 = param('password1');
my $pwd2 = param('password2');

if ($pwd1 && $pwd2) {
  if ($pwd1 eq $pwd2) {
    set_password(state()->{user}{usr_id}, $pwd1);
    state()->{user}{usr_change_password} = undef;
    message('Password changed successfully', 'main.cgi');
    #render('user.spp', { user => state()->{user} });
  } else {
    error("passwords don't match", 'changepwd.cgi');
  }
} else {
  render('changepwd.spp', { user => state()->{user} });
}

1;
