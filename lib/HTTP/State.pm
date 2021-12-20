package HTTP::State;

use Storable qw(lock_store lock_retrieve);
use POSIX qw(strftime);

our $expiry = 60;     ## server side expiry; in minutes or zero is forever
our $persistence = 0; ## client side cookie persistence; in days or zero is none
my $cookiepath;
{
  my $tempdir = $ENV{TEMP} || '/tmp';
  my $sep = '/';
  if ($tempdir =~ /^[a-zA-Z]:\\/) {  ## We're on windows
    $sep = '\\';
  }
  if ($tempdir !~ /$sep$/) {
    $tempdir .= $sep;
  }
  $cookiepath = $tempdir . "perlcookie_";
}

#
# Private utility function.  Creates a cookie and returns it.
#

sub __createcookie {
  srand($$);
  foreach $attempt (1..100) {
    my $cookie = join '', ( 0..9, 'A'..'Z', 'a'..'z')[
      rand 62, rand 62, rand 62, rand 62,
      rand 62, rand 62, rand 62, rand 62,
      rand 62, rand 62, rand 62, rand 62,
      rand 62, rand 62, rand 62, rand 62 ];
    if (!stat("$cookiepath$cookie")) {
      return $cookie;
    }
  }
  die "Could not create cookie in 100 attempts.";
}

##----------------------------------------------------------------------------
##
## Returns a state to the caller.
##
##----------------------------------------------------------------------------

sub get {
  my $arg = shift;
  my $cookie;
  my $state;
  if (ref($arg)) {
    $cookie = $arg->cookie();
  } else {
    $cookie = $arg;
  }
  if (!defined($cookie)) {
    $cookie = $ENV{HTTP_COOKIE};
  }
  if (!defined($cookie)) {
    $cookie = __createcookie();
    $ENV{HTTP_COOKIE} = "perlcookie=$cookie";
  }
  if ($cookie =~ /^perlcookie=([0-9A-Za-z]{16})$/) {
    $cookie = $1;
  } else {
    $cookie = __createcookie();
    $ENV{HTTP_COOKIE} = "perlcookie=$cookie";
  }
  my $path = "$cookiepath$cookie";
  my @s = stat($path);
  if ($expiry && defined($s[8]) && ($s[8] < (time() - ($expiry * 60)))) {
    system("rm $path");
  } else {
    $state = eval { lock_retrieve($path); };
  }
  if (!defined($state)) {
    $state = HTTP::State->new({ cookie => $cookie });
  }
  return $state;
}

##----------------------------------------------------------------------------
##
## Delete the state.
##
##----------------------------------------------------------------------------

sub clear {
  my $state = shift;
  foreach my $key (keys(%{$state})) {
    if ($key ne 'cookie') {
      delete $state->{$key};
    }
  }
}

##----------------------------------------------------------------------------
##
## Saves a state back on disk.
##
##----------------------------------------------------------------------------

sub save {
  my $state = shift;
  lock_store($state, "$cookiepath$state->{cookie}");
}

sub sendcookie {
  my $state = shift;
  my $addition = '';
  if (int($persistence)) {
    my $expires = strftime("%a %b %e %H:%M:%S %Y GMT",
      gmtime(time() + (86400 * $persistence))
    );
    $addition = "; expires=$expires";
  }
  return ("Set-Cookie", "perlcookie=$state->{cookie}$addition");
}

##----------------------------------------------------------------------------
##
## To make it an object.
##
##----------------------------------------------------------------------------

sub new {
  my $class = shift;
  my $classname = ref($class) || $class;
  my $hash = shift || { cookie => __createcookie() };
  bless $hash, $classname;
  return $hash;
}

#sub DESTROY {
#  my $self = shift;
#  HTTP::State::savestate($self);
#}

1;
