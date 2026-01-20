requires 'URI';
requires 'XML::Simple';
requires 'Devel::Cover';
requires 'JSON::MaybeXS';
requires 'Devel::Cover::Report::Json';
requires 'Devel::Cover::Report::Codecov';

on 'test' => sub {
  requires 'Test::More';
  requires 'Test::MockModule';
};
