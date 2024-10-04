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

our $VERSION = '0.05';


# функция flow() принимает только ссылку на массив,
# который переворачивается и разбирается с конца функцией step()
# пока не опустошится
#
sub flow {
  my $flow = shift;

  return if !$flow;
  return if ref( $flow ) ne 'ARRAY';

  @$flow = reverse @$flow;

  while(scalar @$flow) {
    step( $flow );
  }

  return;
}


# функция step() принимает только ссылку на массив,
# который парсится с конца с помощью вызова функции chunk()
# в поисках первой ссылки на функцию.
# эта функция заносится в переменную $fun и будет исполняться, а все переменные
# найденные до этой функции заносятся в массив @$args. таким образом
# $flow становится короче.
#
# step() принимает уже перевернутый поток 
#
# исполняемая функция $fun принимает три аргумента:
#   - $fun - сама эта функция
#   - $args - аргументы
#   - $flow - остаток потока
#
# функция $fun может модифицировать любые свои аргументы
#   - модифицировать первый аргумент - ссылку на саму себя в принципе можно, но не нужно 
#     функция передается сама себе для того чтобы в случае необходимости она могла 
#     рекурсивно возвратить саму себя в поток @$flow
#   - второй аргумент - массив аргументов @$args - может относиться к этой функции или 
#     к другой, которая идет дальше по потоку, если функция $fun принимает аргументы, 
#     то массив @$args должен быть модифицирован 
#     в обязательном порядке, аргументы которые функция $fun принимает идут в конце
#     массива @$args и должны быть получены функцией $fun с помощью pop(@$args)
#   - третий аргумент - поток $flow - тоже может быть модифицирован с целью изменить поток
#     выполнения программы, но так как считается, рядовая функция не должна знать слишком много, 
#     то она может модифицировать этот поток только в плане прекращения потока в случае ошибки
#     из этого следует, что если исполняемая функция $fun захочет вообще
#     прервать исполнение потока $flow, то она должна обнулить @$flow
#     и вернуть undef, т.е. выполнить такой код
#       @$flow = ();
#       return;
#     возможно обнуление flow надо будет сделать в анонимной функции, тогда в ней обязательно 
#     надо определить flow из аргументов в начале функции:
#       my ( $self, $args, $flow ) = @_;
#
#     
# исполняемая функция $fun может вернуть
#   - ссылку на массив - в этом случае этот массив должен быть перевернут 
#       и занесен в конец остатка потока $flow
#   - ссылка на хэш - в этом случае возврат трактуется как объект, который
#       должен быть занесен в конец остатка потока $flow
#   - скаляр - в этом случае возврат трактуется как скаляр, который
#       должен быть занесен в конец остатка потока $flow
#   - undef - в этом случае поток $flow не меняется
#   - во всех других случаях $flow не меняется
#
# после выполнения функции $fun список аргументов @$args может быть не пустым, в
# таком случае он должен быть перевернут и добавлен в поток @$flow после добавления 
# туда результатов работы $fun
#
# также надо взять за правило, что функция $fun должна возвращать что-то только
# тогда, когда она хочет что-то добавить в поток исполнения
# она может вернуть 
#   - ссылку на массив - return [...]; тогда этот массив будет инвертирован и добавлен в поток
#   - ссылку на хэш - return {...}; добавляется в поток
#   - скаляр - return $scalar; добавляется в поток
#   - undef - return; - основной случай, ничего не добавляется в поток
#
sub step {
  my $flow = shift;

  return if !$flow;
  return if ref($flow) ne 'ARRAY';

  if(scalar @$flow) {
    my ($fun, $args) = chunk($flow);
    if ($fun) {
      my $res = $fun->($fun, $args, $flow);

      if( defined $res ) { # $fun вернула что-то определённое, НЕ undef
        if( ref( $res ) eq 'ARRAY' ) { # $fun вернула ссылку на массив
          push(@$flow, reverse @$res) if scalar @$res;
        }
        else {
          push @$flow, $res;
        }
      }

      if (scalar @$args) {
        push @$flow, reverse @$args;
      }
    }
  }

  return;
}


# функция chunk() принимает только ссылку на массив,
# в котором ищет первую с конца ссылку на функцию, всё, что не является ссылкой на функцию 
# считается аргументом функции и попадает в массив аргментов.
# возвращает массив из двух элементов ( fun, [args] )
#
sub chunk {
  my $flow = shift;

  return if ref( $flow ) ne 'ARRAY';

  my ($fun, $args);

  while(scalar @$flow) {
    my $item = pop @$flow;
    if( ref $item ne 'CODE' ) {
      push @$args, $item;
    }
    else {
      $fun = $item;
      last;
    }
  }

  return $fun, $args;
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
