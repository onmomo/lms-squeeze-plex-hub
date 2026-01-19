requires 'URI';
requires 'XML::Simple';
requires 'Devel::Cover';

on 'test' => sub {
  requires 'Test::More';
  requires 'Test::MockModule';
};
