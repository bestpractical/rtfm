# BEGIN LICENSE BLOCK
# 
#  Copyright (c) 2002 Jesse Vincent <jesse@bestpractical.com>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of version 2 of the GNU General Public License 
#  as published by the Free Software Foundation.
# 
#  A copy of that license should have arrived with this
#  software, but in any event can be snarfed from www.gnu.org.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
# END LICENSE BLOCK

use strict;

no warnings qw/redefine/;

use RT::FM;
use RT::FM::ArticleCollection;
use RT::FM::CustomField;
use RT::FM::Class;
use RT::Links;
use RT::URI::fsck_com_rtfm;


use vars qw/$RIGHTS/;

# {{{ This object provides ACLs

$RIGHTS = {
    SeeQueue            => 'Can this principal see this queue',       # loc_pair
    AdminQueue          => 'Create, delete and modify queues',        # loc_pair
    ShowACL             => 'Display Access Control List',             # loc_pair
    ModifyACL           => 'Modify Access Control List',              # loc_pair
    ModifyQueueWatchers => 'Modify the queue watchers',               # loc_pair
    AdminCustomFields   => 'Create, delete and modify custom fields', # loc_pair
    ModifyTemplate      => 'Modify Scrip templates for this queue',   # loc_pair
    ShowTemplate        => 'Display Scrip templates for this queue',  # loc_pair

    ModifyScrips => 'Modify Scrips for this queue',                   # loc_pair
    ShowScrips   => 'Display Scrips for this queue',                  # loc_pair

    ShowTicket         => 'Show ticket summaries',                    # loc_pair
    ShowTicketComments => 'Show ticket private commentary',           # loc_pair

    Watch => 'Sign up as a ticket Requestor or ticket or queue Cc',   # loc_pair
    WatchAsAdminCc  => 'Sign up as a ticket or queue AdminCc',        # loc_pair
    CreateTicket    => 'Create tickets in this queue',                # loc_pair
    ReplyToTicket   => 'Reply to tickets',                            # loc_pair
    CommentOnTicket => 'Comment on tickets',                          # loc_pair
    OwnTicket       => 'Own tickets',                                 # loc_pair
    ModifyTicket    => 'Modify tickets',                              # loc_pair
    DeleteTicket    => 'Delete tickets'                               # loc_pair

};

# TODO: This should be refactored out into an RT::ACLedObject or something
# stuff the rights into a hash of rights that can exist.

foreach my $right ( keys %{$RIGHTS} ) {
    $RT::ACE::LOWERCASERIGHTNAMES{ lc $right } = $right;
}


=head2 AvailableRights

Returns a hash of available rights for this object. The keys are the right names and the values are a description of what t
he rights do

=cut

sub AvailableRights {
    my $self = shift;
    return($RIGHTS);
}


# }}}


# {{{ Create


=item Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(200) 'Name'.
  varchar(200) 'Summary'.
  int(11) 'Content'.
  Class ID  'Class'

  A paramhash called  'CustomFields', which contains 
  arrays of values for each custom field you want to fill in.
  Arrays aRe ordered. 



=begin testing

use_ok(RT::FM::Article);
use_ok(RT::FM::Class);

my $user = RT::CurrentUser->new('root');

my $class = RT::FM::Class->new($user);


my ($id, $msg) = $class->Create(Name =>'ArticleTest');
ok ($id, $msg);



my $article = RT::FM::Article->new($user);
ok (UNIVERSAL::isa($article, 'RT::FM::Article'));
ok (UNIVERSAL::isa($article, 'RT::FM::Record'));
ok (UNIVERSAL::isa($article, 'RT::Record'));
ok (UNIVERSAL::isa($article, 'DBIx::SearchBuilder::Record'));


($id, $msg) = $article->Create( Class => 'ArticleTest', Summary => "ArticleTest");
ok ($id, $msg);
$article->Load($id);
is ($article->Summary, 'ArticleTest');
my $at = RT::FM::Article->new($RT::SystemUser);
$at->Load($id);
is ($at->id , $id);
is ($at->Summary, $article->Summary);


=end testing


=cut




sub Create {
    my $self = shift;
    my %args = ( 
                Name => undef,
                Summary => undef,
                Class => undef,
                CustomFields => { },
		  @_);

    my $class = RT::FM::Class->new($RT::SystemUser);
    $class->Load($args{'Class'});
    unless ($class->Id) {
        return(0,$self->loc('Invalid Class'));
    }

    $RT::Handle->BeginTransaction();
    my ($id, $msg) =  $self->SUPER::Create(
                         Name => $args{'Name'},
                         Class => $class->Id,
                         Summary => $args{'Summary'},
			);
    unless ($id) {
        $RT::Handle->Rollback();
        return (undef, $msg);
    }

    my %cfs  = %{$args{'CustomFields'}};


    foreach my $cf (keys %cfs) {
        # Process custom field values
    }

    # We override the URI lookup. the whole reason
    # we have a URI column is so that joins on the links table
    # aren't expensive and stupid
    $self->SetURI($self->URI);

    $RT::Handle->Commit();

    return($id, $msg);
}

# }}}

# {{{ Children

=item Children

Returns an RT::FM::ArticleCollection object which contains
all articles which have this article as their parent.  This 
routine will not recurse and will not find grandchildren, great-grandchildren, uncles, aunts, nephews or any other such thing.  

=cut

sub Children {
    my $self = shift;
    my $kids = new RT::FM::ArticleCollection($self->CurrentUser);
    $kids->LimitToParent($self->Id);
    return($kids);
}

# }}}

# {{{ sub AddLink

=head2 AddLink

Takes a paramhash of Type and one of Base or Target. Adds that link to this tick
et.

=begin testing

=end testing



=cut

sub AddLink {
    my $self = shift;
    my %args = (
        Target => '',
        Base   => '',
        Type   => 'RefersTo',
        Silent => undef,
        @_
    );

    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    if ( $args{'Base'} and $args{'Target'} ) {
        $RT::Logger->debug(
"$self tried to delete a link. both base and target were specified\n"
        );
        return ( 0, $self->loc("Can't specifiy both base and target") );
    }
    elsif ( $args{'Base'} ) {
        $args{'Target'} = $self->URI();
    }
    elsif ( $args{'Target'} ) {
        $args{'Base'} = $self->URI();
    }
    else {
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    # {{{ We don't want references to ourself
    if ( $args{'Base'} eq $args{'Target'} ) {
        $RT::Logger->debug("Trying to link ".$args{'Base'} . " to ".$args{'Target'});
        return ( 0, $self->loc("Can't link a ticket to itself") );
    }

    # }}}

    # If the base isn't a URI, make it a URI. 
    # If the target isn't a URI, make it a URI. 

    # {{{ Check if the link already exists - we don't want duplicates
    my $old_link = new RT::Link( $self->CurrentUser );
    $old_link->LoadByParams( Base=> $args{'Base'}, Type => $args{'Type'}, Target =>$args{'Target'} );
    if ( $old_link->Id ) {
        $RT::Logger->debug("$self Somebody tried to duplicate a link");
        return ( $old_link->id, $self->loc("Link already exists"), 0 );
    }

    # }}}

    # Storing the link in the DB.
    my $link = RT::Link->new( $self->CurrentUser );
    my ($linkid) = $link->Create(
        Target => $args{Target},
        Base   => $args{Base},
        Type   => $args{Type}
    );



    unless ($linkid) {
        return ( 0, $self->loc("Link could not be created") );
    }

    my $TransString =
      "Ticket $args{'Base'} $args{Type} ticket $args{'Target'}.";

    # Don't write the transaction if we're doing this on create
    if ( $args{'Silent'} ) {
        return ( 1, $self->loc( "Link created ([_1])", $TransString ) );
    }
    else {

        #Write the transaction
        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
            Type      => 'AddLink',
            Field     => $args{'Type'},
            Data      => $TransString,
            TimeTaken => 0
        );
        return ( $Trans, $self->loc( "Link created ([_1])", $TransString ) );
    }

}

# }}}

# {{{ Links

=head2 Links

The following routines deal with links and relationships between articles and
RT tickets.


=begin testing

my ($id, $msg);



my $article_a = RT::FM::Article->new($RT::SystemUser);
($id, $msg) = $article_a->Create( Class => 'ArticleTest', Summary => "ArticleTestlink1");
ok($id,$msg);

my $article_b = RT::FM::Article->new($RT::SystemUser);
($id, $msg) = $article_b->Create( Class => 'ArticleTest', Summary => "ArticleTestlink2");
ok($id,$msg);

# Create a link between two articles
($id, $msg) = $article_a->AddLink( Type => 'RefersTo', Target => $article_b->URI);
ok($id,$msg);

# Make sure that Article B's "ReferredToBy" links object refers to to this article"
my $refers_to_b = $article_b->ReferredToBy;
ok($refers_to_b->Count == 1, "Found one thing referring to b");
my $first = $refers_to_b->First;
ok ($first->isa(RT::Link), "IT's an RT link - ref ".ref($first) );
ok ($first->TargetObj->Id == $article_b->Id, "Its target is B");

ok($refers_to_b->First->BaseObj->isa('RT::FM::Article'), "Yep. its an article");


# Make sure that Article A's "RefersTo" links object refers to this article"
my $referred_To_by_a = $article_a->RefersTo;
ok($referred_To_by_a->Count == 1, "Found one thing referring to b".$referred_To_by_a->Count);
my $first = $referred_To_by_a->First;
ok ($first->isa(RT::Link), "IT's an RT link - ref ".ref($first) );
ok ($first->TargetObj->Id == $article_b->Id, "Its target is B - " . $first->TargetObj->Id);
ok ($first->BaseObj->Id == $article_a->Id, "Its base is A");

ok($referred_To_by_a->First->BaseObj->isa('RT::FM::Article'), "Yep. its an article");

# Delete the link
($id, $msg) = $article_a->DeleteLink(Type => 'RefersTo', Target => $article_b->URI);
ok($id,$msg);


# Create an Article A RefersTo Ticket 1 from the RTFM side
use RT::Ticket;


my $tick = RT::Ticket->new($RT::SystemUser);
$tick->Load('1');
ok ($tick->Id, "Found ticket 1");
ok ($tick->URI =~ /\/1$/, "The ticket uri ends in /1");
($id, $msg) = $article_a->AddLink(Type => 'RefersTo', Target => $tick->URI);
ok($id,$msg);

# Find all tickets whhich refer to Article A

use RT::Tickets;
use RT::Links;

my $tix = RT::Tickets->new($RT::SystemUser);
ok ($tix, "Got an RT::Tickets object");
ok ($tix->LimitReferredToBy($article_a->URI)); 
ok ($tix->Count == 1, "Found one ticket linked to that article");
ok ($tix->First->Id == 1, "It's even the right one");



# Find all articles which refer to Ticket 1
use RT::FM::ArticleCollection;

my $articles = RT::FM::ArticleCollection->new($RT::SystemUser);
ok($articles->isa('RT::FM::ArticleCollection'), "Created an article collection");
ok($articles->isa('RT::FM::SearchBuilder'), "Created an article collection");
ok($articles->isa('RT::SearchBuilder'), "Created an article collection");
ok($articles->isa('DBIx::SearchBuilder'), "Created an article collection");
ok($tick->URI, "The ticket does still have a URI");
$articles->LimitRefersTo($tick->URI);

is($articles->Count(), 1);
is ($articles->First->Id, $article_a->Id);
is ($articles->First->URI, $article_a->URI);



# Find all things which refer to ticket 1 using the RT API.

my $tix2 = RT::Links->new($RT::SystemUser);
ok ($tix2->isa('RT::Links'));
ok($tix2->LimitRefersTo($tick->URI));
ok ($tix2->Count == 1);
is ($tix2->First->BaseObj->URI ,$article_a->URI);



# Delete the link from the RT side.
my $t2 = RT::Ticket->new($RT::SystemUser);
$t2->Load(1);
($id, $msg)= $t2->DeleteLink( Base => $article_a->URI, Type => 'RefersTo');
ok ($id, $msg . " - $id");

# it's actually deleted
my $tix3 = RT::Links->new($RT::SystemUser);
$tix3->LimitReferredToBy($tick->URI);
ok ($tix3->Count == 0);

# Recreate the link from teh RT site
($id, $msg) = $t2->AddLink( Base => $article_a->URI, Type => 'RefersTo');
ok ($id, $msg);

# Find all tickets whhich refer to Article A

# Find all articles which refer to Ticket 1


=end testing



=cut


# {{{ sub DeleteLink 

=head2 DeleteLink

Delete a link. takes a paramhash of Base, Target and Type.
Either Base or Target must be null. The null value will 
be replaced with this ticket\'s id

=cut 

sub DeleteLink {
    my $self = shift;
    my %args = (
        Base   => undef,
        Target => undef,
        Type   => undef,
        @_
    );

    #check acls
    unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
        return ( 0, $self->loc('Permission Denied'))
    }

    #we want one of base and target. we don't care which
    #but we only want _one_

    if ( $args{'Base'} and $args{'Target'} ) {
        $RT::Logger->debug("$self ->_DeleteLink. got both Base and Target\n");
        return ( 0, $self->loc("Can't specifiy both base and target") );
    }
    elsif ( $args{'Base'} ) {
        $args{'Target'} = $self->URI();
    }
    elsif ( $args{'Target'} ) {
        $args{'Base'} = $self->URI();
    }
    else {
        $RT::Logger->debug("$self: Base or Target must be specified\n");
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    my $link = new RT::Link( $self->CurrentUser );
    $RT::Logger->debug( "Trying to load link: " . $args{'Base'} . " " . $args{'Type'} . " " . $args{'Target'} . "\n" ); 
    $link->LoadByParams( Base=> $args{'Base'}, Type => $args{'Type'}, Target => $args{'Target'} );

    #it's a real link. 
    if ( $link->id ) {
        my $linkid = $link->Id;
        $RT::Logger->debug( "We're going to delete link " . $link->id . "\n" );
        $link->Delete();

        my $TransString = "Ticket $args{'Base'} no longer $args{Type} ticket $args{'Target'}.";
        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction( Type      => 'DeleteLink', Field     => $args{'Type'}, Data      => $TransString, );

        return ( $linkid, $self->loc("Link deleted ([_1])", $TransString));
    }


    #if it's not a link we can find
    else {
        $RT::Logger->debug("Couldn't find that link\n");
        return ( 0, $self->loc("Link not found") );
    }
}

# }}}

# {{{ sub RefersTo

=head2 RefersTo

Return an RT::Links object which contains pointers to all the things 
which this article refers to

=cut


sub RefersTo {
    my $self = shift;
    return $self->_Links(Field => 'Base', Type => 'RefersTo');

}
# }}}

# {{{ sub ReferredToBy

=head2 ReferredToBy

Return an RT::Links object which contains pointers to all the things 
which refer to this article.

=cut


sub ReferredToBy {
    my $self = shift;
    return $self->_Links(Field => 'Target', Type => 'RefersTo');

}

# }}}

# {{{ sub _Links 


sub _Links {
    my $self = shift;
    my %args = (    Field => undef,
                    Type => undef,
                @_);


        my $search = new RT::Links( $self->CurrentUser );
        if ( $self->CurrentUserHasRight('ShowTicket') ) {

            $search->Limit( FIELD => $args{'Field'}, VALUE => $self->URI );
            $search->Limit( FIELD => 'Type', VALUE => $args{'Type'} ) if ($args{'Type'});
        }
    return ( $search );
}

# }}} 




# }}}


# {{{ sub URI 

=head2 URI

Returns this article's URI


=begin testing

my ($id,$msg);
my $art = RT::FM::Article->new($RT::SystemUser);
($id, $msg) = $art->Create (Class => 'ArticleTest');
ok ($id,$msg);

ok($art->URI);
ok($art->__Value('URI') eq $art->URI, "The uri in the db is set correctly");


=end testing

         
=cut

sub URI {
    my $self = shift;
    my $uri = RT::URI::fsck_com_rtfm->new($self->CurrentUser);
    return($uri->URIForObject($self));
}

# }}}


# {{{ sub URIObj 

=head2 URIObj

Returns this article's URI


=begin testing

my ($id,$msg);
my $art = RT::FM::Article->new($RT::SystemUser);
($id, $msg) = $art->Create (Class => 'ArticleTest');
ok ($id,$msg);

ok($art->URIObj);
ok($art->__Value('URI') eq $art->URIObj->URI, "The uri in the db is set correctly");


=end testing

         
=cut

sub URIObj {
    my $self = shift;
    my $uri = RT::URI->new($self->CurrentUser);
    $uri->FromObject($self);
    return($uri);
}

# }}}

# {{{ Custom Fields

=head2 Custom Fields

The following routines deal with custom fields and their values

=cut

# {{{ CustomFieldValues

=item CustomFieldValues CUSTOMFIELD_ID

Returns an RT::FM::CustomFieldObjectValueCollection object containing
the values of CustomField CUSTOMFIELDID for this Article


=cut

sub CustomFieldValues {
    my $self = shift;
    my $customfield = shift;
    
    my $cfovc = new RT::FM::ArticleCFValueCollection($self->CurrentUser);
    $cfovc->LimitToArticle($self->Id);
    $cfovc->LimitToCustomField($customfield);
    return ($cfovc);
}

# }}}

# {{{ AddCustomFieldValue

=item AddCustomFieldValue { Field => FIELD, Content => VALUE }

VALUE can either be a CustomFieldValue object or a string.
FIELD can be a CustomField object OR a CustomField ID.


Adds VALUE as a value of CustomField FIELD.  If this is a single-value custom field,
deletes the old value. 
If VALUE isn't a valid value for the custom field, returns 
(0, 'Error message' ) otherwise, returns (1, 'Success Message')


=begin testing


my $art = RT::FM::Article->new($RT::SystemUser);
my ($id,$msg) =$art->Create(Class => 'ArticleTest');
ok ($id, $msg);

my $cf = RT::FM::CustomField->new($RT::SystemUser);
($id, $msg) =$cf->Create(Name => "Test", Type => "SelectMultiple");
ok ($id, $msg);
($id, $msg) = $cf->AddValue(Name => "Test1");
ok ($id, $msg);

($id, $msg) = $cf->AddValue(Name => "Testy");
ok ($id, $msg);

($id, $msg )= $cf->AddToClass('ArticleTest');
ok ($id, $msg);

$id = $cf->ValidForClass('ArticleTest');
ok ($id, "This cf is good for the class 'ArticleTest'");
$id = $cf->ValidForClass($art->ClassObj->Name);
ok ($id, "This cf is good for the class ".$art->ClassObj->Name);

($id, $msg) = $art->AddCustomFieldValue( Field => "Test", Content => "Test1");
ok ($id, $msg);
($id, $msg) = $art->AddCustomFieldValue( Field => "Test", Content => "Test1");
ok (!$id, "Can add a duplicate value to a custom field that's a 'select multiple' - $msg");

($id, $msg) = $art->AddCustomFieldValue( Field => "Test", Content => "Testy");
ok ($id, $msg);


($id, $msg) = $art->AddCustomFieldValue( Field => "Test", Content => "TestFroboz");
ok (!$id, "Can't add a non-existent value to a custom field that's a 'select multiple' - $msg");

=end testing




=cut

sub AddCustomFieldValue {
    my $self = shift;
  #  unless ( $self->CurrentUserHasRight('ModifyTicket') ) {
  #      return ( 0, $self->loc("Permission Denied") );
  #  }
    $self->_AddCustomFieldValue(@_);
}

sub _AddCustomFieldValue {
    my $self = shift;
    my %args = ( Field             => undef,
                 Content            => undef,
                 RecordTransaction => 1,
                 @_ );

    # {{{ Get the custom field we're talking about

    my $cf = RT::FM::CustomField->new( $self->CurrentUser );
    if ( UNIVERSAL::isa( $args{'Field'}, "RT::FM::CustomField" ) ) {
        $cf->Load( $args{'Field'}->id );
    }
    else {
        $cf->Load( $args{'Field'} );
    }


    unless ($cf->ValidForClass($self->__Value('Class')) ) {
        return( 0, $self->loc("Custom field [_1] not valid for that article", $args{'Field'}));
    }

    unless ( $cf->Id ) {
        return ( 0,
                 $self->loc( "Custom field [_1] not found", $args{'Field'} ) );
    }
    # }}}



    # Load up a ArticleCFValueCollection object for this custom field 
    my $values = $cf->ValuesForArticle( $self->id );


    # If the custom field only accepts a single value, delete the existing
    # value and record a "changed from foo to bar" transaction
    if ( $cf->SingleValue ) {
        # {{{ We need to whack any old values here.  In most cases, the custom field should
        # only have one value to delete.  In the pathalogical case, this custom field
        # used to be a multiple and we have many values to whack....
        my $cf_values = $values->Count;

        if ( $cf_values > 1 ) {
            my $i = 0;   #We want to delete all but the last one, so we can then
                 # execute the same code to "change" the value from old to new
            while ( my $value = $values->Next ) {
                $i++;
                if ( $i < $cf_values ) {
                    my $old_value = $value->Content;
                    my ( $val, $msg ) = $cf->DeleteValueForArticle(
                                                      Article => $self->Id,
                                                      Content => $value->Content
                    );
                    unless ($val) {
                        return ( 0, $msg );
                    }
                    my ( $TransactionId, $Msg, $TransactionObj ) =
                      $self->_NewTransaction( Type     => 'CustomField',
                                              Field    => $cf->Id,
                                              OldValue => $old_value );
                }
            }
        }
        # }}}


        # {{{ Add a new custom field value
        my $value = $cf->ValuesForArticle( $self->Id )->First;
        my $old_value;
        if ( $cf_values == 1 ) {
            $old_value = $value->Content();
        }

        my ( $new_value_id, $value_msg ) = $cf->AddValueForArticle(
                                                       Article  => $self->Id,
                                                       Content => $args{'Content'}
        );

     
        unless ($new_value_id) {
            return ( 0, $self->loc( "Could not add new custom field value for Article. [_1] ", $value_msg ) );
        }
        # }}}

        # {{{ Kill the old value
        my $new_value = RT::FM::ArticleCFValue->new( $self->CurrentUser );
        $new_value->Load($new_value_id);

        # now that adding the new value was successful, delete the old one
        if ( defined $old_value ) {
            my ( $val, $msg ) = $cf->DeleteValueForArticle(Article => $self->Id,
                                                           Content => $old_value
            );
            unless ($val) {
                return ( 0, $msg );
            }

        }
        # }}} 

        # {{{ Record the "Changed" transaction
        if ( $args{'RecordTransaction'} ) {
            my ( $TransactionId, $Msg, $TransactionObj ) =
              $self->_NewTransaction( Type     => 'CustomField',
                                      Field    => $cf->Id,
                                      OldValue => $old_value,
                                      NewValue => $new_value->Content );
        }
        return ( 1, $self->loc( "Custom field value changed from [_1] to [_2]", $old_value, $new_value->Content ) );
        # }}}
    }

    # otherwise, just add a new value and record "new value added"
    else {

        # {{{ Add a custom field value
        my ($new_value_id, $new_value_msg) = $cf->AddValueForArticle( Article  => $self->Id, Content => $args{'Content'});

        unless ($new_value_id) {
            return ( 0, $self->loc( "Could not add new custom field value for Article. [_1]", $new_value_msg) );
        }
        # }}}

        # {{{ Record a tranaction
        if ( $args{'RecordTransaction'} ) {
            my ( $TransactionId, $Msg, $TransactionObj ) =
              $self->_NewTransaction( Type     => 'CustomField',
                                      Field    => $cf->Id,
                                      NewValue => $args{'Content'} );
            unless ($TransactionId) {
                return ( 0, $self->loc( "Couldn't create a transaction: [_1]", $Msg) );
            }
        }
        return ( $new_value_id , $self->loc( "[_1] added as a value for [_2]", $args{'Content'}, $cf->Name ) );

        # }}}
    }

}

# }}}

# {{{ DeleteCustomFieldValue

=item DeleteCustomFieldValue { CustomField => undef, Content => undef } 
  
  Takes a paramhash. Deletes the Keyword denoted by the I<Keyword> parameter from this
  ticket's object keywords.

=cut

sub DeleteCustomFieldValue {
    my $self = shift;
    my %args = ( Content => undef,
		 Field => undef,
		 @_ );

    #Load up the ObjectKeyword we\'re talking about
    my $CFObjectValue = new RT::FM::ArticleCFValue($self->CurrentUser);
    $CFObjectValue->LoadByCols( Content  => $args{'Content'},
			        CustomField => $args{'Field'},
			        Article => $self->id()
			      );
    
    #if we can\'t find it, bail
    unless ($CFObjectValue->id) {
	return (undef, $self->loc("Couldn't load custom field [_1] value [_2] while trying to delete it.",$args{'Field'}, $args{'Content'}));
    };
    
    #record transaction here.
   
    $CFObjectValue->Delete();
   
    # TODO XXX error check
    return (1, $self->loc("Value [_1] deleted from custom field [_2].",$CFObjectValue->Content, $args{'Field'}));
    
}

# }}}


# }}}

# {{{ CurrentUserHasRight

=head2 CurrentUserHasRight

NOT IMPLEMENTED YET

=cut

sub CurrentUserHasRight {
    my $self = shift;
    $RT::Logger->crit("$self CurrentUserHasRight not implemented");
    return 1;
}


# }}}

# {{{ _NewTransaction

=head2 _NewTransaction

NOT IMPLEMENTED YET

=cut

sub _NewTransaction {
    my $self = shift;
    $RT::Logger->crit("$self _NewTransaction not implemented");
    return 1;
}


# }}}
1;