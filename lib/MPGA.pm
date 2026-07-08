package MPGA;

use strict;
use warnings;
use Attribute::Handlers; # Добавлено для поддержки атрибутов
use Data::Dumper;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration use MPGA ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
 
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
  flow flow_ctx step chunk
);

our $VERSION = '0.21';
# данная версия модуля MPGA кардинально отличается от предыдущей 0.08 версии следующим:
#   - изменена логика разбора потока - теперь только прямой порядок следования аргументов,
#     без всяких reverse и pop;
#   - специальный объект для хранения контекста потока;
#   - у функций появился атрибут количества обязательных аргументов.
# однако, модуль спроектирован так, что в нем сохраняется обратная совместимость, и код
# написанный в старом стиле все равно будет работать.


# Реестр для хранения количества обязательных аргументов функций
our %REGISTRY;


# Определение атрибута :MPGAargsNum
# этот атрибут необходим функциям, чтобы указать MPGA сколько аргументов обязательно 
# нужно исполняемой функции, это для удобства работы в новом стиле. основываясь на
# это атрибуте step() предоставит функции именно такой длины массив аргументов @$args.
# исполняемая функция должна иметь примерно такой вид:
# sub fun : MPGAargsNum(3) {
#   my ($self, $args, $flow, $ctx) = @_;
#   my $args1 = shift @$args;
#   my $args2 = shift @$args;
#   my $args3 = shift @$args;
# 
#   .....
#   return;
# }
# данная запись явно дает понять, что это не обычная функция perl, а функция, которая
# написана для исполнения модулем MPGA и ей необходимы 3 обязательных аргумента.
# если же этот атрибут не указан
# sub old_style_fun {
#   my ($self, $args, $flow) = @_;
#   my $args1 = pop @$args;
#   .....
#   return;
# }
# значит функция написана в старом стиле и она сама управляет @$args и контекстом.
sub UNIVERSAL::MPGAargsNum : ATTR(CODE) {
  my ($package, $symbol, $referent, $attr, $argsNum) = @_;

  # Если данные пришли в виде массива, берем первый элемент.
  # Если как обычный скаляр — берем его как есть.
  $REGISTRY{$referent} = ref($argsNum) eq 'ARRAY' ? $argsNum->[0] : $argsNum;
}


# функция flow_ctx() принимает ссылку на массив, и в этом массиве первый
# элемент считается объектом контекста ctx, который будет передан
# во все функции потока. вы можете определять ctx как угодно.
# рекомендую пустой хэш {}, в котором можно будет хранить промежуточные
# состояния функций (естественно надо не забывать их чистить :))
sub flow_ctx {
  my $flow = shift;

  return if !$flow;
  return if ref( $flow ) ne 'ARRAY';
  return if !scalar @$flow;

  # Откусываем первый элемент и сохраняем его как контекст выполнения
  my $ctx = shift @$flow;

  # Передаем чистый поток и контекст дальше в цепочку
  flow( $flow, $ctx );

  return;
}


# функция flow() принимает два аргумента:
# первый аргумент обязательный - ссылка на массив - поток,
# второй аргумент необязательный $ctx - контекст.
# поток разбирается слева направо функцией step() пока не опустошится.
sub flow {
  my $flow = shift;
  my $ctx  = shift; # Принимаем контекст (будет undef, если вызван обычный flow)

  return if !$flow;
  return if ref( $flow ) ne 'ARRAY';

  while(scalar @$flow) {
    step( $flow, $ctx ); # Передаем $ctx в step() на каждом шаге
  }

  return;
}


# функция step() принимает два аргумента:
# первый аргумент обязательный - ссылка на массив - поток,
# второй аргумент необязательный $ctx - контекст.
# поток парсится слева направо с помощью вызова функции chunk()
# в поисках первой ссылки на функцию.
# эта функция заносится в переменную $fun и будет исполняться, а все переменные
# найденные до этой функции заносятся в массив накопленных аргументов @$args.
# таким образом $flow становится короче.
#
# step() принимает поток в прямом порядке
#
# исполняемой функции $fun передаются четыре аргумента:
# sub fun {
#   my ( $self, $args, $flow, $ctx ) = @_;
#   .....
#   return;
# }
#   - $fun - сама эта функция
#   - вторым аргументом идет ссылка на массив аргументов:
#       * если у функции задан атрибут :MPGAargsNum(N) — это ссылка на массив из N
#         ближайших к функции аргументов, которые забрали с конца массива
#         накопленных аргументов
#       * если атрибут не задан — это ссылка на весь массив накопленных аргументов
#   - $flow - остаток потока
#   - $ctx - общий объект контекста (может быть undef)
#
# функция $fun может модифицировать любые свои аргументы
#   - первый аргумент - ссылка на саму себя, модифицировать ее в принципе можно, но не нужно,
#     функция передается сама себе для того, чтобы в случае необходимости она могла
#     рекурсивно возвратить саму себя в поток @$flow
#   - второй аргумент - массив аргументов @$args - аргументы могут относиться к этой функции или
#     к другой, которая идет дальше по потоку, это зависит от того определен ли у функции
#     атрибут MPGAargsNum:
#       - если определен, то в @$args именно MPGAargsNum аргументов, и их можно обрабатывать самым
#         обычным способом через shift.
#       - если не определен, то в @$args возможно не все аргументы относятся к этой функции
#         и обрабатывать их надо осторожно, чтобы не удалить из потока транзитные аргументы.
#         поэтому надо обрабатывать их через pop и получать в обратном порядке с конца.
#   - третий аргумент - поток $flow - тоже может быть модифицирован с целью изменить поток
#     выполнения программы, но так как считается, что рядовая функция не должна знать слишком много,
#     то рекомендую модифицировать поток только в плане прекращения потока в случае ошибки,
#     это достигается обнулением @$flow и возвратом undef, т.е. надо выполнить такой код:
#       @$flow = ();
#       return;
#   - четвертый аргумент - контекст ctx. если поток был определен через функцию flow_ctx, то
#     это первый элемент этого потока - контекст, который должен быть передан всем функциям этого потока.
# 
# исполняемая функция $fun может вернуть
#   - ссылку на массив - в этом случае этот массив должен быть 
#       занесен в конец остатка потока $flow
#   - ссылка на хэш - в этом случае возврат трактуется как объект, который
#       должен быть занесен в конец остатка потока $flow
#   - скаляр - в этом случае возврат трактуется как скаляр, который
#       должен быть занесен в конец остатка потока $flow
#   - undef - в этом случае поток $flow не меняется
#   - во всех других случаях $flow не меняется
#
# после выполнения функции $fun список аргументов @$args может быть не пустым, в
# таком случае он должен быть добавлен в поток @$flow после добавления
# туда результатов работы $fun.
# также надо взять за правило, что функция $fun всегда должна заканчиваться return,
# иначе будет возвращен результат последнего оператора функции.
# таким образом функция всегда должна заканчиваться как-то так:
#    return [...];   - ссылка на массив
#    return {...};   - ссылка на хэш
#    return $scalar; - скаляр
#    return;         - undef
sub step {
  my $flow = shift;
  my $ctx  = shift; # Принимаем контекст

  return if !$flow;
  return if ref($flow) ne 'ARRAY';

  if(scalar @$flow) {
    my ($fun, $args) = chunk($flow);

    print "args::: ", Dumper($args);

    if ($fun) {
      my $res;

      # Если у функции объявлен атрибут :MPGAargsNum
      if ( exists $REGISTRY{$fun} ) {
        my $argsNum = $REGISTRY{$fun};

        if (scalar @$args < $argsNum) {
          print "Предупреждение: !!!!! аргументов (" . scalar @$args . ") меньше чем требуется ($argsNum)\n";
          $argsNum = scalar @$args;
        }

        # Забираю нужное число аргументов с конца массива $args (они ближе всего к функции)
        # splice физически удаляет их из $args, оставляя там только транзитные элементы
        my @pass_args = splice(@$args, -$argsNum);

        # Передаю стандартный набор аргументов
        $res = $fun->($fun, \@pass_args, $flow, $ctx);

        # Всё, что было в @pass_args, здесь забывается, так как переменная выходит из области видимости
      }
      else {
        # Старый режим совместимости: передаем исходный $args целиком и $ctx четвертым аргументом
        $res = $fun->($fun, $args, $flow, $ctx);
      }

      if( defined $res ) { # $fun вернула что-то определённое, НЕ undef
        if( ref( $res ) eq 'ARRAY' ) { # $fun вернула ссылку на массив
          unshift(@$flow, @$res) if scalar @$res;
        }
        else {
          unshift @$flow, $res;
        }
      }

      # Если в $args еще остались транзитные аргументы — возвращаем их в начало потока
      if (defined $args && scalar @$args) {
        unshift @$flow, @$args;
      }
    }
  }

  return;
}


# функция chunk() принимает только ссылку на массив,
# в котором ищет первую с начала ссылку на функцию, всё, что не является ссылкой на функцию 
# считается аргументом функции и попадает в массив аргментов.
# возвращает массив из двух элементов ( fun, [args] )
#
sub chunk {
  my $flow = shift;

  return if ref( $flow ) ne 'ARRAY';

  my ($fun, $args);

  while(scalar @$flow) {
    my $item = shift @$flow; 
    if( ref $item ne 'CODE' ) {
      push @$args, $item; # Аргументы собираются слева направо в прямом порядке
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

MPGA - Make Perl Great Again - a module that makes it easy 
to write programs in the PERL programming language.

=head1 SYNOPSIS

  use MPGA;

  # --- Вариант 1: Классический flow без общего контекста ---

  sub fun : MPGAargsNum(2) {
    my ($self, $args, $flow) = @_;
    my ($a, $b) = @$args;
    print "Got arguments: $a and $b\n";
  }

  flow( [ "transit_arg", 5, 6, \&fun ] );


  # --- Вариант 2: Использование flow_ctx с общим контекстом ---

  sub step_one : MPGAargsNum(2) {
    my ($self, $args, $flow, $ctx) = @_;
    my ($a, $b) = @$args;
    
    # Сохраняем промежуточный результат в контекст
    $ctx->{sum_result} = $a + $b;
    return;
  }

  sub step_two : MPGAargsNum(0) {
    my ($self, $args, $flow, $ctx) = @_;
    
    # Читаем данные из контекста на следующем шаге
    print "Sum from previous step: $ctx->{sum_result}\n";
    return;
  }

  my $my_context = { sum_result => 0 };

  # Первым элементом массива передаем наш объект контекста
  flow_ctx( [ $my_context, 10, 20, \&step_one, \&step_two ] );


=head1 DESCRIPTION

Something like "Flow driven development".

Flow is a reference to an array of arguments and functions, which.
are sequentially processed by the functions of this module.

With this module you can program something like this:

flow( [
  $args, ... $args, \&fun1,
  $another, ..., $args, \&fun2,
  $more, ..., $args, \&fun3
] );

Or you can share a single state/context across all functions in the pipeline
using flow_ctx():

flow_ctx( [
  $ctx_hash_ref,
  $args, ..., \&fun1,
  $args, ..., \&fun2
] );

=head1 SEE ALSO

https://github.com/nni7/MPGA

=head1 AUTHOR

NN - Nikolay Neustroev

=head1 COPYRIGHT AND LICENSE

Copyright (C) 1997-2026 by NN

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.32.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
