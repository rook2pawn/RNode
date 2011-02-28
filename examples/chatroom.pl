use common::sense;
use lib "$ENV{HOME}/RNode";
use RNode;
use Text::Trim;

sub getInput {
	my $fh = shift;
	my $input = <$fh>;
	return trim($input);
}

# define servers/clients/responders
my $room = RNode->new(type=>'server', id=>'room', port=>7400);
my $roomActivity = RNode->event(id=>'roomActivity', event=>'room hearsFrom anyone');

# define identifiers
RNode->addIdentification(id=>'anyone', test=>sub { 
	my $_ = shift;
	return (m/^\w+/);
});
# an onConnect specification
$room->onConnect(sub {
	my $data = shift; 
	my $client = $data->{'handle'}; 
	print $client "Welcome to The Room 1.0\x0d\x0aWhat is your name: "; 
	my $name = getInput($client);
	my $server = $data->{'server'};
	$server->{'clients'}{$client}{'name'} = $name; # you can treat $data->{'server'}{data->{'handle'} like a session
						       # and you can recall it later see PART B *** in comments
	print $client "Welcome, $name.\x0d\x0a";
	$room->broadcastAllExcept($data, "$name has connected. Please say hi!\x0d\x0a");
});
$room->onDisconnect(sub {
	my $data = shift; 
	my $client = $data->{'handle'}; 
	my $server = $data->{'server'};
	my $name = $server->{'clients'}{$client}{'name'};
	$room->broadcastAllExcept($data, "$name has disconnected.\x0d\x0a");
});
# add subscribers
$room->subscribe('roomActivity', sub { 
	my $data = shift; # this contains server data only if the event being subscribed to in this case roomActivity, is an 
				# event that can be fired from a server RNode
			  # i.e. data changes based on where it is firing from.
	my $server = $data->{'server'}; 
	my $handle = $data->{'handle'}; 
	my $speakerName = $server->{'clients'}{$handle}{'name'};  # *** PART B here, we retrieve some data we set earlier
	my $buffer = $data->{'buffer'};
	trim($buffer);
	print "* The Room hears : $buffer from $speakerName\n";
	$room->broadcastAllExcept($data, "$speakerName: $buffer\x0d\x0a");
});
RNode->start;
