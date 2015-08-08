#!/dev/null

package IRCv3;

use strict;
use warnings;

use Devel::SimpleTrace;

sub new {
	my ($class, %opts) = @_;

	my $self = {};

	bless($self, $class);
}

sub decode {
	my ($self, $message) = @_;

	my %tags;
	if (substr($message, 0, 1) eq '@') {
		my $tags_string = '';
		($tags_string, $message) = split(/ +/, substr($message, 1), 2);

		while (length $tags_string) {
			my $tag_string = '';
			($tag_string, $tags_string) = split(';', $tags_string, 2);

			my ($key, $val) = split('=', $tag_string, 2);
			$tags{$key} = $val;
		}
	}

	my $prefix;
	if (substr($message, 0, 1) eq ':') {
		($prefix, $message) = split(/ +/, substr($message, 1), 2);
	}

	my ($command, $args_string) = split(/ +/, $message, 2);

	my @args;
	if (defined $args_string) {
		while (length $args_string) {
			if (substr($args_string, 0, 1) eq ':') {
				push(@args, substr($args_string, 1));
				last;
			}

			my $arg;
			($arg, $args_string) = split(/ +/, $args_string, 2);

			push(@args, $arg);
		}
	}

	return {
		'tags' => \%tags,
		'prefix' => $prefix,
		'command' => $command,
		'arguments' => \@args
	};
}

sub encode {
	my ($self, %data) = @_;

	my @components;

	if (defined $data{'tags'}) {
		my @tags;
		foreach my $key (keys %{$data{'tags'}}) {
			push(@tags, $key . (defined $data{'tags'}->{$key} ? '=' . $data{'tags'}->{$key} : ''));
		}
		push(@components, '@' . join(';', @tags));
	}

	if (defined $data{'prefix'}) {
		push(@components, ':' . $data{'prefix'});
	}

	push(@components, uc $data{'command'});

	if (defined $data{'arguments'}) {
		foreach my $argument (@{$data{'arguments'}}) {
			push(@components, ($argument =~ / / ? ':' : '') . $argument);
		}
	}

	return join(' ', @components);
}

1;
