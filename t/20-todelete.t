{
	package Test;


	sub new {
		my $self = bless {}, ref $_[0] || $_[0];
		$self->{data} = undef;
		$self->{next} = undef;
		$self->{prev} = undef;
		return $self;
	}

	sub bulk_add {
		my ($self) = shift;
		my $prev;
		for (@_) {
			my $new = $self->new();
			$new->{data} = $_;
			$new->{prev} = $prev ||= $self;
			$prev->{next} = $new;
			$prev = $new;
		}
		return $prev;
	}

	sub length {
		my ($self) = @_;

		while ($self->{prev}) {
			$self = $self->{prev};
		}
		my $c = 0;
		while ($self->{next}) {
			$self = $self->{next};
			$c++;	
		}
		return $c;
	}
}


my $t = Test->new;

$t->bulk_add(1..1000000);

use Data::Dumper;
warn Dumper $t->length;

