# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl MPGA.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 14;
BEGIN { use_ok('MPGA') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


is_deeply( [ step() ], [undef, undef, undef], 'test step()' );

my $reverse_flow = undef;
is_deeply( [ step( $reverse_flow ) ], [undef, undef, undef], 'test step( undef )' );

$reverse_flow = 'aaa';
is_deeply( [ step( $reverse_flow ) ], [undef, undef, undef], 'test step( scalar )' );

my @reverse_flow = ( 1, 2, 'aaa' );
is_deeply( [ step( @reverse_flow ) ], [undef, undef, undef], 'test step( array )' );

my %reverse_flow = ( 1 => 2, 'aaa' => 'bbb' );
is_deeply( [ step( $reverse_flow ) ], [undef, undef, undef], 'test step( hash )' );

$reverse_flow = { 1 => 2, 'aaa' => 'bbb' };
is_deeply( [ step( $reverse_flow ) ], [undef, undef, undef], 'test step( \hash )' );

$reverse_flow = [];
is_deeply( [ step( $reverse_flow ) ], [undef, undef, undef], 'test step( [] )' );

$reverse_flow = [1];
is_deeply( [ step( $reverse_flow ) ], [undef, [1], 1], 'test step( [scalar] )' );

$reverse_flow = [3, 2, 1];
is_deeply( [ step( $reverse_flow ) ], [undef, [1, 2, 3], 1], 'test step( [scalar, scalar, scalar] )' );

$reverse_flow = [1, \&fun1];
is_deeply( [ step( $reverse_flow ) ] , [\&fun1, undef, undef], 'test step( [scalar, fun] )' );
is_deeply( $reverse_flow , [ 1 ] , 'test flow after step( [scalar, fun] )' );

$reverse_flow = [\&fun1, 3, 2, 1];
is_deeply( [ step( $reverse_flow ) ], [\&fun1, [1, 2, 3], 1], 'test step( [fun, @scalar] )' );

$reverse_flow = [\&fun1, 5, 4, \&fun1, 3, 2, 1];
step( $reverse_flow );
is_deeply( $reverse_flow , [ \&fun1, 5, 4 ] , 'test flow after step( [fun, @scalar] )' );




sub fun1 {
  my ( $self, $args, $flow ) = @_;
  #my $obj = shift @$args;

  print "fun1: ", Dumper( $args );

  return 'ccc';
}

