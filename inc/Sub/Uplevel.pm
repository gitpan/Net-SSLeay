#line 1
package Sub::Uplevel;

use 5.006;

use strict;
use vars qw($VERSION @ISA @EXPORT);
$VERSION = "0.14";

# We have to do this so the CORE::GLOBAL versions override the builtins
_setup_CORE_GLOBAL();

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(uplevel);

#line 73

our @Up_Frames; # uplevel stack

sub uplevel {
    my($num_frames, $func, @args) = @_;
    
    local @Up_Frames = ($num_frames, @Up_Frames );
    return $func->(@args);
}


sub _setup_CORE_GLOBAL {
    no warnings 'redefine';

    *CORE::GLOBAL::caller = sub(;$) {
        my $height = $_[0] || 0;

        # shortcut if no uplevels have been called
        # always add +1 to CORE::caller to skip this function's caller
        return CORE::caller( $height + 1 ) if ! @Up_Frames;

#line 143

        my $saw_uplevel = 0;
        my $adjust = 0;

        # walk up the call stack to fight the right package level to return;
        # look one higher than requested for each call to uplevel found
        # and adjust by the amount found in the Up_Frames stack for that call

        for ( my $up = 0; $up <= $height + $adjust; $up++ ) {
            my @caller = CORE::caller($up + 1); 
            if( defined $caller[0] && $caller[0] eq __PACKAGE__ ) {
                # add one for each uplevel call seen
                # and look into the uplevel stack for the offset
                $adjust += 1 + $Up_Frames[$saw_uplevel];
                $saw_uplevel++;
            }
        }

        my @caller = CORE::caller($height + $adjust + 1);

        if( wantarray ) {
            if( !@_ ) {
                @caller = @caller[0..2];
            }
            return @caller;
        }
        else {
            return $caller[0];
        }
    }; # sub

}

#line 243


1;
