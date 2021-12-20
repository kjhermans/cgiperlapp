#!/usr/bin/perl -I../lib

use common;

require_login();

render('main.spp');

1;
