This is the template for all my web applications. Gets me going
really quickly. It's based on perl, CGI and Apache.

====

Apache is normally configured something like this:

APPNAME=foo
LOCATION=/var/foo

Alias		/$(APPNAME)/html	$(LOCATION)/$(APPNAME)/static/html
Alias		/$(APPNAME)/img		$(LOCATION)/$(APPNAME)/static/img
Alias		/$(APPNAME)/js		$(LOCATION)/$(APPNAME)/static/js
Alias		/$(APPNAME)/css		$(LOCATION)/$(APPNAME)/static/css
ScriptAlias	/$(APPNAME)/		$(LOCATION)/$(APPNAME)/cgi/
