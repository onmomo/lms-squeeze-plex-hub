requires 'URI';
requires 'XML::Simple';
requires 'Devel::Cover';
requires 'JSON::MaybeXS';
requires 'Devel::Cover::Report::Json';

on 'test' => sub {
  requires 'Test::More';
  requires 'Test::MockModule';
};
