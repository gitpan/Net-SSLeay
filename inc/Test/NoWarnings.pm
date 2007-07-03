#line 1
use strict;
use warnings;

package Test::NoWarnings;

use Test::Builder;

use Test::NoWarnings::Warning;

my $Test = Test::Builder->new;
my $PID = $$;

use Carp;

use vars qw(
	$VERSION @EXPORT_OK @ISA $do_end_test
);

$VERSION = '0.083';

require Exporter;
@ISA = qw( Exporter );

@EXPORT_OK = qw(
	clear_warnings had_no_warnings warnings
);

my @warnings;

$SIG{__WARN__} = make_catcher(\@warnings);

$do_end_test = 0;

sub import
{
	$do_end_test = 1;

	goto &Exporter::import;
}

# the END block must be after the "use Test::Builder" to make sure it runs
# before Test::Builder's end block
# only run the test if there have been other tests
END {
	had_no_warnings() if $do_end_test;
}

sub make_warning
{
	local $SIG{__WARN__};

	my $msg = shift;

	my $warning = Test::NoWarnings::Warning->new;

	$warning->setMessage($msg);
	$warning->fillTest($Test);
	$warning->fillTrace(__PACKAGE__);

	$Carp::Internal{__PACKAGE__.""}++;
	local $Carp::CarpLevel = $Carp::CarpLevel + 1;
	$warning->fillCarp($msg);
	$Carp::Internal{__PACKAGE__.""}--;

	return $warning;
}

sub make_catcher
{
	# this make a subroutine which can be used in $SIG{__WARN__}
	# it takes one argument, a ref to an array
	# it will push the details of the warning onto the end of the array.

	my $array = shift;

	return sub {
		my $msg = shift;

		$Carp::Internal{__PACKAGE__.""}++;
		push(@$array, make_warning($msg));
		$Carp::Internal{__PACKAGE__.""}--;

		return $msg;
	};
}

sub had_no_warnings
{
	return 0 if $$ != $PID;

	local $SIG{__WARN__};
	my $name = shift || "no warnings";

	my $ok;
	my $diag;
	if (@warnings == 0)
	{
		$ok = 1;
	}
	else
	{
		$ok = 0;
		$diag = "There were ".@warnings." warning(s)\n";
		$diag .= join("----------\n", map { $_->toString } @warnings);
	}

	$Test->ok($ok, $name) || $Test->diag($diag);

	return $ok;
}

sub clear_warnings
{
	local $SIG{__WARN__};
	@warnings = ();
}

sub warnings
{
	local $SIG{__WARN__};
	return @warnings;
}

sub builder
{
	local $SIG{__WARN__};
	if (@_)
	{
		$Test = shift;
	}
	return $Test;
}

1;

__END__

#line 310
