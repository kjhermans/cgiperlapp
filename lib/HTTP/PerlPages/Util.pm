package main;

use POSIX;

sub render_date_sec {
  my $t = shift;
  return undef if (!defined($t));
  my @tm = localtime($t);
  return sprintf("%.2d-%.2d-%d",
    $tm[3], $tm[4]+1, $tm[5]+1900
  );
}

sub render_datetime_sec {
  my $t = shift;
  my @tm = localtime($t);
  return sprintf("%.2d-%.2d-%d %.2d:%.2d:%.2d",
    $tm[3], $tm[4]+1, $tm[5]+1900, $tm[2], $tm[1], $tm[0]
  );
}

sub html_escape {
  my $str = shift;
  if (!defined($str)) { return ''; }
  $str =~ s/&/&amp;/g;
  $str =~ s/</&lt;/g;
  $str =~ s/>/&gt;/g;
  $str =~ s/'/&#039;/g;
  $str =~ s/"/&quot;/g;
  return $str;
}

#
# Optionizes a set of arguments into a HTML options list.
# Calling conventions:
# value, hashref
# value, array of scalars
# value, arrayref of scalars
# value, arrayref of hashrefs, hashkeykey, hashvalkey, optmodifierfunc
#

sub optionize {
  my $value = shift; ## may be undef, arrayref or scalar
  my $arg1 = $_[0];
  my $arg2 = $_[1];
  my $arg3 = $_[2];
  my $arg4 = $_[3];
  my $result = '';
  if (ref($arg1) eq 'HASH' && !defined($arg2) && !defined($arg3)) {
    while (my ($key, $val) = each %{$arg1}) {
      $result .= "<option value='" . html_escape($key) . "'";
      $result .= optionselected($key, $value);
      $result .= ">" . html_escape($val) . "</option>\n";
    }
  } elsif (ref($arg1) eq 'ARRAY') {
    for (my $i=0; $i<scalar(@{$arg1}); $i++) {
      my $elt = $arg1->[$i];
      if (defined($elt)) {
        if (ref($elt) eq 'HASH') {
          my $key = $elt->{$arg2};
          my $val = $elt->{$arg3};
          if (!defined($arg2) && !defined($arg3)) {
            $result .= optionize($value, $elt);
          } else {
            $result .= "<option value='" . html_escape($key) . "'";
            $result .= optionselected($key, $value);
            if ($arg4) {
              $val = &$arg4($val);
            }
            if (!$val) {
              $val = '--';
            }
            $result .= ">" . html_escape($val) . "</option>\n";
          }
        } elsif (!ref($elt)) {
          my $key = $elt;
          if ($arg2 eq 'INDEX') {
            $key = $i;
          }
          $result .= "<option value='" . html_escape($key) . "'";
          $result .= optionselected($key, $value);
          $result .= ">" . html_escape($elt) . "</option>\n";
        }
      }
    }
  } elsif (!ref($arg1) && !ref($arg2) && !ref($arg3)) {
    while (scalar(@_)) {
      my $elt = shift(@_);
      $result .= "<option value='" . html_escape($elt) . "'";
      $result .= optionselected($elt, $value);
      $result .= ">" . html_escape($elt) . "</option>\n";
    }
  }
  return $result;
}

sub optionselected {
  my $key = shift;
  my $value = shift;
  return '' if (!defined($value));
  if (ref($value) eq 'ARRAY' && grep($key, @{$value})) {
    return ' selected';
  } elsif ($value eq $key) {
    return ' selected';
  } else {
    return '';
  }
}

sub optionize_timelist {
  my $value = shift;
  my $result = '';
  foreach my $elt (@_) {
    $result .= "<option value='$elt'";
    if ($elt eq $value) {
      $result .= " selected";
    }
    $result .= sprintf(">%.2d</option>\n", $elt);
  }
  return $result;
}

my $datetimepopup = 0;

sub datetimepopup {
  $datetimepopup = 1;
}

my $datetimepopupscriptloaded = 0;

sub __render_date {
  my $key = shift || 'date';
  my $t = shift;
  my $null = !$t;
  if (!defined($t)) {
    $t = time();
  }
  my ($day, $month, $year) = ();
  if ($t =~ /^[0-9]+$/) {
    my @tm = localtime($t);
    $day = $tm[3];
    $month = $tm[4];
    $year = $tm[5] + 1900;
  } elsif ($t =~ /([0-9]{2})-([0-9]{2})-([0-9]{4})/) {
    $day = $1;
    $month = $2 - 1;
    $year = $3;
  }
  my @months = (
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  );
  if ($datetimepopup) {
    my $str = '';
    if (!$datetimepopupscriptloaded) {
      $str .= "<script language=javascript src='js/CalendarPopup.js'></script>";
    }
    $str .=
           "<script language=javascript>\n<!--\n".
           "function __dateset_$key(y,m,d) {\n".
           "document.getElementById('__date_$key').value=".
           "LZ(d)+'-'+LZ(m)+'-'+y;\n".
           "document.forms[0].elements['___date_$key'].value=".
           "LZ(d)+'-'+LZ(m)+'-'+y;\n".
           "}\n//-->\n</script>\n".
           "<input type=hidden id='__date_$key' name='__date_$key' value='".
           ($null ? "" : sprintf("%.2d-%.2d-%d", $day, $month+1, $year)).
           "'><input type=text size=10 disabled=true ".
           "name='___date_$key' value='".
           ($null ? "" : sprintf("%.2d-%.2d-%d", $day, $month+1, $year)).
           "'>&nbsp;".
           "<a name='__anchor_$key' id='__anchor_$key' href=\"javascript:".
           "cal.setReturnFunction('__dateset_$key');".
           "cal.select(document.forms[0].elements['__date_$key'],".
           "'__anchor_$key','dd-MM-yyyy');\">".
           "<img src='img/calendar.gif' border=0 ".
           "alt='Calendar' title='Calendar'></a>";
    return $str;
  } else {
    return
      "<td><select name='__day_$key'>\n".optionize($day, 1..31).
      "</select></td>\n".
      "<td><select name='__month_$key'>\n".optionize($month, \@months, 'INDEX').
      "</select></td>\n".
      "<td><input type=text name='__year_$key' value='$year' size='5'></td>\n";
  }
}

sub __render_time {
  my $key = shift || 'date';
  my $t = shift;
  if (!defined($t)) {
    $t = time();
  }
  my ($second, $minute, $hour) = ();
  if ($t =~ /^[0-9]+$/) {
    my @tm = localtime($t);
    $second = $tm[0];
    $minute = $tm[1];
    $hour = $tm[2];
  } elsif ($t =~ /([0-9]{2}):([0-9]{2}):([0-9]{2})/) {
    $hour = $1;
    $minute = $2;
    $second = $3;
  }
  return
    "<td><select name='__hour_$key'>\n".optionize_timelist($hour, 0..23).
    "</select></td><td>:</td>\n".
    "<td><select name='__minute_$key'>\n".optionize_timelist($minute, 0..59).
    "</select></td><td>:</td>\n".
    "<td><select name='__second_$key'>\n".optionize_timelist($second, 0..59).
    "</select></td>\n";
}

sub render_date {
  return "<table><tr>" . __render_date(@_) . "</tr></table>\n";
}

sub render_date_or_null {
  my $key = shift || 'date';
  if ($datetimepopup) {
    return __render_date($key, ( @_ )) . "&nbsp;".
           "<script language=javascript>\n<!--\n".
           "function __dateclear_$key() {\n".
           "document.getElementById('__date_$key').value='';\n".
           "document.forms[0].elements['___date_$key'].value='';\n".
           "}\n//-->\n</script>\n".
           "<a href=\"javascript:__dateclear_$key();\">".
           "<img src=img/calendarnull.gif border=0 alt='Clear' title='Clear'>".
           "</a>";
  } else {
    my $result = 
      "<table><tr>" .
      __render_date($key, ( @_ )) .
      "<td><i>or none:</i></td>" .
      "<td><input type=checkbox name='__null_$key' value=1";
    if (!$_[0]) {
      $result .= " checked=true";
    }
    $result .= "></td>\n</tr></table>\n";
    return $result;
  }
}

sub render_datetime {
  return "<table><tr>" .
         __render_date(@_) .
         "<td><img src=img/clock.gif alt='time:' title='time'></td>".
         __render_time(@_) .
         "</tr></table>\n";
}

sub render_datetime_or_null {
  return "<table><tr>" .
         __render_date(@_) .
         "<td><img src=img/clock.gif></td>".
         __render_time(@_) .
         "<td><i>or none:</i></td>" .
         "<td><input type=checkbox name='__null_$key' value=1></td>\n" .
         "</tr></table>\n";
}

sub render_time {
  return __render_time(@_);
}

sub retrieve_timestamp {
  my $key = shift || 'date';
  if (get_param("__null_$key")) {
    return undef;
  }
  if ($datetimepopup) {
    my $date = get_param("__date_$key");
    if ($date =~ /([0-9]{2})-([0-9]{2})-([0-9]{4})/) {
      my $day = int($1);
      my $month = int($2) - 1;
      my $year = int($3) - 1900;
      return mktime(0,0,0, $day, $month, $year);
    } else {
      return undef;
    }
  } else {
    my $day = get_param("__day_$key");
    my $month = get_param("__month_$key");
    my $year = get_param("__year_$key");
    my $hour = get_param("__hour_$key"); if (!defined($hour)) { $hour = 12; }
    my $minute = get_param("__minute_$key") || '0';
    my $second = get_param("__second_$key") || '0';
    return mktime(
      $second,
      $minute,
      $hour,
      $day,
      $month,
      $year - 1900
    );
  }
}

sub urlencode {
  my $str = shift;
  my $res = '';
  while ($str =~ s/^(.)//s) {
    my $chr = $1;
    if ($chr eq ' ') {
      $res .= '+';
    } elsif ($chr !~ /^[a-zA-Z0-9]$/) {
      $res .= '%' . sprintf("%.2x", ord($chr));
    } else {
      $res .= $chr;
    }
  }
  return $res;
}

1;
