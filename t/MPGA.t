# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl MPGA.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 11;
BEGIN { use_ok('MPGA') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


is_deeply( [ chunk() ], [undef, undef, undef], 'test chunk()' );

my $reverse_flow = undef;
is_deeply( [ chunk( $reverse_flow ) ], [undef, undef, undef], 'test chunk( undef )' );

$reverse_flow = 'aaa';
is_deeply( [ chunk( $reverse_flow ) ], [undef, undef, undef], 'test chunk( scalar )' );

my @reverse_flow = ( 1, 2, 'aaa' );
is_deeply( [ chunk( @reverse_flow ) ], [undef, undef, undef], 'test chunk( array )' );

$reverse_flow = [];
is_deeply( [ chunk( $reverse_flow ) ], [undef, undef, undef], 'test chunk( [] )' );

$reverse_flow = [1];
is_deeply( [ chunk( $reverse_flow ) ], [undef, [1], 1], 'test chunk( [scalar] )' );

$reverse_flow = [3, 2, 1];
is_deeply( [ chunk( $reverse_flow ) ], [undef, [1, 2, 3], 1], 'test chunk( [scalar, scalar, scalar] )' );

$reverse_flow = [1, \&fun1];
is_deeply( [ chunk( $reverse_flow ) ] , [\&fun1, undef, undef], 'test chunk( [scalar, fun] )' );
is_deeply( $reverse_flow , [ 1 ] , 'test flow after chunk( [scalar, fun] )' );

$reverse_flow = [\&fun1, 1];
is_deeply( [ chunk( $reverse_flow ) ], [\&fun1, [1], 1], 'test chunk( [fun, scalar] )' );




sub fun1 {
  my ( $self, $args, $flow ) = @_;
  #my $obj = shift @$args;

  print "fun1: ", Dumper( $args );

  return 'ccc';
}

#my $arr_rev;
#@$arr_rev = reverse @$arr;
#is( chunk( $arr_rev ), (\&fun1, [1], 1), 'test chunk()' );


#$arr = [ \&fun1 ];
#@$arr_rev = reverse @$arr;
#is( chunk( $arr_rev ), (\&fun1, [1], 1), 'test chunk()' );
