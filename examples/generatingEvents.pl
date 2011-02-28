use common::sense;
use lib "$ENV{HOME}/RNode";
use RNode;
use Text::Trim;
use Data::Dumper;

# define servers/clients/responders
my $todd = RNode->new(type=>'responder', id=>'todd');
my $tedd = RNode->new(type=>'responder', id=>'tedd');

my $secretary = RNode->new(type=>'responder', id=>'secretary');
RNode->event(id=>'teddSpeaks', event=>'todd hearsFrom tedd');
RNode->event(id=>'toddSpeaks', event=>'tedd hearsFrom todd');

RNode->addIdentification(id=>'todd', test=>sub { 
	my $_ = shift;
	return (m/todd: /);
});
RNode->addIdentification(id=>'tedd', test=>sub { 
	my $_ = shift;
	return (m/^tedd: /);
});
# add subscribers
$todd->subscribe("teddSpeaks", sub {
	my $data = shift;
	my $buffer = $data->{'buffer'};
	my ($number) = ($buffer =~ /tedd: (\d+)/);
	if (defined $number) {
		print "Tedd has said a number, and that number is $number\n";
	}
	$number = $number + 1;
	$todd->writeToResponder("tedd", "todd: $number");
	sleep(1);
});
$tedd->subscribe("toddSpeaks", sub {
	my $data = shift;
	my $buffer = $data->{'buffer'};
	my ($number) = ($buffer =~ /todd: (\d+)/);
	if (defined $number) {
		print "Todd has said a number, and that number is $number\n";
	}
	$number = $number + 1;
	$tedd->writeToResponder("todd", "tedd: $number");
	sleep(1);
});
$secretary->subscribe("toddSpeaks", sub {
	print "The secretary has noticed that Todd has spoken\n";
});
$secretary->subscribe("teddSpeaks", sub {
	print "The secretary has noticed that Tedd has spoken\n";
});

$todd->writeToResponder("tedd", "todd: 1");

# start
RNode->start;
