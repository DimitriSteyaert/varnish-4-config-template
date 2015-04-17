##Varnish 4 configuration template

###The Setup
This configuration file can be used to quickly configure your Varnish 4 installation. This is a rather general file that can be used as a start for different kinds of websites.

###Installation
* First of all create a local backup of your current varnish configuration file: `cp /etc/varnish/default.vcl /etc/varnish/default.vcl.bak`
* Then edit the file /etc/varnish/default.vcl and add the contents of this configuration
* Test your config: `varnishd -C -f /etc/varnish/default.vcl`
* Restart varnish: `/etc/init.d/varnish restart`
