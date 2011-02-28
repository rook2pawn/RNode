use common::sense;
use lib "$ENV{HOME}/RNode";
use RNode_threaded;
use Data::Dumper;
########################
# RNode_threaded - Tunnel
########################

# define servers/clients/responders
my $tunnel = RNode->new(type=>'server', port=>5150, id=>'tunnel');
# define events;
RNode->event(id=>'noise', event=> 'tunnel hearsFrom anyone');

# define identifiers
RNode->addIdentification(id=>'anyone', test=>sub { 
	return 1;
});
# add subscribers
$tunnel->subscribe('noise', sub {
	my $data = shift;
	print "NOISE WAS HEARD!!!\n";
	print Dumper($data);
});
# start
RNode->start;
