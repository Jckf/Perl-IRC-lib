#!/usr/bin/perl

use strict;
use warnings;

use Time::HiRes 'sleep';

use Devel::SimpleTrace;

use IRC;

my $sleep_after = 10000;

print 'Initializing...', "\n";

my $irc = IRC->new();

$irc->debug(1);

$irc->bind('ping', sub {
	my ($self, $data) = @_;

	$self->pong(@{$data->{'arguments'}});
});

$irc->bind('001', sub {
	my ($self) = @_;

	$self->join('#gamesdonequick');
});

while (defined $irc) {
	print 'Connecting...', "\n";

	$irc->connect('irc.twitch.tv', 6667);

	print 'Registering...', "\n";

	$irc->cap('REQ', 'twitch.tv/commands twitch.tv/membership twitch.tv/tags');
	$irc->pass('oauth:abc123abc123abc123abc123abc123abc123');
	$irc->nick('Cheeky_Bot');

	print 'Running...', "\n";

	my $idle_counter = 0;
	while (sleep 0.01) {
		my $status = $irc->tick();

		last unless $status;

		$idle_counter = 0 if $status == 2;

		if ($idle_counter < $sleep_after) {
			$idle_counter++ if $status == 1;
		} else {
			sleep 0.25;
		}
	}

	print 'Disconnected. Waiting 5 seconds...', "\n";

	sleep 5;
}
