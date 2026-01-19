requires 'URI';
requires 'XML::Simple';
requires 'Devel::Cover';
requires 'Devel::Cover::Report::Codecov::Service::GithubActions';

on 'test' => sub {
  requires 'Test::More';
  requires 'Test::MockModule';
};
