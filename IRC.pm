#!/dev/null

package IRC;

use strict;
use warnings;

use Devel::SimpleTrace;
#use Data::Dumper;

use Try::Tiny;

use Scalar::Util 'reftype';

use IO::Select;
use IO::Socket::INET;

use IRCv3;

our $AUTOLOAD;

sub new {
	my ($class, %args) = @_;

	my $self = {
		'debug' => 0,
		'handlers' => {},
		'parser' => IRCv3->new(),
		'select' => undef,
		'socket' => undef,
		'closed' => 1
	};

	$self->{$_} = $args{$_} for keys %args;

	bless($self, $class);
}

sub bind {
	my ($self, $event, $handler) = @_;

	$self->{'handlers'}->{uc $event} = () unless defined $self->{'handlers'}->{uc $event};

	push(@{$self->{'handlers'}->{uc $event}}, $handler);
}

sub trigger {
	my ($self, $event, $data) = @_;

	return unless defined $self->{'handlers'}->{uc $event};

	foreach my $handler (@{$self->{'handlers'}->{uc $event}}) {
		try {
			&{$handler}($self, $data);
		} catch {
			warn 'Error during event trigger: ' . $_;
		}
	}
}

sub connect {
	my ($self, $server, $port) = @_;

	return unless $self->{'closed'};

	$self->{'socket'} = IO::Socket::INET->new(
		'Proto' => 'tcp',
		'PeerAddr' => $server,
		'PeerPort' => $port
	) or warn $!;

	$self->{'closed'} = !defined $self->{'socket'};

	return if $self->{'closed'};

	$self->{'select'} = IO::Select->new($self->{'socket'});
}

sub disconnect {
	my ($self) = @_;

	$self->{'socket'}->close();
	$self->{'closed'} = 1;
}

sub write {
	my ($self, $data) = @_;

	return if $self->{'closed'};

	$data =~ s/[\r\n].*$//;

	print '< ' . $data . "\n" if $self->{'debug'};

	syswrite($self->{'socket'}, $data . "\r\n");
}

sub read {
	my ($self) = @_;

	return if $self->{'closed'};

	return unless $self->{'select'}->can_read(0);

	my ($data, $buffer, $line) = ('', '', 0);

	if (defined $self->{'ibuffer'}) {
		$data = $self->{'ibuffer'};
		$self->{'ibuffer'} = undef;
	}

	while (sysread($self->{'socket'}, $buffer, 1)) {
		$data .= $buffer;

		if ($data =~ /[\r\n]+$/) {
			$line = 1;
			last;
		}
	}

	return $self->disconnect() unless length $data;

	unless ($line) {
		$self->{'ibuffer'} = $buffer;
		return;
	}

	$data =~ s/[\r\n]//g;

	return unless length $data;

	print '> ' . $data . "\n" if $self->{'debug'};

	return $self->{'parser'}->decode($data);
}

sub tick {
	my ($self) = @_;

	return 0 if $self->{'closed'} || $self->{'select'}->has_exception(0);

	my $data = $self->read();

	return 1 unless defined $data;

	$self->trigger($data->{'command'}, $data);

	return 2;
}

sub debug {
	my ($self, $state) = @_;

	$self->{'debug'} = $state;
}

sub AUTOLOAD {
	my ($self) = @_;

	my %data;
	if (ref $_[1] eq 'HASH') {
		%data = %{$_[1]};
	} else {
		shift; # Ugh.
		$data{'arguments'} = \@_;
	}

	$data{'command'} = substr(uc $AUTOLOAD, rindex($AUTOLOAD, ':') + 1);

	$self->write($self->{'parser'}->encode(%data));
}

sub DESTROY {
	my ($self) = @_;

	$self->quit();
}

1;
