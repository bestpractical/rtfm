#!/usr/bin/perl

use warnings;
use strict;

use lib 't/lib';
use RT::FM::Test tests => 43;

use_ok 'RT::FM::System';
my $sys = RT::FM::System->new;
isa_ok $sys, 'RT::FM::System';
is $sys->Id, 1;

use_ok('RT::FM::Class');

my $class = RT::FM::Class->new($RT::SystemUser);
isa_ok($class, 'RT::FM::Class');
isa_ok($class, 'RT::FM::Record');
isa_ok($class, 'RT::Record');


my $name = 'test-'.$$;
my ($id,$msg) = $class->Create( Name =>$name, Description => 'Test class');
ok($id,$msg);
is ($class->Name, $name);
is ($class->Description, 'Test class');



# Test custom fields.

can_ok($class, 'CustomFields');
can_ok($class, 'AddCustomFieldValue');
can_ok($class, 'DeleteCustomFieldValue');
can_ok($class, 'FirstCustomFieldValue');
can_ok($class, 'CustomFieldValues');
can_ok($class, 'CurrentUserHasRight');


# Add a custom field to our class
my $cf = RT::CustomField->new($RT::SystemUser);
isa_ok($cf, 'RT::CustomField');

($id,$msg) = $cf->Create( Name => 'FM::Sample-'.$$,
             Description => 'Test text cf',
             LookupType => RT::FM::Article->CustomFieldLookupType,
             Type => 'Text'
             );



ok($id,$msg);


($id,$msg) = $cf->AddToObject($class);
ok ($id,$msg);


# Does our class have a custom field?

my $cfs = $class->ArticleCustomFields;
isa_ok($cfs, 'RT::CustomFields');
is($cfs->Count, 1, "We only have one custom field");
my $found_cf = $cfs->First;
is ($cf->id, $found_cf->id, "it's the right one");

($id,$msg) = $cf->RemoveFromObject($class);

is($class->ArticleCustomFields->Count, 0, "All gone!");

# Put it back. we want to go forward.

($id,$msg) = $cf->AddToObject($class);
ok ($id,$msg);




use_ok('RT::FM::Article');

my $art = RT::FM::Article->new($RT::SystemUser);
($id,$msg) =$art->Create(Class => $class->id,
             Name => 'Sample'.$$,
             Description => 'A sample article');

ok($id,"Created article ".$id." - " .$msg);

# make sure there is one transaction.

my $txns = $art->Transactions;

is($txns->Count, 1, "One txn");
my $txn = $txns->First;
is ($txn->ObjectType, 'RT::FM::Article');
is ($txn->ObjectId , $id ,  "It's the right article");
is ($txn->Type, 'Create', "It's a create!");


my $art_cfs = $art->CustomFields();
is ($art_cfs->Count, 1, "It has a custom field");
my $values = $art->CustomFieldValues($art_cfs->First);
is ($values->Count, 0);

$art->AddCustomFieldValue(Field => $cf->id, Value => 'Testing');
$values = $art->CustomFieldValues($art_cfs->First->id);

# We added the custom field
is ($values->Count, 1);
is ($values->First->Content, 'Testing', "We added the CF");

is ($art->Transactions->Count,2, "We added a second transaction for the custom field addition");
my $txn2 = $art->Transactions->Last;
is ($txn2->ObjectId, $art->id);
is ($txn2->id, ($txn->id +1));
is ($txn2->Type, 'CustomField');
is($txn2->NewValue, 'Testing');
ok (!$txn2->OldValue, "It had no old value");

1;

