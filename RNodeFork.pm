package RNode;
use common::sense;
use Exporter;
use Stream::ReadWrite;
use Data::Dumper;
use IO::Select;
use IO::Socket;
use IO::Handle;	# thousands of lines just for autoflush :-(
use IO::Socket::INET;
use Text::Trim;
use Carp qw(cluck);
use Switch; 
use JSON;
our @ISA = qw( Exporter );
our @EXPORT = qw( identify parseRequest);


socketpair(CHILD, PARENT, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
			or  die "socketpair: $!";
CHILD->autoflush(1);
PARENT->autoflush(1);

my @eventQueue = (); # 
my @jobQueue = ();
my ($add_server, $rem_server, $get_server, $set_server, $print_server,$get_servers) = serverManager();
my ($add_client, $rem_client, $get_client_byHandle, $get_client, $msgClientById, $get_clients, $broadcast) = clientManager();
my ($add_identification, $get_identification, $get_identifications) = identificationManager();
my ($add_event, $rem_event, $get_event, $set_event, $print_event,$get_events) = eventManager();
my ($add_entity, $get_entity, $get_entities) = entityManager();
my ($add_responder, $get_responder, $get_responders) = responderManager();

sub entityManager {
	my @entities;
	my $add_entity = sub {
		my $entity = shift;
		push @entities, $entity;
	};
	my $get_entity = sub {
		my $id = shift;
		my @foo = grep {$_ eq $id} @entities;
		if (@foo) {
			return $foo[0];
		}
		print "returning nothing in entity manager\n";
		return;
	};
	my $get_entities = sub {
		return @entities;
	};
	return ($add_entity, $get_entity, $get_entities);
}
sub parseRequest {
	my %foo = ();
	my $fullRequest = shift;
	foreach $_ (split /\x0d\x0a/, $fullRequest) {
		if ((!exists $foo{'get'}) && (m/GET (.+?) HTTP/)) { $foo{'get'} = $1;}
		if ((!exists $foo{'post'}) && (m/POST (.+?) HTTP/)) { $foo{'post'} = $1;}
		if ((!exists $foo{'userAgent'}) && (m/User-Agent: (.+?)$/ms)) { $foo{'userAgent'} = $1;}
		if ((!exists $foo{'contentLength'}) && (m/Content-Length: (\d+)$/ms)) { $foo{'contentLength'} = $1;}
		if ((!exists $foo{'host'}) && (m/Host: (.+?)$/)) { $foo{'host'} = $1;}
		if ((!exists $foo{'request'}) && (m/^(GET .+?HTTP.+?)$/)) { $foo{'request'} = $1;}
	}
	$foo{'fullRequest'} = $fullRequest;
	foreach my $key (keys %foo) { trim($foo{$key});} 
	return \%foo;
}
sub responderManager {
	my @responders;
	my $add_responder = sub {
		my $responder = shift;
		push @responders, $responder;
	};
	my $get_responder = sub {
		my $id = shift;
		my @foo = grep {$_->{'id'} eq $id} @responders;
		if (@foo) {
			return $foo[0];
		}
		print "returning nothing in responder manager\n";
		return;
	};
	my $get_responders = sub {
		return @responders;
	};
	return ($add_responder, $get_responder, $get_responders);
}

sub identificationManager {
	my @identifiers;
	my $add_identification = sub {
		my $identification = shift;
		push @identifiers, $identification;
	};
	my $get_identification = sub {
		my $id = shift;
		my (@foo) = grep {$_->{id} eq $id} @identifiers;
		return $foo[0];
	};
	my $get_identifications = sub {
		return @identifiers;
	};
	return ($add_identification, $get_identification, $get_identifications);
}
sub eventManager {
	my @events;
	my $add_event = sub {
		my $data = shift;
		push @events, $data;
	};
	my $rem_event = sub {
		my $id = shift;
		@events = grep { $_->{id} ne $id } @events;
	};
	my $get_event = sub {
		my $id = shift;
		my $foo = (grep {$_->{id} eq $id} @events)[0];
		return $foo;
	};
	my $set_event = sub {
		my $id = shift;
		my $data = shift;
		for (my $i = 0; $i <= $#events; $i++) {
			if ($events[$i]->{id} eq $id) {
				$events[$i] = $data;
			}
		}
	};
	my $get_events = sub {
		my $grepString = shift;
		if (defined $grepString) {
			my @matchingEvents = ();
			foreach my $event (@events) {
				if ($event->{'event'} =~ m/$grepString/) {
					push @matchingEvents, $event;
				}
			}
			return @matchingEvents;
		}
		return @events;
	};
	return ($add_event, $rem_event,$get_event, $set_event, $print_event, $get_events);
};

sub serverManager {
	my @servers;
	my $add_server = sub {
		my %data = @_;
		push @servers, \%data;
	};
	my $rem_server = sub {
		my $id = shift;
		@servers = grep { $_->{id} ne $id } @servers;
	};
	my $get_server = sub {
		my $id = shift;
		my $foo = (grep {$_->{id} eq $id} @servers)[0];
		return $foo;
	};
	my $set_server = sub {
		my $id = shift;
		my $data = shift;
		for (my $i = 0; $i <= $#servers; $i++) {
			if ($servers[$i]->{id} eq $id) {
				$servers[$i] = $data;
			}
		}
	};
	my $get_servers = sub {
		return @servers;
	};
	return ($add_server, $rem_server,$get_server, $set_server, $print_server, $get_servers);
};
sub clientManager {
	my @clients;
	my $add_client = sub {
		my %data = @_;
		push @clients, \%data;
	};
	my $rem_client = sub {
		my $id = shift;
		@clients = grep { $_->{id} ne $id } @clients;
	};
	my $get_client_byHandle = sub {
		my $handle = shift;
		my ($client) = grep { $_->{handle} == $handle } @clients;
		return $client;
	};
	my $get_client = sub {
		my $id = shift;
		my ($client) = grep { $_->{id} eq $id } @clients;
		return $client;
	};
	my $msgClientById = sub {
		my $id = shift;
		my $msg = shift;
		my ($client) = grep { $_->{id} eq $id } @clients;
		my $clientHandle = $client->{handle};
		my $stream = Stream::ReadWrite->new($clientHandle);
		$stream->write($msg);
	};
	my $get_clients = sub {
		return @clients;
	};
	my $broadcast = sub {
		my $msg = shift;
=pod
		foreach my $clientRef (@clients) {
			if ($clientRef->{id} =~ m/search_/) {
				my $client = $clientRef->{handle};
				my $stream = Stream::ReadWrite->new($client);
				$stream->write($msg);
			}
		}
=cut
	};
	return ($add_client, $rem_client, $get_client_byHandle, $get_client, $msgClientById, $get_clients, $broadcast);
};
sub onConnect {
	my $self = shift;
	my $cb = shift;
	my $server = $get_server->($self->{'id'});
	$server->{'onConnect'} = $cb;
	$set_server->($self->{'id'}, $server);
}
sub onDisconnect {
	my $self = shift;
	my $cb = shift;
	my $server = $get_server->($self->{'id'});
	$server->{'onDisconnect'} = $cb;
	$set_server->($self->{'id'}, $server);
}
sub writeToServer { #only for servers
	my $self = shift;
	my $message = shift;
	my $server = $get_server->($self->{'id'});
	my $clientsRef = $server->{'clients'};
	foreach my $key (keys %{$clientsRef}) {
		my $handle = $clientsRef->{$key}{'handle'};
		print $handle $message;
	}	
}
sub writeToClient { #only TO clients.. from anyone .. clients make their response in their own buffer.
		    # and those can be checked by placing those things on the event queue.
	my $self = shift;
	my $id = shift;
	my $message = shift;
	my $client = $get_client->($id);
	my $clientHandle = $client->{'client'};
	$clientHandle->send($message."\x0d\x0a\x0d\x0a");
	$clientHandle->blocking(0);
	my $buffer, my $chars;
	while ($clientHandle->read($chars, 4096)) {
		$buffer .= $chars;
	}
	return $buffer;	
}

sub writeToResponder { 
	my $self = shift;
	my $id = shift;
	my $message = shift;
	my $responder = $get_responder->($id);
	$responder->{'buffer'} = $message;
}
sub writeToResponderGroup {
	my $actor1 = shift;
	my $message = shift;
	my @responders = $get_responders->();
	foreach my $responder (@responders) {
		if ((defined $responder->{'group'}) && ($responder->{'group'} eq $actor1)) {
			$responder->{'buffer'} = $message;
		}
	}
}

sub broadcastAllExcept { # this is only for servers.
	my $self = shift;
	my $data = shift;
#	print "****\nBroadcast ALLEXCEPT\n".Dumper($data)."\n";
	my $handle = $data->{'handle'};
	my $message = shift;	
	my $server = $get_server->($self->{'id'});
	my $clientsRef = $server->{'clients'};
	foreach my $key (keys %{$clientsRef}) {
		my $handle2 = $clientsRef->{$key}{'handle'};
		if ($handle2 != $handle) {
			print $handle2 $message;
		}
	}
	writeToResponderGroup($self->{'id'}, $message);
}
sub broadcastOne { # this is only for servers.
	my $self = shift;
	my $data = shift;
#	print "****\nBroadcast ONE\n".Dumper($data)."\n";
	my $handle = $data->{'handle'};
	my $message = shift;
#	print "message to send is $message\n";
	print $handle $message;
	writeToResponderGroup($self->{'id'}, $message);
}
sub broadcastAll { # this is only for servers.
	my $self = shift;
	my $data = shift;
#	print "****\nBroadcast ALL\n".Dumper($data)."\n";
	my $message = shift;
	my $server = $get_server->($self->{'id'});
	my $clientsRef = $server->{'clients'};
	foreach my $key (keys %{$clientsRef}) {
		my $handle = $clientsRef->{$key}{'handle'};
		print $handle $message;
	}
	writeToResponderGroup($self->{'id'}, $message);
}

sub hashToList {
	my $hashRef = shift;
	my @list = ();
	foreach my $key (keys %{$hashRef}) {
		push @list, $key;
		push @list, $hashRef->{$key};
	}
	return @list;
}
sub parseEventForEntities {
	my $eventRef = shift;
	my @actions = qw(hearsFrom speaksTo);
	my ($actor1, $actor2) = ($eventRef->{'event'} =~ m/(.+?) hearsFrom (.+)/);
#	print "actor1 is $actor1\tactor2 is $actor2\n";
	$add_entity->($actor1);	
	$add_entity->($actor2);	
}
sub addIdentification {
	my $self = shift;
	my %identification = @_;
	$add_identification->(\%identification);
}
sub matchEvent {
	my ($actor1, $actor2, @events) = @_;
	if (scalar @events) {
		print join ", ", @events;
	} else {
		@events = $get_events->();
	}
	foreach my $event (@events) {
		if ($event->{'event'} =~ m/$actor1 hearsFrom $actor2/) {
			return $event;
		}
	}
	return;
}
sub getIdentification {
	my $self = shift;
	my $id = shift;
	return $get_identification->($id);
}
sub lookForEventsAndFire {
	my $data = shift;
	if (exists $data->{'server'}) {
		my $buffer = $data->{'buffer'};
		my $server = $data->{'server'};
		my $handle = $data->{'handle'};
		if (defined $buffer) {
			my ($actor1, $actor2) = ($server->{'id'}, identify($buffer));
			if (defined $actor2) {
				my $possibleEvent = matchEvent($actor1, $actor2);
				if (defined $possibleEvent) {
					print " * Server based event found with $actor1 and $actor2 in event $possibleEvent->{'event'}\n";
					#print "Buffer is $buffer\n";
					$possibleEvent->publish({buffer=>$buffer, handle=>$handle, server=>$server});
				}
			}
		}
	} elsif (exists $data->{'responder'}) { # we are guaranteed that there exists a group key as well 
						# which acts as the actor1 (or server id) since group key basically 
						# "brings" the action to the responder (i.e. inclusive without physically
						# being included (i.e. on a socket connection etc.)
					
						# yet we are only going through responder's subscription list,
						# not a all the global events subscribers' list.
		my $buffer = $data->{'responder'}->{'buffer'};
		my $responder = $data->{'responder'};
		my @events = @{$responder->{'subscriptions'}};
		my ($actor1, $actor2) = ($responder->{'group'}, identify($buffer));
		$data->{'responder'}->{'buffer'} = "";
#		print "responder--> actor1: $actor1\tactor2: $actor2\n";
		if (defined $actor2) {
			my $possibleEvent = matchEvent($actor1, $actor2, @events);
			if (defined $possibleEvent) {
				print " * Responder based event found with $actor1 and $actor2 in event $possibleEvent->{'event'}\n";
				#print "Buffer is $buffer\n";
				$possibleEvent->publish({buffer=>$buffer});				
			}
		}
	}
}
sub identify {
	my $buffer = shift;
	# foreach parsable id in the event rules, we get identification cb 
	# and test the buffer for that id. if true we return identification->{id}
	my @identifiers = $get_identifications->();
	my @matches = ();
	foreach my $identifier (@identifiers) {
		if (!exists $identifier->{'priority'}) { $identifier->{'priority'} = 0; }
		if ($identifier->{'test'}->($buffer)) {
			push @matches, {id=>$identifier->{'id'}, priority=>$identifier->{'priority'}};
		}
	}
	@matches = sort {$b->{'priority'} <=> $a->{'priority'}} @matches;
	my $match = shift @matches;
	return $match->{'id'};
}
sub start {
	my @servers = $get_servers->();	
#       unless say we include an announceAs key, which would indicate that
#       our server its connecting to is "one of us".

	my @clients = $get_clients->();	
	foreach my $client (@clients) {
		push @eventQueue, sub {
			if ($client->{'client'}->connected) {
				print "** Looks good like ".$client->{'id'}. " is connected to its server\n";
			} elsif ($client->{'reconnect'} == 1) {
				print "** Looks good like ".$client->{'id'}. " has disconnected from its server\n";	
				print "** Going to reconnect to ".$client->{'peerAddr'}.":".$client->{'peerPort'}."\n";
				$client->{'client'} = IO::Socket::INET->new(Proto => "tcp", 
				PeerAddr => $client->{'peerAddr'}, 
				PeerPort => $client->{'peerPort'},
				ReuseAddr => 1) || cluck("RNode Error: $!\n");
			}
		}
#		my $clientStream = Stream::ReadWrite->new($client->{'client'});
#		print Dumper($client);
#		my %out = (id=>$client->{'announceAs'});
#		my $jsonText = encode_json(\%out);
#		print "RNode: Jsontext is $jsonText\n";
#		$clientStream->write(encode_json(\%out));
	}
	my @responders = $get_responders->();
	foreach my $responder (@responders) {
#		if (defined $responder->{'group'}) {
			push @eventQueue, sub {
				if ($responder->{'buffer'} ne "") {
					push @jobQueue, sub { lookForEventsAndFire({buffer=>$responder->{'buffer'}, responder=>$responder}); }
				}
			}
#		}
	}
	if (my $pid = fork) {
		close PARENT; # we don't need the parent FH open in the parent process.		
			      # we only need the parent FH open in the child process. 
			      # so we close it here to be kind to the child process.
		while(1) {
			print "PARENT : Report on servers...\n";
			print Dumper ($servers[0]);
			print "PARENT : waiting for my child..\n";
			my $line = <CHILD>;
			print "PARENT : Oh is that my baby?\n";
			print "PARENT : Recieved word from my child -->$line<--\n";
			foreach my $server (@servers) {
				print Dumper($server) 
			}
			print "hit enter..\n";
			<STDIN>;
			my $ref = decode_json($line);
			my $buffer = $ref->{'buffer'};
			my $server = $ref->{'server'};
			my $handle = $ref->{'handle'};
			push @jobQueue, sub { lookForEventsAndFire({buffer=>$buffer, server=>$server, handle=>$handle}); };
			#close CHILD;
			while (my $job = shift @jobQueue) {
				print "Doing a job\n";
				$job->();
			}
			for (my $i=0; $i <= $#eventQueue; $i++) {
				$eventQueue[$i]->();
			}
	
		}
	} else {
		close CHILD; # we don't need the child FH open the same reasoning as for closing hte parent
		while(1) {
			foreach my $server (@servers) {
			my @ready = $server->{'readers'}->can_read(2); 
#			print "Ready is size ".scalar @ready."\n";
			for my $handle (@ready) {
#				print "looping inside ready\n";
				my ($response, $buffer, $chars);
				if ($handle eq $server->{'server'}) {
#					print "listen sock activity on ".$server->{'id'}."\n";
					my $new = $server->{'server'}->accept;
					$server->{'clients'}{$new}{'handle'} = $new;
					$server->{'readers'}->add($new);
					if (exists $server->{'onConnect'}) {
						$server->{'onConnect'}->({handle=>$new, server=>$server});
					}
				} elsif (my $client = $server->{'clients'}{$handle}{'handle'}) {
#					print "client activity on ".$server->{'id'}."\n";
					$client->blocking(0);
					while ($client->read($chars, 2048)) {
						$buffer .= $chars;
					}
#					print "Got buffer : -->$buffer<--\n";
					my $size = length $chars;
					if ((!$size) || ($size == 0)) { 
						print "closing a client that was connected to ".$server->{'id'}."\n";
						if (exists $server->{'onDisconnect'}) {
							$server->{'onDisconnect'}->({handle=>$client, server=>$server});
						}
						$server->{'readers'}->remove($handle);
						delete $server->{'clients'}{$handle};
						close $handle;
						last;
					} else {
						my $out= {buffer=>$buffer};
						my $jsonText = encode_json($out);
#
#						my $out= {buffer=>$buffer, server=>$server, handle=>$handle};

#						print "CHILD : Preparing buffer -->$buffer<-- for sending to mom and dad\n";
#						my $jsonText = encode_json(\%out);
						print "CHILD: Sending parent $jsonText\n";
						print "CHILD: SUmmary report of server ..\n";
						print Dumper($server);
						print PARENT $jsonText."\x0d\x0a";
					}
				}
			}
			}
		}
	}		
}
sub getEvent {
	my $self = shift;
	my $id = shift;
	return $get_event->($id);
}
sub event {
	my $class = shift;
	my %eventData = @_;
	verify(\%eventData, 'event', qw(event id));
	parseEventForEntities(\%eventData);
	$add_event->(\%eventData);
	return bless \%eventData, $class;
}
sub subscribe { # clients/servers/responders defined by new of this package can subscribe
	my $self = shift;
	my $eventId = shift;
	my $notificationMethod = shift;
	if (!defined $notificationMethod) {
		$notificationMethod = sub {
			my %args = @_;
			if (!defined \%args) { print "arg list goes here\n"; }
			else {
				print "Args: ";
				foreach my $key (keys %args) {
					print "$key : $args{$key}\t";
				}
				print "\n";
			}
			print "This is ".$self->{id}."'s default notification method. \n"};
	}	
	print "subscribe: ".$self->{'id'}." wants to subscribe to $eventId\n";
	my $event = $get_event->($eventId) || cluck ("RNode: there is no event with eventId: $eventId\n");
	push @{$event->{'subscribers'}}, {id=>$self->{'id'}, notificationMethod=>$notificationMethod}; # add self to event's subscribers list
	push @{$self->{'subscriptions'}}, $event;  
	# add event to self's list of subscriptions.
	# print Dumper($self);
}
sub bridge { # bridge a client into a server by passing the client into the server's readers list.
	my $self = shift;
	my $clientId = shift;
	my $serverId = shift;
	my $readers = $get_server->($serverId);
	my $client = $get_client->($clientId);
	$readers->add($client);
}
sub notify {
	my $self = shift;
	my $message = shift;
	if ((exists $self->{'type'}) && ($self->{'type'} eq "server")) {
		my $server = $get_server->($self->{'id'});
		my $clientsRef = $server->{'clients'};
		foreach my $key (keys %{$clientsRef}) {
			my $handle = $clientsRef->{$key}{'handle'};
			print $handle $message;
		}
	}
}
sub publish { # events are published. i.e. event objects do the publishing.
	my $self = shift;
	my $data = shift;
	if (!exists $data->{'msg'}) {
		$data->{'msg'} = "DEFAULT MESSAGE FOR NOTIFICATION METHOD\n"; 
	}
	if (!exists $data->{'handle'}) { 
		$data->{'handle'} = undef; 
	}
	if (!exists $data->{'server'}) { 
		$data->{'server'} =  undef; 
	}
	my $event = $get_event->($self->{id});
	my @subscribers = @{$event->{'subscribers'}};
	foreach my $subscriber (@subscribers) {
		$subscriber->{'notificationMethod'}->($data);
	}
}
sub verify {
	my $hash = shift;
	my $type = shift;
	my @params = @_;
	if (exists($hash->{$type})) {
		foreach my $param (@params) {
			cluck("RNode Error: param $param not specified!\n") unless exists $hash->{$param};
		}
	}
}
sub config {
	my $self = shift;
	my %data = @_;
	$self->{data} = \%data;
}
sub new {
	my $class = shift;
	my %config = @_;
	verify(\%config,'server', qw(type port id));
	verify(\%config,'client', qw(type peerPort peerAddr id));
	verify(\%config,'responder', qw(type id));
	switch ($config{'type'}) {
		case 'server' {
			my $server = new IO::Socket::INET(
				Proto => 'tcp', 
				Listen => SOMAXCONN, 
				LocalPort => $config{'port'}, 
				Reuse => 1) || cluck("RNode Error: $!\n"); 
			my $readers = IO::Select->new(); $readers->add($server);
			$add_server->(id=>$config{'id'}, server=>$server, readers=>$readers, clients=>());
		}
		case 'client' {
			my $client = IO::Socket::INET->new(
				Proto => "tcp", 
				PeerAddr => $config{'peerAddr'}, 
				PeerPort => $config{'peerPort'},
				ReuseAddr => 1) || cluck("RNode Error: $!\n");
			$add_client->(peerPort=>$config{'peerPort'}, peerAddr=>$config{'peerAddr'},  # these two are
				 #included just so i can easily reconnect without having to look at the self object for these
				 #values.
			id=>$config{'id'}, client=>$client, announceAs=>$config{'announceAs'}, reconnect=>$config{'reconnect'});
		}
		case 'responder' {
			my $responder = {id=>$config{'id'}, buffer=>"", group=>$config{'group'}};
			$add_responder->($responder);
		}
		else {}
	}
	return bless \%config, $class;
}
1
