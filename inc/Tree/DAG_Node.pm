#line 1

# -*-Perl-*-  Time-stamp: "2004-12-29 18:17:58 AST"

require 5;
package Tree::DAG_Node;
use Carp ();
use strict;
use vars qw(@ISA $Debug $VERSION);

$Debug = 0;
$VERSION = "1.05";

#line 284

sub new { # constructor
  # Presumably you won't EVER need to override this -- _init is what
  # you'd override in order to set an object's default attribute values.
  my $class = shift;
  $class = ref($class) if ref($class); # tchristic style.  why not?

  my $o = ref($_[0]) eq 'HASH' ? $_[0] : {}; # o for options hashref
  my $it = bless( {}, $class );
  print "Constructing $it in class $class\n" if $Debug;
  $it->_init( $o );
  return $it;
}

###########################################################################

#line 318

sub _init { # method
  my $this = shift;
  my $o = ref($_[0]) eq 'HASH' ? $_[0] : {};

  # Sane initialization.
  $this->_init_mother($o);
  $this->_init_daughters($o);
  $this->_init_name($o);
  $this->_init_attributes($o);

  return;
}

sub _init_mother { # to be called by an _init
  my($this, $o) = @_[0,1];

  $this->{'mother'} = undef;

  # Undocumented and disfavored.  Consider this just an example.
  ( $o->{'mother'} )->add_daughter($this)
    if defined($o->{'mother'}) && ref($o->{'mother'});
  # DO NOT use this option (as implemented) with new_daughter or
  #  new_daughter_left!!!!!
  # BAD THINGS MAY HAPPEN!!!
}

sub _init_daughters { # to be called by an _init
  my($this, $o) = @_[0,1];

  $this->{'daughters'} = [];

  # Undocumented and disfavored.  Consider this just an example.
  $this->set_daughters( @{$o->{'daughters'}} )
    if ref($o->{'daughters'}) && (@{$o->{'daughters'}});
  # DO NOT use this option (as implemented) with new_daughter or
  #  new_daughter_left!!!!!
  # BAD THINGS MAY HAPPEN!!!
}

sub _init_name { # to be called by an _init
  my($this, $o) = @_[0,1];

  $this->{'name'} = undef;

  # Undocumented and disfavored.  Consider this just an example.
  $this->name( $o->{'name'} ) if exists $o->{'name'};
}

sub _init_attributes { # to be called by an _init
  my($this, $o) = @_[0,1];

  $this->{'attributes'} = {};

  # Undocumented and disfavored.  Consider this just an example.
  $this->attributes( $o->{'attributes'} ) if exists $o->{'attributes'};
}

###########################################################################
###########################################################################

#line 388

sub daughters { # read-only attrib-method: returns a list.
  my $this = shift;

  if(@_) { # undoc'd and disfavored to use as a write-method
    Carp::croak "Don't set daughters with doughters anymore\n";
    Carp::carp "my parameter must be a listref" unless ref($_[0]);
    $this->{'daughters'} = $_[0];
    $this->_update_daughter_links;
  }
  #return $this->{'daughters'};
  return @{$this->{'daughters'} || []};
}

###########################################################################

#line 410

sub mother { # read-only attrib-method: returns an object (the mother node)
  my $this = shift;
  Carp::croak "I'm a read-only method!" if @_;
  return $this->{'mother'};
}

###########################################################################
###########################################################################

#line 442

sub add_daughters { # write-only method
  my($mother, @daughters) = @_;
  return unless @daughters; # no-op
  return
    $mother->_add_daughters_wrapper(
      sub { push @{$_[0]}, $_[1]; },
      @daughters
    );
}

sub add_daughter { # alias
  my($it,@them) = @_;  $it->add_daughters(@them);
}

#line 468

sub add_daughters_left { # write-only method
  my($mother, @daughters) = @_;
  return unless @daughters;
  return
    $mother->_add_daughters_wrapper(
      sub { unshift @{$_[0]}, $_[1]; },
      @daughters
    );
}

sub add_daughter_left { # alias
  my($it,@them) = @_;  $it->add_daughters_left(@them);
}

#line 503


###
##  Used by the adding methods
#    (except maybe new_daughter, and new_daughter_left)

sub _add_daughters_wrapper {
  my($mother, $callback, @daughters) = @_;
  return unless @daughters;

  my %ancestors;
  @ancestors{ $mother->ancestors } = undef;
  # This could be made more efficient by not bothering to compile
  # the ancestor list for $mother if all the nodes to add are
  # daughterless.
  # But then you have to CHECK if they're daughterless.
  # If $mother is [big number] generations down, then it's worth checking.

  foreach my $daughter (@daughters) { # which may be ()
    Carp::croak "daughter must be a node object!" unless UNIVERSAL::can($daughter, 'is_node');

    printf "Mother  : %s (%s)\n", $mother, ref $mother if $Debug;
    printf "Daughter: %s (%s)\n", $daughter, ref $daughter if $Debug;
    printf "Adding %s to %s\n",
      ($daughter->name() || $daughter),
      ($mother->name()   || $mother)     if $Debug > 1;

    Carp::croak "mother can't be its own daughter!" if $mother eq $daughter;

    $daughter->cyclicity_fault(
      "$daughter (" . ($daughter->name || 'no_name') .
      ") is an ancestor of $mother (" . ($mother->name || 'no_name') .
      "), so can't became its daughter."
    ) if exists $ancestors{$daughter};

    my $old_mother = $daughter->{'mother'};

    next if defined($old_mother) && ref($old_mother) && $old_mother eq $mother;
      # noop if $daughter is already $mother's daughter

    $old_mother->remove_daughters($daughter)
      if defined($old_mother) && ref($old_mother);

    &{$callback}($mother->{'daughters'}, $daughter);
  }
  $mother->_update_daughter_links; # need only do this at the end

  return;
}

###########################################################################
###########################################################################

sub _update_daughter_links {
  # Eliminate any duplicates in my daughters list, and update
  #  all my daughters' links to myself.
  my $this = shift;

  my $them = $this->{'daughters'};

  # Eliminate duplicate daughters.
  my %seen = ();
  @$them = grep { ref($_) && not($seen{$_}++) } @$them;
   # not that there should ever be duplicate daughters anyhoo.

  foreach my $one (@$them) { # linkage bookkeeping
    Carp::croak "daughter <$one> isn't an object!" unless ref $one;
    $one->{'mother'} = $this;
  }
  return;
}

###########################################################################

# Currently unused.

sub _update_links { # update all descendant links for ancestorship below
  # this point
  # note: it's "descendant", not "descendent"
  # see <http://www.lenzo.com/~sburke/stuff/english_ant_and_ent.html>
  my $this = shift;
  # $this->no_cyclicity;
  $this->walk_down({
    'callback' => sub {
      my $this = $_[0];
      $this->_update_daughter_links;
      return 1;
    },
  });
}

###########################################################################
###########################################################################

#line 617

# Note that if you radically change 'mother'/'daughters' bookkeeping,
# you may have to change this routine, since it's one of the places
# that directly writes to 'daughters' and 'mother'.

sub new_daughter {
  my($mother, @options) = @_;
  my $daughter = $mother->new(@options);

  push @{$mother->{'daughters'}}, $daughter;
  $daughter->{'mother'} = $mother;

  return $daughter;
}

#line 640

# Note that if you radically change 'mother'/'daughters' bookkeeping,
# you may have to change this routine, since it's one of the places
# that directly writes to 'daughters' and 'mother'.

sub new_daughter_left {
  my($mother, @options) = @_;
  my $daughter = $mother->new(@options);

  unshift @{$mother->{'daughters'}}, $daughter;
  $daughter->{'mother'} = $mother;

  return $daughter;
}

###########################################################################

#line 666

sub remove_daughters { # write-only method
  my($mother, @daughters) = @_;
  Carp::croak "mother must be an object!" unless ref $mother;
  return unless @daughters;

  my %to_delete;
  @daughters = grep {ref($_)
		       and defined($_->{'mother'})
		       and $mother eq $_->{'mother'}
                    } @daughters;
  return unless @daughters;
  @to_delete{ @daughters } = undef;

  # This could be done better and more efficiently, I guess.
  foreach my $daughter (@daughters) {
    $daughter->{'mother'} = undef;
  }
  my $them = $mother->{'daughters'};
  @$them = grep { !exists($to_delete{$_}) } @$them;

  # $mother->_update_daughter_links; # unnecessary
  return;
}

#line 696

sub remove_daughter { # alias
  my($it,@them) = @_;  $it->remove_daughters(@them);
}

#line 709

sub unlink_from_mother {
  my $node = $_[0];
  my $mother = $node->{'mother'};
  $mother->remove_daughters($node) if defined($mother) && ref($mother);
  return $mother;
}

###########################################################################

#line 727

sub clear_daughters { # write-only method
  my($mother) = $_[0];
  my @daughters = @{$mother->{'daughters'}};

  @{$mother->{'daughters'}} = ();
  foreach my $one (@daughters) {
    next unless UNIVERSAL::can($one, 'is_node'); # sanity check
    $one->{'mother'} = undef;
  }
  # Another, simpler, way to do it:
  #  $mother->remove_daughters($mother->daughters);

  return @daughters; # NEW
}
#--------------------------------------------------------------------------

#line 753

sub set_daughters { # write-only method
  my($mother, @them) = @_;
  $mother->clear_daughters;
  $mother->add_daughters(@them) if @them;
  # yup, it's that simple
}

#--------------------------------------------------------------------------

#line 809

sub replace_with { # write-only method
  my($this, @replacements) = @_;
  
  if(not( defined($this->{'mother'}) && ref($this->{'mother'}) )) { # if root
    foreach my $replacement (@replacements) {
      $replacement->{'mother'}->remove_daughters($replacement)
        if $replacement->{'mother'};
    }
      # make 'em roots
  } else { # I have a mother
    my $mother = $this->{'mother'};

    #@replacements = grep(($_ eq $this  ||  $_->{'mother'} ne $mother),
    #                     @replacements);
    @replacements = grep { $_ eq $this
                           || not(defined($_->{'mother'}) &&
                                  ref($_->{'mother'}) &&
                                  $_->{'mother'} eq $mother
                                 )
                         }
                         @replacements;
    # Eliminate sisters (but not self)
    # i.e., I want myself or things NOT with the same mother as myself.

    $mother->set_daughters(   # old switcheroo
                           map($_ eq $this ? (@replacements) : $_ ,
                               @{$mother->{'daughters'}}
                              )
                          );
    # and set_daughters does all the checking and possible
    # unlinking
  }
  return($this, @replacements);
}

#line 863

# Note that if you radically change 'mother'/'daughters' bookkeeping,
# you may have to change this routine, since it's one of the places
# that directly writes to 'daughters' and 'mother'.

sub replace_with_daughters { # write-only method
  my($this) = $_[0]; # takes no params other than the self
  my $mother = $this->{'mother'};
  return($this, $this->clear_daughters)
    unless defined($mother) && ref($mother);

  my @daughters = $this->clear_daughters;
  my $sib_r = $mother->{'daughters'};
  @$sib_r = map($_ eq $this ? (@daughters) : $_,
                @$sib_r   # old switcheroo
            );
  foreach my $daughter (@daughters) {
    $daughter->{'mother'} = $mother;
  }
  return($this, @daughters);
}

#--------------------------------------------------------------------------

#line 905

sub add_left_sisters { # write-only method
  my($this, @new) = @_;
  return() unless @new;
  
  @new = $this->replace_with(@new, $this);
  shift @new; pop @new; # kill the copies of $this
  return @new;
}

#line 920

sub add_left_sister { # alias
  my($it,@them) = @_;  $it->add_left_sisters(@them);
}

#line 935

sub add_right_sisters { # write-only method
  my($this, @new) = @_;
  return() unless @new;
  @new = $this->replace_with($this, @new);
  shift @new; shift @new; # kill the copies of $this
  return @new;
}

#line 949

sub add_right_sister { # alias
  my($it,@them) = @_;  $it->add_right_sisters(@them);
}

###########################################################################

#line 959

###########################################################################
###########################################################################

#line 973

sub name { # read/write attribute-method.  returns/expects a scalar
  my $this = shift;
  $this->{'name'} = $_[0] if @_;
  return $this->{'name'};
}


###########################################################################

#line 998

sub attributes { # read/write attribute-method
  # expects a ref, presumably a hashref
  my $this = shift;
  if(@_) {
    Carp::carp "my parameter must be a reference" unless ref($_[0]);
    $this->{'attributes'} = $_[0];
  }
  return $this->{'attributes'};
}

#line 1014

sub attribute { # alias
  my($it,@them) = @_;  $it->attributes(@them);
}

###########################################################################
# Secret Stuff.

sub no_cyclicity { # croak iff I'm in a CYCLIC class. 
  my($it) = $_[0];
  # If, God forbid, I use this to make a cyclic class, then I'd
  # expand the functionality of this routine to actually look for
  # cyclicity.  Or something like that.  Maybe.

  $it->cyclicity_fault("You can't do that in a cyclic class!")
    if $it->cyclicity_allowed;
  return;
}

sub cyclicity_fault {
  my($it, $bitch) = @_[0,1];
  Carp::croak "Cyclicity fault: $bitch"; # never return
}

sub cyclicity_allowed {
  return 0;
}

###########################################################################
# More secret stuff.  Currently unused.

sub inaugurate_root { # no-op
  my($it, $tree) = @_[0,1];
  # flag this node as being the root of the tree $tree.
  return;
}

sub decommission_root { # no-op
  # flag this node as no longer being the root of the tree $tree.
  return;
}

###########################################################################
###########################################################################

#line 1072

sub is_node { return 1; } # always true.
# NEVER override this with anything that returns false in the belief
#  that this'd signal "not a node class".  The existence of this method
#  is what I test for, with the various "can()" uses in this class.

###########################################################################

#line 1092

sub ancestors {
  my $this = shift;
  my $mama = $this->{'mother'}; # initial condition
  return () unless ref($mama); # I must be root!

  # $this->no_cyclicity; # avoid infinite loops

  # Could be defined recursively, as:
  # if(ref($mama = $this->{'mother'})){
  #   return($mama, $mama->ancestors);
  # } else {
  #   return ();
  # }
  # But I didn't think of that until I coded the stuff below, which is
  # faster.

  my @ancestors = ( $mama ); # start off with my mama
  while(defined( $mama = $mama->{'mother'} ) && ref($mama)) {
    # Walk up the tree
    push(@ancestors, $mama);
    # This turns into an infinite loop if someone gets stupid
    #  and makes this tree cyclic!  Don't do it!
  }
  return @ancestors;
}

###########################################################################

#line 1127

sub root {
  my $it = $_[0];
  my @ancestors = ($it, $it->ancestors);
  return $ancestors[-1];
}

###########################################################################

#line 1142

sub is_daughter_of {
  my($it,$mama) = @_[0,1];
  return $it->{'mother'} eq $mama;
}

###########################################################################

#line 1159

sub self_and_descendants {
  # read-only method:  return a list of myself and any/all descendants
  my $node = shift;
  my @List = ();
  # $node->no_cyclicity;
  $node->walk_down({ 'callback' => sub { push @List, $_[0]; return 1;}});
  Carp::croak "Spork Error 919: \@List has no contents!?!?" unless @List;
    # impossible
  return @List;
}

###########################################################################

#line 1181

sub descendants {
  # read-only method:  return a list of my descendants
  my $node = shift;
  my @list = $node->self_and_descendants;
  shift @list; # lose myself.
  return @list;
}

###########################################################################

#line 1200

sub leaves_under {
  # read-only method:  return a list of all leaves under myself.
  # Returns myself in the degenerate case of being a leaf myself.
  my $node = shift;
  my @List = ();
  # $node->no_cyclicity;
  $node->walk_down({ 'callback' =>
    sub {
      my $node = $_[0];
      my @daughters = @{$node->{'daughters'}};
      push(@List, $node) unless @daughters;
      return 1;
    }
  });
  Carp::croak "Spork Error 861: \@List has no contents!?!?" unless @List;
    # impossible
  return @List;
}

###########################################################################

#line 1231

sub depth_under {
  my $node = shift;
  my $max_depth = 0;
  $node->walk_down({
    '_depth' => 0,
    'callback' => sub {
      my $depth = $_[1]->{'_depth'};
      $max_depth = $depth if $depth > $max_depth;
      return 1;
    },
  });
  return $max_depth;
}

###########################################################################

#line 1285

sub generation {
  my($node, $limit) = @_[0,1]; 
  # $node->no_cyclicity;
  return $node
    if $node eq $limit || not(
			      defined($node->{'mother'}) &&
			      ref($node->{'mother'})
			     ); # bailout

  return map(@{$_->{'daughters'}}, $node->{'mother'}->generation($limit));
    # recurse!
    # Yup, my generation is just all the daughters of my mom's generation.
}

sub generation_under {
  my($node, @rest) = @_; 
  return $node->generation(@rest);
}

###########################################################################

#line 1318

sub self_and_sisters {
  my $node = $_[0];
  my $mother = $node->{'mother'};
  return $node unless defined($mother) && ref($mother);  # special case
  return @{$node->{'mother'}->{'daughters'}};
}

###########################################################################

#line 1335

sub sisters {
  my $node = $_[0];
  my $mother = $node->{'mother'};
  return() unless $mother;  # special case
  return grep($_ ne $node,
              @{$node->{'mother'}->{'daughters'}}
             );
}

###########################################################################

#line 1356

sub left_sister {
  my $it = $_[0];
  my $mother = $it->{'mother'};
  return undef unless $mother;
  my @sisters = @{$mother->{'daughters'}};
  
  return undef if @sisters  == 1; # I'm an only daughter

  my $left = undef;
  foreach my $one (@sisters) {
    return $left if $one eq $it;
    $left = $one;
  }
  die "SPORK ERROR 9757: I'm not in my mother's daughter list!?!?";
}


#line 1383

sub left_sisters {
  my $it = $_[0];
  my $mother = $it->{'mother'};
  return() unless $mother;
  my @sisters = @{$mother->{'daughters'}};
  return() if @sisters  == 1; # I'm an only daughter

  my @out = ();
  foreach my $one (@sisters) {
    return @out if $one eq $it;
    push @out, $one;
  }
  die "SPORK ERROR 9767: I'm not in my mother's daughter list!?!?";
}

#line 1408

sub right_sister {
  my $it = $_[0];
  my $mother = $it->{'mother'};
  return undef unless $mother;
  my @sisters = @{$mother->{'daughters'}};
  return undef if @sisters  == 1; # I'm an only daughter

  my $seen = 0;
  foreach my $one (@sisters) {
    return $one if $seen;
    $seen = 1 if $one eq $it;
  }
  die "SPORK ERROR 9777: I'm not in my mother's daughter list!?!?"
    unless $seen;
  return undef;
}

#line 1435

sub right_sisters {
  my $it = $_[0];
  my $mother = $it->{'mother'};
  return() unless $mother;
  my @sisters = @{$mother->{'daughters'}};
  return() if @sisters  == 1; # I'm an only daughter

  my @out;
  my $seen = 0;
  foreach my $one (@sisters) {
    push @out, $one if $seen;
    $seen = 1 if $one eq $it;
  }
  die "SPORK ERROR 9787: I'm not in my mother's daughter list!?!?"
    unless $seen;
  return @out;
}

###########################################################################

#line 1465

sub my_daughter_index {
  # returns what number is my index in my mother's daughter list
  # special case: 0 for root.
  my $node = $_[0];
  my $ord = -1;
  my $mother = $node->{'mother'};

  return 0 unless $mother;
  my @sisters = @{$mother->{'daughters'}};

  die "SPORK ERROR 6512:  My mother has no kids!!!" unless @sisters;

 Find_Self:
  for(my $i = 0; $i < @sisters; $i++) {
    if($sisters[$i] eq $node) {
      $ord = $i;
      last Find_Self;
    }
  }
  die "SPORK ERROR 2837: I'm not a daughter of my mother?!?!" if $ord == -1;
  return $ord;
}

###########################################################################

#line 1534

sub address {
  my($it, $address) = @_[0,1];
  if(defined($address) && length($address)) { # given the address, return the node.
    # invalid addresses return undef
    my $root = $it->root;
    my @parts = map {$_ + 0}
                    $address =~ m/(\d+)/g; # generous!
    Carp::croak "Address \"$address\" is an ill-formed address" unless @parts;
    Carp::croak "Address \"$address\" must start with '0'" unless shift(@parts) == 0;

    my $current_node = $root;
    while(@parts) { # no-op for root
      my $ord = shift @parts;
      my @daughters = @{$current_node->{'daughters'}};

      if($#daughters < $ord) { # illegal address
        print "* $address has an out-of-range index ($ord)!" if $Debug;
        return undef;
      }
      $current_node = $daughters[$ord];
      unless(ref($current_node)) {
        print "* $address points to or thru a non-node!" if $Debug;
        return undef;
      }
    }
    return $current_node;

  } else { # given the node, return the address
    my @parts = ();
    my $current_node = $it;
    my $mother;

    while(defined( $mother = $current_node->{'mother'} ) && ref($mother)) {
      unshift @parts, $current_node->my_daughter_index;
      $current_node = $mother;
    }
    return join(':', 0, @parts);
  }
}

###########################################################################

#line 1590

sub common { # Return the lowest node common to all these nodes...
  # Called as $it->common($other) or $it->common(@others)
  my @ones = @_; # all nodes I was given
  my($first, @others) = @_;

  return $first unless @others; # degenerate case

  my %ones;
  @ones{ @ones } = undef;

  foreach my $node (@others) {
    Carp::croak "TILT: node \"$node\" is not a node"
      unless UNIVERSAL::can($node, 'is_node');
    my %first_lineage;
    @first_lineage{$first, $first->ancestors} = undef;
    my $higher = undef; # the common of $first and $node
    my @my_lineage = $node->ancestors;

   Find_Common:
    while(@my_lineage) {
      if(exists $first_lineage{$my_lineage[0]}) {
        $higher = $my_lineage[0];
        last Find_Common;
      }
      shift @my_lineage;
    }
    return undef unless $higher;
    $first = $higher;
  } 
  return $first;
}


###########################################################################

#line 1643

sub common_ancestor {
  my @ones = @_; # all nodes I was given
  my($first, @others) = @_;

  return $first->{'mother'} unless @others;
    # which may be undef if $first is the root!

  my %ones;
  @ones{ @ones } = undef; # my arguments

  my $common = $first->common(@others);
  if(exists($ones{$common})) { # if the common is one of my nodes...
    return $common->{'mother'};
    # and this might be undef, if $common is root!
  } else {
    return $common;
    # which might be null if that's all common came up with
  }
}

###########################################################################
###########################################################################

#line 1724

sub walk_down {
  my($this, $o) = @_[0,1];

  # All the can()s are in case an object changes class while I'm
  # looking at it.

  Carp::croak "I need options!" unless ref($o);
  Carp::croak "I need a callback or a callbackback" unless
    ( ref($o->{'callback'}) || ref($o->{'callbackback'}) );

  # $this->no_cyclicity;
  my $callback = ref($o->{'callback'}) ? $o->{'callback'} : undef;
  my $callbackback = ref($o->{'callbackback'}) ? $o->{'callbackback'} : undef;
  my $callback_status = 1;

  print "Callback: $callback   Callbackback: $callbackback\n" if $Debug;

  printf "* Entering %s\n", ($this->name || $this) if $Debug;
  $callback_status = &{ $callback }( $this, $o ) if $callback;

  if($callback_status) {
    # Keep recursing unless callback returned false... and if there's
    # anything to recurse into, of course.
    my @daughters = UNIVERSAL::can($this, 'is_node') ? @{$this->{'daughters'}} : ();
    if(@daughters) {
      $o->{'_depth'} += 1;
      #print "Depth " , $o->{'_depth'}, "\n";
      foreach my $one (@daughters) {
        $one->walk_down($o) if UNIVERSAL::can($one, 'is_node');
        # and if it can do "is_node", it should provide a walk_down!
      }
      $o->{'_depth'} -= 1;
    }
  } else {
    printf "* Recursing below %s pruned\n", ($this->name || $this) if $Debug;
  }

  # Note that $callback_status doesn't block callbackback from being called
  if($callbackback){
    if(UNIVERSAL::can($this, 'is_node')) { # if it's still a node!
      print "* Calling callbackback\n" if $Debug;
      scalar( &{ $callbackback }( $this, $o ) );
      # scalar to give it the same context as callback
    } else {
      print "* Can't call callbackback -- $this isn't a node anymore\n"
        if $Debug;
    }
  }
  if($Debug) {
    if(UNIVERSAL::can($this, 'is_node')) { # if it's still a node!
      printf "* Leaving %s\n", ($this->name || $this)
    } else {
      print "* Leaving [no longer a node]\n";
    }
  }
  return;
}

###########################################################################

#line 1807

sub dump_names {
  my($it, $o) = @_[0,1];
  $o = {} unless ref $o;
  my @out = ();
  $o->{'_depth'} ||= 0;
  $o->{'indent'} ||= '  ';
  $o->{'tick'} ||= '';

  $o->{'callback'} = sub {
      my($this, $o) = @_[0,1];
      push(@out,
        join('',
             $o->{'indent'} x $o->{'_depth'},
             $o->{'tick'},
             &Tree::DAG_Node::_dump_quote($this->name || $this),
             "\n"
        )
      );      
      return 1;
    }
  ;
  $it->walk_down($o);
  return @out;
}

###########################################################################
###########################################################################

#line 1869

sub random_network { # constructor or method.
  my $class = $_[0];
  my $o = ref($_[1]) ? $_[1] : {};
  my $am_cons = 0;
  my $root;

  if(ref($class)){ # I'm a method.
    $root = $_[0]; # build under the given node, from same class.
    $class = ref $class;
    $am_cons = 0;
  } else { # I'm a constructor
    $root = $class->new; # build under a new node, with class named.
    $root->name("Root");
    $am_cons = 1;
  }

  my $min_depth = $o->{'min_depth'} || 2;
  my $max_depth = $o->{'max_depth'} || ($min_depth + 3);
  my $max_children = $o->{'max_children'} || 4;
  my $max_node_count = $o->{'max_node_count'} || 25;

  Carp::croak "max_children has to be positive" if int($max_children) < 1;

  my @mothers = ( $root );
  my @children = ( );
  my $node_count = 1; # the root

 Gen:
  foreach my $depth (1 .. $max_depth) {
    last if $node_count > $max_node_count;
   Mother:
    foreach my $mother (@mothers) {
      last Gen if $node_count > $max_node_count;
      my $children_number;    
      if($depth <= $min_depth) {
        until( $children_number = int(rand(1 + $max_children)) ) {}
      } else {
        $children_number = int(rand($max_children));
      }
     Beget:
      foreach (1 .. $children_number) {
        last Gen if $node_count > $max_node_count;
        my $node = $mother->new_daughter;
        $node->name("Node$node_count");
        ++$node_count;
        push(@children, $node);
      }
    }
    @mothers = @children;
    @children = ();
    last unless @mothers;
  }

  return $root;
}

#line 1990

sub lol_to_tree {
  my($class, $lol, $seen_r) = @_[0,1,2];
  $seen_r = {} unless ref($seen_r) eq 'HASH';
  return if ref($lol) && $seen_r->{$lol}++; # catch circularity

  $class = ref($class) || $class;
  my $node = $class->new();

  unless(ref($lol) eq 'ARRAY') {  # It's a terminal node.
    $node->name($lol) if defined $lol;
    return $node;
  }
  return $node unless @$lol;  # It's a terminal node, oddly represented

  #  It's a non-terminal node.

  my @options = @$lol; 
  unless(ref($options[-1]) eq 'ARRAY') {
    # This is what separates this method from simple_lol_to_tree
    $node->name(pop(@options));
  }

  foreach my $d (@options) {  # Scan daughters (whether scalars or listrefs)
    $node->add_daughter( $class->lol_to_tree($d, $seen_r) );  # recurse!
  }

  return $node;
}

#--------------------------------------------------------------------------

#line 2050

#--------------------------------------------------------------------------

sub tree_to_lol_notation {
  my $root = $_[0];
  my($it, $o) = @_[0,1];
  $o = {} unless ref $o;
  my @out = ();
  $o->{'_depth'} ||= 0;
  $o->{'multiline'} = 0 unless exists($o->{'multiline'});

  my $line_end;
  if($o->{'multiline'}) {
    $o->{'indent'} ||= '  ';
    $line_end = "\n";
  } else {
    $o->{'indent'} ||= '';
    $line_end = '';
  }

  $o->{'callback'} = sub {
      my($this, $o) = @_[0,1];
      push(@out,
             $o->{'indent'} x $o->{'_depth'},
             "[$line_end",
      );      
      return 1;
    }
  ;
  $o->{'callbackback'} = sub {
      my($this, $o) = @_[0,1];
      my $name = $this->name;
      if(!defined($name)) {
        $name = 'undef';
      } else {
        $name = &Tree::DAG_Node::_dump_quote($name);
      }
      push(@out,
             $o->{'indent'} x ($o->{'_depth'} + 1),
             "$name$line_end",
             $o->{'indent'} x $o->{'_depth'},
             "], $line_end",
      );
      return 1;
    }
  ;
  $it->walk_down($o);
  return join('', @out);
}

#--------------------------------------------------------------------------

#line 2114

sub tree_to_lol {
  # I haven't /rigorously/ tested this.
  my($it, $o) = @_[0,1]; # $o is currently unused anyway
  $o = {} unless ref $o;

  my $out = [];
  my @lol_stack = ($out);
  $o->{'callback'} = sub {
      my($this, $o) = @_[0,1];
      my $new = [];
      push @{$lol_stack[-1]}, $new;
      push(@lol_stack, $new);
      return 1;
    }
  ;
  $o->{'callbackback'} = sub {
      my($this, $o) = @_[0,1];
      push @{$lol_stack[-1]}, $this->name;
      pop @lol_stack;
      return 1;
    }
  ;
  $it->walk_down($o);
  die "totally bizarre error 12416" unless ref($out->[0]);
  $out = $out->[0]; # the real root
  return $out;
}

###########################################################################

#line 2170

sub simple_lol_to_tree {
  my($class, $lol, $seen_r) = @_[0,1,2];
  $class = ref($class) || $class;
  $seen_r = {} unless ref($seen_r) eq 'HASH';
  return if ref($lol) && $seen_r->{$lol}++; # catch circularity

  my $node = $class->new();

  unless(ref($lol) eq 'ARRAY') {  # It's a terminal node.
    $node->name($lol) if defined $lol;
    return $node;
  }

  #  It's a non-terminal node.
  foreach my $d (@$lol) { # scan daughters (whether scalars or listrefs)
    $node->add_daughter( $class->simple_lol_to_tree($d, $seen_r) );  # recurse!
  }

  return $node;
}

#--------------------------------------------------------------------------

#line 2207

sub tree_to_simple_lol {
  # I haven't /rigorously/ tested this.
  my $root = $_[0];

  return $root->name unless scalar($root->daughters);
   # special case we have to nip in the bud

  my($it, $o) = @_[0,1]; # $o is currently unused anyway
  $o = {} unless ref $o;

  my $out = [];
  my @lol_stack = ($out);
  $o->{'callback'} = sub {
      my($this, $o) = @_[0,1];
      my $new;
      $new = scalar($this->daughters) ? [] : $this->name;
        # Terminal nodes are scalars, the rest are listrefs we'll fill in
        # as we recurse the tree below here.
      push @{$lol_stack[-1]}, $new;
      push(@lol_stack, $new);
      return 1;
    }
  ;
  $o->{'callbackback'} = sub { pop @lol_stack; return 1; };
  $it->walk_down($o);
  die "totally bizarre error 12416" unless ref($out->[0]);
  $out = $out->[0]; # the real root
  return $out;
}

#--------------------------------------------------------------------------

#line 2246

sub tree_to_simple_lol_notation {
  my($it, $o) = @_[0,1];
  $o = {} unless ref $o;
  my @out = ();
  $o->{'_depth'} ||= 0;
  $o->{'multiline'} = 0 unless exists($o->{'multiline'});

  my $line_end;
  if($o->{'multiline'}) {
    $o->{'indent'} ||= '  ';
    $line_end = "\n";
  } else {
    $o->{'indent'} ||= '';
    $line_end = '';
  }

  $o->{'callback'} = sub {
      my($this, $o) = @_[0,1];
      if(scalar($this->daughters)) {   # Nonterminal
        push(@out,
               $o->{'indent'} x $o->{'_depth'},
               "[$line_end",
        );
      } else {   # Terminal
        my $name = $this->name;
        push @out,
          $o->{'indent'} x $o->{'_depth'},
          defined($name) ? &Tree::DAG_Node::_dump_quote($name) : 'undef',
          ",$line_end";
      }
      return 1;
    }
  ;
  $o->{'callbackback'} = sub {
      my($this, $o) = @_[0,1];
      push(@out,
             $o->{'indent'} x $o->{'_depth'},
             "], $line_end",
      ) if scalar($this->daughters);
      return 1;
    }
  ;

  $it->walk_down($o);
  return join('', @out);
}

###########################################################################
#  $list_r = $root_node->draw_ascii_tree({ h_compact => 1});
#  print map("$_\n", @$list_r);

#line 2331

sub draw_ascii_tree {
  # Make a "box" for this node and its possible daughters, recursively.

  # The guts of this routine are horrific AND recursive!

  # Feel free to send me better code.  I worked on this until it
  #  gave me a headache and it worked passably, and then I stopped.

  my $it = $_[0];
  my $o = ref($_[1]) ? $_[1] : {};
  my(@box, @daughter_boxes, $width, @daughters);
  @daughters = @{$it->{'daughters'}};

  # $it->no_cyclicity;

  $o->{'no_name'}   = 0 unless exists $o->{'no_name'};
  $o->{'h_spacing'} = 1 unless exists $o->{'h_spacing'};
  $o->{'h_compact'} = 1 unless exists $o->{'h_compact'};
  $o->{'v_compact'} = 1 unless exists $o->{'v_compact'};

  my $printable_name;
  if($o->{'no_name'}) {
    $printable_name = '*';
  } else {
    $printable_name = $it->name || $it;
    $printable_name =~ tr<\cm\cj\t >< >s;
    $printable_name = "<$printable_name>";
  }

  if(!scalar(@daughters)) { # I am a leaf!
    # Now add the top parts, and return.
    @box = ("|", $printable_name);
  } else {
    @daughter_boxes = map { &draw_ascii_tree($_, $o) } @daughters;

    my $max_height = 0;
    foreach my $box (@daughter_boxes) {
      my $h = @$box;
      $max_height = $h if $h > $max_height;
    }

    @box = ('') x $max_height; # establish the list

    foreach my $one (@daughter_boxes) {
      my $length = length($one->[0]);
      my $height = @$one;

      #now make all the same height.
      my $deficit = $max_height - $height;
      if($deficit > 0) {
        push @$one, ( scalar( ' ' x $length ) ) x $deficit;
        $height = scalar(@$one);
      }


      # Now tack 'em onto @box
      ##########################################################
      # This used to be a sub of its own.  Ho-hum.

      my($b1, $b2) = (\@box, $one);
      my($h1, $h2) = (scalar(@$b1), scalar(@$b2));

      my(@diffs, $to_chop);
      if($o->{'h_compact'}) { # Try for h-scrunching.
        my @diffs;
        my $min_diff = length($b1->[0]); # just for starters
        foreach my $line (0 .. ($h1 - 1)) {
          my $size_l = 0; # length of terminal whitespace
          my $size_r = 0; # length of initial whitespace
          $size_l = length($1) if $b1->[$line] =~ /( +)$/s;
          $size_r = length($1) if $b2->[$line] =~ /^( +)/s;
          my $sum = $size_l + $size_r;
      
          $min_diff = $sum if $sum < $min_diff;
          push @diffs, [$sum, $size_l, $size_r];
        }
        $to_chop = $min_diff - $o->{'h_spacing'};
        $to_chop = 0 if $to_chop < 0;
      }

      if(not(  $o->{'h_compact'} and $to_chop  )) {
        # No H-scrunching needed/possible
        foreach my $line (0 .. ($h1 - 1)) {
          $b1->[ $line ] .= $b2->[ $line ] . (' ' x $o->{'h_spacing'});
        }
      } else {
        # H-scrunching is called for.
        foreach my $line (0 .. ($h1 - 1)) {
          my $r = $b2->[$line]; # will be the new line
          my $remaining = $to_chop;
          if($remaining) {
            my($l_chop, $r_chop) = @{$diffs[$line]}[1,2];
      
            if($l_chop) {
              if($l_chop > $remaining) {
                $l_chop = $remaining;
                $remaining = 0;
              } elsif($l_chop == $remaining) {
                $remaining = 0;
              } else { # remaining > l_chop
                $remaining -= $l_chop;
              }
            }
            if($r_chop) {
              if($r_chop > $remaining) { 
                $r_chop = $remaining;
                $remaining = 0;
              } elsif($r_chop == $remaining) {
                $remaining = 0;
              } else { # remaining > r_chop
                $remaining -= $r_chop; # should never happen!
              }
            }

            substr($b1->[$line], -$l_chop) = '' if $l_chop;
            substr($r, 0, $r_chop) = '' if $r_chop;
          } # else no-op
          $b1->[ $line ] .= $r . (' ' x $o->{'h_spacing'});
        }
         # End of H-scrunching ickyness
      }
       # End of ye big tack-on

    }
     # End of the foreach daughter_box loop

    # remove any fencepost h_spacing
    if($o->{'h_spacing'}) {
      foreach my $line (@box) {
        substr($line, -$o->{'h_spacing'}) = '' if length($line);
      }
    }

    # end of catenation
    die "SPORK ERROR 958203: Freak!!!!!" unless @box;

    # Now tweak the pipes
    my $new_pipes = $box[0];
    my $pipe_count = $new_pipes =~ tr<|><+>;
    if($pipe_count < 2) {
      $new_pipes = "|";
    } else {
      my($init_space, $end_space);

      # Thanks to Gilles Lamiral for pointing out the need to set to '',
      #  to avoid -w warnings about undeffiness.

      if( $new_pipes =~ s<^( +)><>s ) {
        $init_space = $1;
      } else {
        $init_space = '';
      }

      if( $new_pipes =~ s<( +)$><>s ) {
        $end_space  = $1
      } else {
        $end_space = '';
      }

      $new_pipes =~ tr< ><->;
      substr($new_pipes,0,1) = "/";
      substr($new_pipes,-1,1) = "\\";

      $new_pipes = $init_space . $new_pipes . $end_space;
      # substr($new_pipes, int((length($new_pipes)), 1)) / 2) = "^"; # feh
    }

    # Now tack on the formatting for this node.
    if($o->{'v_compact'} == 2) {
      if(@daughters == 1) {
        unshift @box, "|", $printable_name;
      } else {
        unshift @box, "|", $printable_name, $new_pipes;
      }
    } elsif ($o->{'v_compact'} == 1 and @daughters == 1) {
      unshift @box, "|", $printable_name;
    } else { # general case
      unshift @box, "|", $printable_name, $new_pipes;
    }
  }

  # Flush the edges:
  my $max_width = 0;
  foreach my $line (@box) {
    my $w = length($line);
    $max_width = $w if $w > $max_width;
  }
  foreach my $one (@box) {
    my $space_to_add = $max_width - length($one);
    next unless $space_to_add;
    my $add_left = int($space_to_add / 2);
    my $add_right = $space_to_add - $add_left;
    $one = (' ' x $add_left) . $one . (' ' x $add_right);
  }

  return \@box; # must not return a null list!
}

###########################################################################

#line 2544

sub copy_tree {
  my($this, $o) = @_[0,1];
  my $root = $this->root;
  $o = {} unless ref $o;
  
  my $new_root = $root->copy_at_and_under($o);
  
  return $new_root;
}

#line 2569

sub copy_at_and_under {
  my($from, $o) = @_[0,1];
  $o = {} unless ref $o;
  my @daughters = map($_->copy_at_and_under($o), @{$from->{'daughters'}});
  my $to = $from->copy($o);
  $to->set_daughters(@daughters) if @daughters;
  return $to;
}

#line 2642

sub copy {
  my($from,$o) = @_[0,1];
  $o = {} unless ref $o;

  # Straight dupe, and bless into same class:
  my $to = bless { %$from }, ref($from);
  
  # Null out linkages.
  $to->_init_mother;
  $to->_init_daughters;

  # dupe the 'attributes' attribute:
  unless($o->{'no_attribute_copy'}) {
    my $attrib_copy = ref($to->{'attributes'});
    if($attrib_copy) {
      if($attrib_copy eq 'HASH') {
        $to->{'attributes'} = { %{$to->{'attributes'}} };
        # dupe the hashref
      } elsif ($attrib_copy = UNIVERSAL::can($to->{'attributes'}, 'copy') ) {
        # $attrib_copy now points to the copier method
        $to->{'attributes'} = &{$attrib_copy}($from);
      } # otherwise I don't know how to copy it; leave as is
    }
  }
  $o->{'from_to'}->{$from} = $to; # SECRET VOODOO
    # ...autovivifies an anon hashref for 'from_to' if need be
    # This is here in case I later want/need a table corresponding
    # old nodes to new.
  return $to;
}


###########################################################################

#line 2736

sub delete_tree {
  my $it = $_[0];
  $it->root->walk_down({ # has to be callbackback, not callback
    'callbackback' => sub {
       %{$_[0]} = ();
       bless($_[0], 'DEADNODE'); # cause become dead!  cause become dead!
       return 1;
     }
  });
  return;
  # Why DEADNODE?  Because of the nice error message:
  #  "Can't locate object method "leaves_under" via package "DEADNODE"."
  # Moreover, DEADNODE doesn't provide is_node, so fails my can() tests.
}

sub DEADNODE::delete_tree { return; }
  # in case you kill it AGAIN!!!!!  AND AGAIN AND AGAIN!!!!!! OO-HAHAHAHA!

###########################################################################
# stolen from MIDI.pm

sub _dump_quote {
  my @stuff = @_;
  return
    join(", ",
    map
     { # the cleaner-upper function
       if(!length($_)) { # empty string
         "''";
       } elsif( m/^-?\d+(?:\.\d+)?$/s ) { # a number
         $_;
       } elsif( # text with junk in it
          s<([^\x20\x21\x23\x27-\x3F\x41-\x5B\x5D-\x7E])>
           <'\\x'.(unpack("H2",$1))>eg
         ) {
         "\"$_\"";
       } else { # text with no junk in it
         s<'><\\'>g;
         "\'$_\'";
       }
     }
     @stuff
    );
}

###########################################################################

#line 2936

1;

__END__
