package HTTP::PerlPages::Table;

use Storable qw (lock_store lock_retrieve);
use Digest::MD5;
use HTTP::PerlPages;

our $sql_paginate = 1;

##
## Fetches a subset of a SELECT query for you (for pagination purposes)
## and caches a bigger subset (or all) on disk so that, if you make
## the same call again within 5 minutes, the result will be fetched from
## the cache instead.
##

sub new {

  my $dbh = shift || die "Need database handle";
  my $par = shift || die "Need params";
  my $len = shift || die "Need page length";
  my $sql = shift || die "Need SQL SELECT statement";

  my @binds = @_;
  my $digest = Digest::MD5::md5_hex($sql . join(',', @binds));
  my $table = HTTP::PerlPages::Table->instance();
  $table->{digest} = $digest;
  my $page = 0;
  my $off = 0;
  if ($par->{id} eq $digest) {
    if ($page = int($par->{page})) {
      $off = $page * $len;
    }
    $table->{prev} = $page;
  }
  if ($sql_paginate) {
    $sql .= " offset $off limit " . ($len + 1);
  }
  my $sth = $dbh->prepare($sql);
  if ($sth && $sth->execute(@binds)) {
    while (my $row = $sth->fetchrow_hashref()) {
      if ($sql_paginate) {
        push @{$table->{tab}}, $row;
      } elsif ($n >= $off) {
        last if ($n >= $off + $len);
        push @{$table->{tab}}, $row;
      }
    }
    while (scalar(@{$table->{tab}}) > $len) {
      pop(@{$table->{tab}});
      $table->{next} = 1;
    }
    return $table;
  }
  return undef;
}

##
## Object representing a page within the paginated table
##

sub instance {
  my $class = shift;
  my $classname = ref($class) || $class;
  my $self = {
    tab => [],
    prev => 0,
    next => 0
  };
  bless $self, $classname;
  return $self;
}

##
## Rendering calls; uses other libraries
##

sub output {
  my $self = shift; (ref($self) eq 'HTTP::PerlPages::Table') || die;
  my $str =
    HTTP::PerlPages::output('HTTP/PerlPages/table.spp', { page => $self });
  return $str;
}

1;
