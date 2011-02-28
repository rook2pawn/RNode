package Stream::ReadWrite; 
use common::sense;
use Text::Trim;

=pod

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

Copyright 2010 David Wee / James Halliday

package: Stream::ReadWrite; 
file: stream.pm
Author: David Wee / James Halliday

=cut

sub new {
	my $class = shift;
	my $stringOrFH = shift;
	if (ref($stringOrFH) eq "") {
		return bless {string=>$stringOrFH}, $class;
		
	} else {
		binmode $stringOrFH, ":raw";
		return bless {FH => $stringOrFH}, $class;
	}
}	
sub read {
	my $self = shift;
	if (exists $self->{'string'}) {
		my $string = $self->{'string'};
		print "STRING IS $string\n";
		my ($length, $message) =  ($string =~ /^(\d+)\x0d\x0a(.+)/ms);
		if (!defined $length) {
			return -1;
		}
		trim($message);
		print "stream.pm: Length is $length\n";
		return $message;

	} else {
		my $fh = $self->{FH};
		my $length = <$fh>;
		if (!defined $length) {
			return -1;
		}
		trim($length);
		print "stream.pm: Length is $length\n";
		read $fh,my ($message),$length;
		return $message;
	}
}
sub write {
	my $self = shift;
	my $message = shift;
	print "stream.pm writing message: -->$message<--\n";
	my $fh = $self->{FH};
	print $fh length($message)."\x0D\x0A".$message;
}
1
