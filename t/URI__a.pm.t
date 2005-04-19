#!/usr/bin/perl -w

use Test::More 'no_plan';

use_ok(RT);
RT::LoadConfig();
RT::Init();

use_ok("RT::URI::a");
my $uri = RT::URI::a->new($RT::SystemUser);
ok(ref($uri), "URI object exists");

my $class = RT::FM::Class->new($RT::SystemUser);
$class->Create(Name => 'URItest');
my $article = RT::FM::Article->new($RT::SystemUser);
$article->Create(Name => 'Testing URI parsing',
                 Summary => 'In which this should load',
                 Class => $class->Id);


my $uristr = "a:" . $article->Id;
$uri->ParseURI($uristr);
is(ref($uri->Object), "RT::FM::Article", "Object loaded is an article");
is($uri->Object->Id, $article->Id, "Object loaded has correct ID");
is($uri->URI, 'fsck.com-rtfm://example.com/article/'.$article->Id, 
   "URI object has correct URI string");