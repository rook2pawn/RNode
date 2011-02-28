use common::sense;
use lib "$ENV{HOME}/RNode";
use RNode;
use Handshake::WebSocket;
use Data::Dumper;
use Text::Trim;
# define servers/clients/responders
my $webServer = RNode->new(type=>'server', port=>80, id=>'webserver');
my $webSocket = RNode->new(type=>'server', port=>9000, id=>'websocket');
my $chattySquirrel = RNode->new(type=>'responder', id=>'chattySquirrel');
my $squirrelServer = RNode->new(type=>'server', port=>5150, id=>'squirrelServer');
# define events;
RNode->event(id=>'webrequests', event=> 'webserver hearsFrom webtraffic');
RNode->event(id=>'handshakeEvent', event=>'websocket hearsFrom websocketHandshake');
RNode->event(id=>'websocketTraffic', event=>'websocket hearsFrom anyone');
RNode->event(id=>'squirrelServerActivity', event=>'squirrelServer hearsFrom anyone');

# define identifiers
RNode->addIdentification(id=>'webtraffic', priority=>0, test=>sub { 
	my $_ = shift;
	return (m/^GET \/ HTTP/);
});
RNode->addIdentification(id=>'websocketHandshake', priority=>1, test=>sub {
	$_ = shift;
	return ((m/Upgrade: WebSocket/ms) && (m/Sec-WebSocket-Key1:/ms) && (m/Sec-WebSocket-Key2/ms));
});
RNode->addIdentification(id=>'anyone', test => sub {
	return 1;
});
# add subscribers
$squirrelServer->subscribe('squirrelServerActivity', sub {
	my $data = shift;
	my $client = $data->{'handle'};
	my $buffer = $data->{'buffer'};
	trim($buffer);
	$webSocket->broadcastAll($data, "\x00".$buffer."\xff");	
});
$chattySquirrel->subscribe('websocketTraffic', sub {
	my $data = shift;
	print "Chatty Squirrel overheard the following websockettraffic \n -->".$data->{'buffer'}."<--\n";
});
$webSocket->subscribe('handshakeEvent', sub {
	my $data = shift;
	print "**********\nwebsocket sees a handshakeEvent\n";
#	print Dumper($data);
	my $buffer = $data->{'buffer'};
	my $handshake = Handshake::WebSocket->new();
	my $response = $handshake->parse($buffer);
 	my $handle = $data->{'handle'};
	print $handle $response->{'handshakeResponse'};
});
$webServer->subscribe('webrequests', sub {
	my $data = shift;
	print "**********\nwebserver sees a webrequest event\n";
	print Dumper($data);
	my $buffer = $data->{'buffer'};
	my $handle = $data->{'handle'};
	my $server = $data->{'server'};
	print $handle "HTTP/1.1 200 OK\x0d\x0aContent-type: text/html\x0d\x0a\x0d\x0a"."<html><head><title>RNode Degredation Path</title><body><h2>websocket tunnel example</h2><br><br>anyone who connects to this ip at port 5150 (use putty - raw mode) can type what chatty the squirrel says. <h3>Chatty Squirrel says: </h3><div id='chattySquirrel'></div>";
	print $handle "<script>if ('WebSocket' in window) {
	alert('Websocket supported');
	var ws = new WebSocket('ws://rook2pawn.com:9000');
	ws.onopen = function(e) { //alert('opened!'); //this.send('hello');
	};
	ws.onerror = function(e) {
		alert(e);
	}
	ws.onmessage = function(e) {
		document.getElementById('chattySquirrel').innerHTML = e.data;
	}
	
} else {
  // WebSockets not supported
	alert('websocket not supported');
}</script>";
	print $handle "</body></html>\x0d\x0a\x0d\x0a";
	$server->{'readers'}->remove($handle);
	delete $server->{'clients'}{$handle};
	close $handle;
});
# start
RNode->start;
