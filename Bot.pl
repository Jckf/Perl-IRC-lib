#!/usr/bin/perl

# Load debug libs.
use strict;
use warnings;

# Load more precise sleep().
use Time::HiRes qw(sleep);

# Load IRC lib.
use IRC;

# Create our IRC object.
my $irc = IRC->new(
	'server'	=> 'irc.minecraft.no',
	'username'	=> 'herp',
	'realname'	=> 'Herp Derp',
	'nickname'	=> 'Herp'
);

# Bind to the 001 numeric (001 means server registration is complete and that we can start joining channels).
$irc->bind('001',sub {
	# Join a channel.
	$irc->join('#lounge');
});

# Bind to the PRIVMSG command (someone talking).
$irc->bind('privmsg',sub {
	# Get the raw data.
	my ($input) = @_;

	# Split it up into something we can use.
	my ($user,undef,$target,$message) = split(/\s:?/,substr($input,1),4);
	my ($user_nick,$user_username,$user_address) = split(/[\!\@]/,$user,3);

	# Check if this is a PM (target is ourself).
	if ($target eq $irc->{'nickname'}) {
		# It is. Set target to be the sender.
		$target = $user_nick;
	}

	# Do something with the input here.
	print $target . ' <' . $user_nick . '> ' . $message . "\n";
});

# Loop while our IRC object exists.
while ($irc) {
	# Connect to the server.
	$irc->connect();

	# Maintain the connection.
	while ($irc->tick()) {
		# Sleep for a little while so the bot won't go crazy.
		sleep 0.01;
	}

	# We got disconnected. Sleep for 5 seconds before trying to reconnect.
	sleep 5;
}
