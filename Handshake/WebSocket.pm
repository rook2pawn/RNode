package Handshake::WebSocket;
use Digest::MD5;
use Text::Trim;

sub extract_number {
	$_ = shift;
	my $digits = join('', /(\d)/g);
	my $spaces = (s/\s//g);
	return int(int($digits) / int($spaces));
}
sub new {
	my $class = shift;
	return bless {}, $class;
}
sub findChecksum {
	my $class = shift;
	my ($key1, $key2, $randTokens) = @_;
	my $num1 = pack 'N'=>extract_number($key1);
	my $num2 = pack 'N'=>extract_number($key2);
	my $md5 = Digest::MD5::md5($num1 . $num2 . $randTokens);
	return $md5;
}
sub parse {
	my $self = shift;
	my $buffer = shift;
	trim($buffer);
	my $key1 = ($buffer =~ /Sec-WebSocket-Key1: (.+)$/m)[0];
	my $key2 = ($buffer =~ /Sec-WebSocket-Key2: (.+)$/m)[0];
	my $randTokens = ($buffer =~ /\n^(.{8,16}?)$/m)[0];
	trim ($key1, $key2, $randTokens);
	my ($host, $port)= ($buffer =~ /Host: (.+?):(\d+)/ms);
	if (!defined $port) {
		$port = "";
	}
	my ($resourceName) = ($buffer =~ /GET (.+?) HTTP/);
	my ($origin) = ($buffer =~ /Origin: (.+?)$/m);
	trim($origin);
	my $location = "ws://$host:$port$resourceName";
	my $shake = "HTTP/1.1 101 WebSocket Protocol Handshake\x0d\x0aUpgrade: WebSocket\x0d\x0AConnection: Upgrade\x0d\x0aSec-WebSocket-Origin: $origin\x0d\x0aSec-WebSocket-Location: $location";
	my $checksum = findChecksum($self, $key1, $key2, $randTokens);
	$shake .= "\x0d\x0a\x0d\x0a$checksum";
=pod
	$randTokens = unpack "H*",$randTokens;
	$randTokens =~ s/(\w\w)/$1:/g;
	chop $randTokens;
	my @foo = split /:/, $randTokens;
	print join ", ", @foo;
	@foo = map {pack "H*", $_} @foo;
	$randTokens = join "", @foo;
=cut
	return {checksum=>$checksum, host=>$host, port=>$port, resourceName=>$resourceName, origin=>$origin, key1=>$key1, key2=>$key2, randTokens=>$randTokens, location=>$location, handshakeResponse=>$shake};
}
1
