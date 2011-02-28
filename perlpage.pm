package perlpage;
use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( examineRequest );

use common::sense;
use Data::Dumper;
use Text::Trim;
use File::ChangeNotify;

=pod

Author: David Wee © 2011
package: perlpage::main
file: perlpage.pm
Desc: main assembly class to be used in conjunction with controller

=cut
my $rootDir = $ENV{HOME}."/mtgBrowse";
print "perlpage.pm: ROOT DIR is $rootDir\n";
sub decodeURIComponent {
	my $arg = shift;
	$arg =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
	return $arg;
}
sub encodeURIComponent {
	return join '', map { sprintf "%%%X", ord } split //, shift;
}
sub examineRequest {
	my %foo = ();
	foreach $_ (split /\x0d\x0a/, $_= shift) {
		if ((!exists $foo{'get'}) && (m/GET (.+?) HTTP/)) { $foo{'get'} = $1;}
		if ((!exists $foo{'post'}) && (m/POST (.+?) HTTP/)) { $foo{'post'} = $1;}
		if ((!exists $foo{'userAgent'}) && (m/User-Agent: (.+?)$/ms)) { $foo{'userAgent'} = $1;}
		if ((!exists $foo{'contentLength'}) && (m/Content-Length: (\d+)$/ms)) { $foo{'contentLength'} = $1;}
		if ((!exists $foo{'host'}) && (m/Host: (.+?)$/)) { $foo{'host'} = $1;}
	}
	foreach my $key (keys %foo) { trim($foo{$key});} 
	$foo{'execute'} = sub { print "Executing of the executioner style.\n" };
	return \%foo;
}
sub getValue {
	my $ref = shift;
	my $key = shift;
	if (exists $ref->{$key}) {
		return $ref->{$key};
	}
}


sub new {
	my $class = shift;
	return bless {request=>undef, conf=>undef}, $class;
}
sub http_header {
	my $self  = shift;
	my $http_header = "HTTP/1.1 200 OK\x0d\x0aContent-type: text/html\x0d\x0a\x0d\x0a";	
	return $http_header;
}
sub setRequest {
	my $self  = shift;
	my $request = shift;
	$self ->{'request'} = $request;
}
sub header {
	my $self = shift;
	my $out = $self->get('header');
	return $out;
}
sub footer {
	my $self = shift;
	my $out = $self->get('footer');
	return $out;
}
sub truncateRequest {
	my $self = shift;
	my $truncatedRequest = ($self->{'request'} =~ /\/energy\/?(.+?)$/)[0];
	if ((!defined $truncatedRequest) || ($truncatedRequest eq "")) {
		$truncatedRequest = "default";
	}
	return $truncatedRequest;
}
sub getFile {
	my $file = shift;
	my $contents;
	if (-e $file) {
		open my $fh, $file;
		binmode $fh;
		{local $/; $contents = <$fh>}
		close $fh;
	}
	return $contents;	
}
sub loadConf {
	my $self = shift;
	my $conf = getFile($rootDir."/conf/conf.txt");
	my @lines = split /\n/, $conf;
	foreach my $line (@lines) {
		my ($key, $value) = ($line=~ /(.+?)\t(.+?)$/);
		$self->{'conf'}{$key} = trim $value;
	}
}
sub get {
	my $self = shift;
	my $entity = shift;
	my $file = $self->{'conf'}{$entity};
	my $fileContents = $self->{'conf'}{$entity}{'contents'};

	## lazy load
	my $returnContents;
	if (defined $fileContents) {
		$returnContents = $fileContents;
	} else { 
		$returnContents = getFile($rootDir."/".$file);
		$self->{'conf'}{$entity}{'contents'} = $returnContents;
	}
	return $returnContents;
}
sub notify {
	my $self = shift;
	my $ref = shift;
	if ((exists $ref->{'source'}) && ($ref->{'source'} eq "watcher") && ($ref->{'type'} eq "modify")) {
		$ref->{'path'} =~ s/^\.\.\///;
		my %hash = %{$self->{'conf'}};
		foreach my $key (keys %hash) {
			if ($hash{$key} eq $ref->{'path'}) {
				print "Reloading ".$ref->{'path'}."\n";
				$self->{'conf'}{$key}{'contents'} = getFile($rootDir."/".$ref->{'path'});
			}
		}		
	}
}
sub navigation {
	my $self  = shift;
	my $out = $self->get('navBar');
	return $out;
}
sub content {
	my $self  = shift;
	my $prepend = shift;
	my $request = $self->truncateRequest;
	my $content;
	if (exists $self->{'conf'}{$request}) {
		$content = $self->get($request);
	}
	if (defined $prepend) {
		$content = $prepend.$content;
	}
	return "<div class='content'>".$content."</div>";
}
1
