#line 1
#
# $Id: Compare.pm 22 2007-04-01 15:03:22Z dave $
#

#line 177

package Array::Compare;

use strict;
use vars qw($VERSION $AUTOLOAD);

use Carp;

$VERSION = 1.14;

my %_defaults = (Sep => '^G',
		 WhiteSpace => 1,
                 Case => 1,
		 Skip => {},
		 DefFull => 0);

#line 236

sub new {
  my $class = shift;

  my $self = {%_defaults, @_};

  bless $self, $class;

  return $self;
}

#
# Utility function to check the arguments to any of the comparison
# function. Ensures that there are two arguments and that they are
# both arrays.
#
sub _check_args {
  my $self = shift;
  croak('Must compare two arrays.') unless @_ == 2;
  croak('Argument 1 is not an array') unless ref($_[0]) eq 'ARRAY';
  croak('Argument 2 is not an array') unless ref($_[1]) eq 'ARRAY';

  return;
}

#line 267

sub compare_len {
  my $self = shift;

  $self->_check_args(@_);

  return @{$_[0]} == @{$_[1]};
}

#line 287

sub compare {
  my $self = shift;

  if ($self->DefFull) {
    return $self->full_compare(@_);
  } else {
    return $self->simple_compare(@_);
  }
}

#line 309

sub simple_compare {
  my $self = shift;

  $self->_check_args(@_);

  my ($row1, $row2) = @_;

  # No point in continuing if the number of elements is different.
  return unless $self->compare_len(@_);

  # @check contains the indexes into the two arrays, i.e. the numbers
  # from 0 to one less than the number of elements.
  my @check = 0 .. $#$row1;

  my ($pkg, $caller) = (caller(1))[0, 3];
  my $perm = $caller eq __PACKAGE__ . "::perm";

  # Filter @check so it only contains indexes that should be compared.
  # N.B. Makes no sense to do this if we are called from 'perm'.
  unless ($perm) {
    @check = grep {!(exists $self->Skip->{$_}
		     && $self->Skip->{$_}) } @check
		       if keys %{$self->Skip};
  }

  # Build two strings by taking array slices containing only the columns
  # that we shouldn't skip and joining those array slices using the Sep
  # character. Hopefully we can then just do a string comparison.
  # Note: this makes the function liable to errors if your arrays
  # contain the separator character.
  my $str1 = join($self->Sep, @{$row1}[@check]);
  my $str2 = join($self->Sep, @{$row2}[@check]);

  # If whitespace isn't significant, collapse it
  unless ($self->WhiteSpace) {
    $str1 =~ s/\s+/ /g;
    $str2 =~ s/\s+/ /g;
  }

  # If case isn't significant, change to lower case
  unless ($self->Case) {
    $str1 = lc $str1;
    $str2 = lc $str2;
  }

  return $str1 eq $str2;
}

#line 376

sub full_compare {
  my $self = shift;

  $self->_check_args(@_);

  my ($row1, $row2) = @_;

  # No point in continuing if the number of elements is different.
  # Because of the expected return value from this function we can't
  # just say 'the arrays are different'. We need to do some work to
  # calculate a meaningful return value.
  # If we've been called in array context we return a list containing
  # the number of the columns that appear in the longer list and aren't
  # in the shorter list. If we've been called in scalar context we
  # return the difference in the lengths of the two lists.
  unless ($self->compare_len(@_)) {
    if (wantarray) {
      my ($max, $min);
      if ($#{$row1} > $#{$row2}) {
	($max, $min) = ($#{$row1}, $#{$row2} + 1);
      } else {
	($max, $min) = ($#{$row2}, $#{$row1} + 1);
      }
      return ($min .. $max);
    } else {
      return abs(@{$row1} - @{$row2});
    }
  }

  my ($arr1, $arr2) = @_;

  my @diffs = ();

  foreach (0 .. $#{$arr1}) {
    next if keys %{$self->Skip} && $self->Skip->{$_};

    my ($val1, $val2) = ($arr1->[$_], $arr2->[$_]);
    unless ($self->WhiteSpace) {
      $val1 =~ s/\s+/ /g;
      $val2 =~ s/\s+/ /g;
    }

    unless ($self->Case) {
      $val1 = lc $val1;
      $val2 = lc $val2;
    }

    push @diffs, $_ unless $val1 eq $val2;
  }

  return wantarray ? @diffs : scalar @diffs;
}

#line 441

sub perm {
  my $self = shift;

  return $self->simple_compare([sort @{$_[0]}], [sort @{$_[1]}]);
}

#
# Attempt to be clever with object attributes.
# Each object attribute is always accessed using an access method.
# None of these access methods exist in the object code.
# If an unknown method is called then the AUTOLOAD method is called
# in its place with the same parameters and the variable $AUTOLOAD
# set to the name of the unknown method.
#
# In this function we work out which method has been called and
# simulate it by returning the correct attribute value (and setting
# it to a new value if the method was passed a new value to use).
#
# We're also a little cleverer than that as we create a new method on
# the fly so that the next time we call the missing method it has
# magically sprung into existance, thereby avoiding the overhead of
# calling AUTOLOAD more than once for each method called.
#
sub AUTOLOAD {
  no strict 'refs';
  my ($self, $val) = @_;
  my ($name) = $AUTOLOAD =~ m/.*::(\w*)/;

  *{$AUTOLOAD} = sub { return @_ > 1 ?
			 $_[0]->{$name} = $_[1] :
			   $_[0]->{$name}};

  return defined $val ? $self->{$name} = $val : $self->{$name};
}

#
# One (small) downside of the AUTOLOAD trick, is that we need to
# explicitly define a DESTROY method to prevent Perl from passing
# those calls to AUTOLOAD. In this case we don't need to do anything.
#
sub DESTROY { }

1;
__END__

#line 503

#
# $Log$
# Revision 1.13  2005/09/21 09:23:40  dave
# Documentation fix
#
# Revision 1.12  2005/03/01 09:05:33  dave
# Changes to pass Pod::Coverage tests (and, hence, increase kwalitee)
#
# Revision 1.11  2004/10/23 08:11:32  dave
# Improved test coverage
#
# Revision 1.10  2004/10/22 20:32:48  dave
# Improved docs for full comparison
#
# Revision 1.9  2003/09/19 09:37:40  dave
# Bring CVS version into line with old file
#
# Revision 1.1  2003/09/19 09:34:43  dave
# Bit of an overhaul
#
# Revision 1.7  2002/03/29 17:45:09  dave
# Test version
#
# Revision 1.6  2002/01/09 11:41:52  dave
# Small cleanups
#
# Revision 1.5  2001/12/09 19:31:47  dave
# Cleanup.
#
# Revision 1.4  2001/06/04 20:47:01  dave
# RCS Import
#
# Revision 1.3  2001/02/26 13:34:41  dave
# Added case insensitivity.
#
# Revision 1.2  2000/06/04 17:43:14  dave
# Renamed 'manifest' and 'readme' to 'MANIFEST' and 'README'.
# Added header info.
#
# Revision 1.1.1.1  2000/06/04 17:40:19  dave
# CVS import
#
# Revision 0.2  00/05/13  14:23:48  14:23:48  dave (Dave Cross)
# Added 'perm' method.
# Revision 0.1  00/04/25  13:33:55  13:33:55  dave (Dave Cross)
# Initial version.
#
