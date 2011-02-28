use common::sense;
use lib "$ENV{HOME}/RNode";
use RNode;

########################
# RNode - Tunnel
########################

# define servers/clients/responders
my $tunnel = RNode->new(type=>'server', port=>5150, id=>'tunnel');
my $webclient = RNode->new(type=>'client', peerPort=>80, id=>'webclient', peerAddr=>'127.0.0.1');

# define events;
RNode->event(id=>'webrequests', event=> 'tunnel hearsFrom webproxytraffic');

# define identifiers
RNode->addIdentification(id=>'webproxytraffic', priority=>0, test=>sub { 
	$_ = shift;
	return (m/^GET http.+? HTTP/); #proxy traffic generally uses http:// and full address instead of
				       # relative addresing schemes.
});
# add subscribers
$tunnel->subscribe('webrequests', sub {
	my $data = shift;
	my $req = parseRequest($data->{'buffer'});
	my $response = $tunnel->writeToClient('webclient', $req->{'fullRequest'});
	$tunnel->broadcastOne($data, $response);
});
# start
RNode->start;
