use common::sense;
use lib "$ENV{HOME}/RNode";
use RNode;
use Data::Dumper;
use Stream::ReadWrite;
use Handshake::WebSocket;
use perlpage;
use Text::Trim;
use JSON;
my $mtgBrowse = perlpage->new();
$mtgBrowse->loadConf;

# define servers/clients/responders
my $webServer = RNode->new(type=>'server', port=>4500, id=>'webserver');
my $webSocketHandler = RNode->new(type=>'server', port=>9000, id=>'websocket');
my $webRouter = RNode->new(type=>'responder', id=>'webRouter');
my $keypressResponder = RNode->new(type=>'responder', id=>'keypressResponder');


# define events;
RNode->event(id=>'generalContact', event=> 'webserver hearsFrom webtraffic');
# can multiple syntehetic events fire the same event? yes.
RNode->event(id=>'generalContact', event=> 'webserver hearsFrom keypress');

my $websocketEvent = RNode->event(id=>'websocketHandshakeEvent', event=>'websocket hearsFrom websocketHandshake');
my $keypressEvent = RNode->event(id=>'keypress', event=>'keypress');
my $standardRequestEvent = RNode->event(id=>'standardRequestEvent', event=>'standardRequestEvent');


# define identifiers
RNode->addIdentification(id=>'webtraffic', priority=>0, test=>sub { 
	my $_ = shift;
	return (m/^GET|^POST/);
});
RNode->addIdentification(id=>'websocketHandshake', priority=>1, test=>sub {
	$_ = shift;
	return ((m/Upgrade: WebSocket/ms) && (m/Sec-WebSocket-Key1:/ms) && (m/Sec-WebSocket-Key2/ms));
});
RNode->addIdentification(id=>'keypress', priority=>1, test=> sub {
	$_ = shift;
	return (m/POST \/mtg\/keypress/);
});

# add subscribers
$webRouter->subscribe('generalContact', sub {
	my $data = shift;
	my $buffer = $data->{'buffer'};
	my $identity = identify($buffer);
	if ($identity eq "keypress") {
		print "Firing keypress event\n";
		$keypressEvent->publish($data);
	} elsif ($identity eq "webtraffic") {
		print "firing webtraffice event\n";
		$standardRequestEvent->publish($data);
	} else {
		print "\n*******\nwebrouter could not provide routing for \n$buffer\n*******\n";
	}
});

$webSocketHandler->subscribe('websocketHandshakeEvent', sub {
	my $data = shift;
	my $buffer = $data->{'buffer'};
	my $handshake = Handshake::WebSocket->new();
	my $response = $handshake->parse($buffer);
 	my $handle = $data->{'handle'};
	print $handle $response->{'handshakeResponse'};
}	
);
$webServer->subscribe('standardRequestEvent', sub {
	my $data = shift;
	my $buffer = $data->{'buffer'};
	my $handle = $data->{'handle'};
	my $server = $data->{'server'};
	print $handle $mtgBrowse->http_header.$mtgBrowse->header.$mtgBrowse->navigation.$mtgBrowse->content.$mtgBrowse->footer."\x0d\x0a\x0d\x0a";
	$server->{'readers'}->remove($handle);
	delete $server->{'clients'}{$handle};
	close $handle;
});
$keypressResponder->subscribe('keypress', sub {
	my $data = shift;
	print "\n***keypressResponder responding to keypress event***\n";
	my $search = ($data->{'buffer'} =~ /search=(.+?)$/m);
	print "\t search is for $search\n";
	my %out = ();
	$out{'pre'} = 'alert("foobar")'; #MAIN.respondent.set('searchBox','value','$search');|);
	my $jsonText = encode_json(\%out);
	my $handle = $data->{'handle'};
	my $length = length $jsonText;
	my $string =qq|HTTP/1.1 200 OK\x0d\x0aContent-Length: $length\x0d\x0aContent-type: text/json\x0d\x0a\x0d\x0a|;
	print $handle $string.$jsonText."\x0d\x0a";
});

# start
RNode->start;
