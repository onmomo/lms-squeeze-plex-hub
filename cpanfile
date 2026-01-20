requires 'URI';
requires 'XML::Simple';
requires 'Devel::Cover';
requires 'devel-cover-coverage-cobertura';

on 'test' => sub {
  requires 'Test::More';
  requires 'Test::MockModule';
};
