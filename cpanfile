requires 'URI';
requires 'XML::Simple';
requires 'Devel::Cover';
requires 'Devel::Cover::Report::Html';
requires 'Devel::Cover::Report::Lcov';

on 'test' => sub {
  requires 'Test::More';
  requires 'Test::MockModule';
};
