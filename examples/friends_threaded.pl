use common::sense;
use lib "$ENV{HOME}/RNode";
use RNode_threaded;
use Text::Trim;
use Data::Dumper;
# define servers/clients/responders

my $room = RNode->new(type=>'server', id=>'room', port=>7400);
my $yesman = RNode->new(type=>'responder', id=>'yesman');
my $critic = RNode->new(type=>'responder', id=>'critic', group=>'room');

my $roomActivity = RNode->event(id=>'roomActivity', event=>'room hearsFrom anyone');
my $yesmanSpeaks = RNode->event(id=>'yesmanSpeaks', event=>'room hearsFrom yesman');
# define identifiers
RNode->addIdentification(id=>'anyone', test=>sub { 
	my $_ = shift;
	return (m/^\w+/);
});
RNode->addIdentification(id=>'yesman', priority=>1, test=>sub { 
	my $_ = shift;
	return (m/^yesman: /);
});
$room->onConnect(sub {
	my $data = shift; 
	print "in room on Connect\n";
	print Dumper($data);
	my $client = $data->{'handle'}; 
	print $client "Welcome to The Room 1.0\x0d\x0aWhat is your name: "; 
	my $name = <$client>; 
	trim($name);
	print "Recieved name -->$name<--\n"; 
	my $server = $data->{'server'};
	$server->{'clients'}{$client}{'name'} = $name;
	print $client "Welcome, $name.\x0d\x0a";
});
# add subscribers
$room->subscribe('roomActivity', sub { 
	my $data = shift; # this contains server data only if the event being subscribed to in this case roomActivity, is an 
				# event that can be fired from a server RNode
			  # i.e. data changes based on where it is firing from.
	print "ROOM... dumping data\n";
	print Dumper($data);
	my $server = $data->{'server'}; 
	my $handle = $data->{'handle'}; 
	my $speakerName = $server->{'clients'}{$handle}{'name'} || $data->{'id'} || "Undefined";
	my $buffer = $data->{'buffer'};
	trim($buffer);
	print "* The Room hears : $buffer from $speakerName\n";
	$room->broadcastAllExcept($data, "$speakerName: $buffer\x0d\x0a");
});
$yesman->subscribe('roomActivity', sub {
	my $data = shift; # again this has server / handle data since its fired from a server 
	my $server = $data->{'server'};
	my $handle = $data->{'handle'}; 
	my $speakerName = $server->{'clients'}{$handle}{'name'};
	my $buffer = $data->{'buffer'};
	trim($buffer);
	print "* Yesman hears : $buffer from $speakerName\n";
	$room->broadcastAll($data, "yesman: I agree with what $speakerName said when he said $buffer\x0d\x0a");
});
$critic->subscribe('yesmanSpeaks', sub {
	my $data = shift; # this does NOT have server/handle data because this event triggered from a non-server source.
			  # (in this case it was triggered by buffer update on a responder which had a group that matched an event
			  # if it has a response it can notify a server object directly (but this notification won't be treated as net data)
	my $buffer = $data->{'buffer'};
	trim($buffer);
	print "* critic hears : $buffer\n";
	$room->notify("critic: stop being such a yesman.\x0d\x0a");
});
# start

RNode->start;
