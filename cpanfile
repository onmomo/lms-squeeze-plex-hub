requires 'URI';
requires 'XML::Simple';
requires 'Devel::Cover';
requires 'Devel::Cover::Report::Html';
requires 'Devel::Cover::Report::Codecov';
requires 'Devel::Cover::Report::Codecovbash';

on 'test' => sub {
  requires 'Test::More';
  requires 'Test::MockModule';
};
