package MPGA;

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use MPGA ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
  flow step chunk
);

our $VERSION = '0.01';


sub flow {
  my $flow = shift;
  @$flow = reverse @$flow;

  while(scalar @$flow) {
    step( $flow );
  }

  return;
}


sub step {
  my $flow = shift;

  if(scalar @$flow) {
    my ( $fun, $args, $obj ) = chunk( $flow );
    if( $fun ) {
      my $res = $fun->( $fun, $args, $flow );
      if( !defined $res ) {
        push @$flow, $obj if scalar @$flow;
      }
      elsif( ref( $res ) eq 'ARRAY' ) {
        @$flow = reverse @$res;
      }
      elsif( ref( $res ) eq 'HASH' ) {
        push @$flow, $res;
      }
      elsif( !ref( $res ) ) {
        push @$flow, $res;
      }
      else {
        print "функция хз чо, скорее всего это ошибка!\n";
        print Dumper( $res );
      }
    }
  }

  return;
}


sub chunk {
  my $flow = shift;

  my $args;
  my $fun;
  my $obj;

  return $fun, $args, $obj if !$flow;

  return $fun, $args, $obj if !ref( $flow );


  while(scalar @$flow) {
    my $item = pop @$flow;
    if( ref $item ne 'CODE' ) {
      push @$args, $item;
      $obj = $item if !defined $obj;
    }
    else {
      $fun = $item;
      last;
    }
  }

  return $fun, $args, $obj;
}


# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

MPGA - Perl extension for blah blah blah

=head1 SYNOPSIS

  use MPGA;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for MPGA, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

U-DESKTOP-MJUPRTK\nn, E<lt>nn@nonetE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2021 by U-DESKTOP-MJUPRTK\nn

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.32.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
