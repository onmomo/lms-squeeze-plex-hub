#!/usr/bin/perl
# Updates a plugin repository XML file with new version, SHA, and URL.
# Heavily inspired by https://github.com/philippe44/lms-deezer/blob/main/repo/release.pl 🙏
use strict;
use warnings;

use XML::Simple;
use File::Basename;
use Digest::SHA;

my $repofile = $ARGV[0];
my $version = $ARGV[1];
my $zipfile = $ARGV[2];
my $url = $ARGV[3];

print "Inputs: repo=$repofile version=$version zip=$zipfile url=$url\n";

my $repo = XMLin($repofile, ForceArray => 1, KeepRoot => 0, KeyAttr => 0, NoAttr => 0);
print "Loaded repo XML from $repofile\n";

$repo->{plugins}[0]->{plugin}[0]->{version} = $version;
print "Updated plugin version to $version\n";

open (my $fh, "<", $zipfile) or die "Cannot open $zipfile: $!";
binmode $fh;
print "Opened zipfile $zipfile for reading\n";

my $digest = Digest::SHA->new;
$digest->addfile($fh);
close $fh;
my $sha = $digest->hexdigest;
$repo->{plugins}[0]->{plugin}[0]->{sha}[0] = $sha;
print "Computed SHA: $sha\n";

$url .= "/$zipfile" unless $url =~ m{/$zipfile$};
$repo->{plugins}[0]->{plugin}[0]->{url}[0] = $url;
print "Updated plugin URL to $url\n";

XMLout($repo, RootName => 'extensions', NoSort => 1, XMLDecl => 1, KeyAttr => '', OutputFile => $repofile, NoAttr => 0);
print "Wrote updated repository XML to $repofile\n";
