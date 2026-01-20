requires 'URI';
requires 'XML::Simple';
requires 'Devel::Cover';
requires 'Devel::Cover::Report::Clover';

on 'test' => sub {
  requires 'Test::More';
  requires 'Test::MockModule';
};
