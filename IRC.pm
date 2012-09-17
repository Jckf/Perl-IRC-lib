package IRC;

use strict;
use warnings;
use Encode;
use IO::Select;
use IO::Socket::INET;

use constant {
	SELF => 0,
	EVENT => 1,
	SUB => 2,
	ARGS => 2
};

our $AUTOLOAD;

sub new {
	my ($class,%args) = @_;

	my $self = {
		'server'	=> 'irc.fllabs.org',
		'port'		=> 6667,
		'username'	=> 'user',
		'realname'	=> 'User',
		'nickname'	=> 'User',
		'handlers'	=> {}
	};

	$self->{$_} = $args{$_} for keys %args;
	%{$self->{'args'}} = %args;

	bless($self,$class)
}

sub bind { $_[SELF]->{'handlers'}{uc $_[EVENT]} = $_[SUB]; }

sub trigger { defined($_[SELF]->{'handlers'}{uc $_[EVENT]}) ? &{$_[SELF]->{'handlers'}{uc $_[EVENT]}}($_[ARGS]) : 0; }

sub connect {
	my ($self) = @_;

	$self->{'socket'} = IO::Socket::INET->new($self->{'server'} . ':' . $self->{'port'});
	$self->{'select'} = IO::Select->new($self->{'socket'});

	$self->user($self->{'username'},'*','*',$self->{'realname'});
	$self->nick($self->{'nickname'});

	return $self->{'socket'};
}

sub write {
	my ($self,@args) = @_;

	my @data;
	push(@data,($_ =~ / / ? ':' : '') . $_) for (@args);

	return syswrite($self->{'socket'},encode('utf8',join(' ',@data) . "\n"));
}

sub tick {
	my ($self) = @_;

	if ($self->{'select'}->can_read(0)) {
		my ($input,$buffer) = ('','');
		while ($input !~ /\n$/) {
			sysread($self->{'socket'},$buffer,1) or last;
			last if !length $buffer;
			$input .= $buffer;
		}
		$input =~ s/[\r\n]//g;
		return 0 if !$input;

		if (substr($input,0,1) ne ':') {
			my @split = split(/ /,$input,2);

			if ($split[0] eq 'PING') {
				$self->pong($split[1]);
			} elsif ($split[0] eq 'ERROR') {
				return 0;
			}

			$self->trigger($split[0],$input);
		} else {
			my @split = split(/ /,$input,3);

			if ($split[1] eq '433') {
				$self->nick($self->{'nickname'} . int(rand(10)));
			} elsif ($split[1] eq 'NICK' && (split(/!/,substr($split[0],1),2))[0] eq $self->{'nickname'}) {
				$self->{'nickname'} = $split[2];
			}

			$self->trigger($split[1],$input);
		}
	}

	return 1;
}

sub AUTOLOAD {
	my ($self,@args) = @_;

	my $command = uc $AUTOLOAD;
	$command =~ s/.*://;

	$self->write($command,@args);
}

sub DESTROY { $_[0]->quit('IRC object destroyed.') }

1;
