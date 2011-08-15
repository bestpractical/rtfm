# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2010 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/copyleft/gpl.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}
package RT::FM::Class;

use strict;
use warnings;
no warnings qw/redefine/;

use RT::FM::System;
use RT::CustomFields;
use RT::ACL;
use RT::FM::ArticleCollection;
use RT::FM::ObjectClass;
use RT::FM::ObjectClassCollection;


=head2 Load IDENTIFIER

Loads a class, either by name or by id

=cut

sub Load {
    my $self = shift;
    my $id   = shift ;

    return unless $id;
    if ( $id =~ /^\d+$/ ) {
        $self->SUPER::Load($id);
    }
    else {
        $self->LoadByCols( Name => $id );
    }
}

# {{{ This object provides ACLs

use vars qw/$RIGHTS/;
$RIGHTS = {

    SeeClass            => 'See that this class exists',               #loc_pair
    CreateArticle       => 'Create articles in this class',            #loc_pair
    ShowArticle         => 'See articles in this class',               #loc_pair
    ShowArticleHistory  => 'See articles in this class',               #loc_pair
    ModifyArticle       => 'Modify or delete articles in this class',  #loc_pair
    ModifyArticleTopics => 'Modify topics for articles in this class', #loc_pair
    AdminClass  =>
      'Modify metadata and custom fields for this class',              #loc_pair
    AdminTopics =>
      'Modify topic hierarchy associated with this class',             #loc_pair
    ShowACL             => 'Display Access Control List',              #loc_pair
    ModifyACL           => 'Modify Access Control List',               #loc_pair
    DeleteArticle       => 'Delete articles in this class',            #loc_pair
};

# TODO: This should be refactored out into an RT::ACLedObject or something
# stuff the rights into a hash of rights that can exist.

# Tell RT::ACE that this sort of object can get acls granted
$RT::ACE::OBJECT_TYPES{'RT::FM::Class'} = 1;

foreach my $right ( keys %{$RIGHTS} ) {
    $RT::ACE::LOWERCASERIGHTNAMES{ lc $right } = $right;
}

=head2 AvailableRights

Returns a hash of available rights for this object. The keys are the right names and the values are a description of what t
he rights do

=cut

sub AvailableRights {
    my $self = shift;
    return ($RIGHTS);
}

# }}}


# {{{ Create

=item Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(255) 'Name'.
  varchar(255) 'Description'.
  int(11) 'SortOrder'.

=cut

sub Create {
    my $self = shift;
    my %args = (
        Name        => '',
        Description => '',
        SortOrder   => '0',
        HotList     => 0,
        @_
    );

    unless (
        $self->CurrentUser->HasRight(
            Right  => 'AdminClass',
            Object => $RT::FM::System
        )
      )
    {
        return ( 0, $self->loc('Permission Denied') );
    }

    $self->SUPER::Create(
        Name        => $args{'Name'},
        Description => $args{'Description'},
        SortOrder   => $args{'SortOrder'},
        HotList     => $args{'HotList'},
    );

}

sub ValidateName {
    my $self   = shift;
    my $newval = shift;

    return undef unless ($newval);
    my $obj = RT::FM::Class->new($RT::SystemUser);
    $obj->Load($newval);
    return undef if ( $obj->Id );
    return 1;

}

# }}}

# }}}

# {{{ ACCESS CONTROL

# {{{ sub _Set
sub _Set {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('AdminClass') ) {
        return ( 0, $self->loc('Permission Denied') );
    }
    return ( $self->SUPER::_Set(@_) );
}

# }}}

# {{{ sub _Value

sub _Value {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('SeeClass') ) {
        return (undef);
    }

    return ( $self->__Value(@_) );
}

# }}}

sub CurrentUserHasRight {
    my $self  = shift;
    my $right = shift;

    return (
        $self->CurrentUser->HasRight(
            Right        => $right,
            Object       => ( $self->Id ? $self : $RT::FM::System ),
            EquivObjects => [ $RT::System, $RT::FM::System ]
        )
    );

}

sub ArticleCustomFields {
    my $self = shift;


    my $cfs = RT::CustomFields->new( $self->CurrentUser );
    if ( $self->CurrentUserHasRight('SeeClass') ) {
        $cfs->LimitToGlobalOrObjectId( $self->Id );
        $cfs->LimitToLookupType( RT::FM::Article->CustomFieldLookupType );
        $cfs->ApplySortOrder;
    }
    return ($cfs);
}


=head1 AppliedTo

Returns collection of Queues this Class is applied to.
Doesn't takes into account if object is applied globally.

=cut

sub AppliedTo {
    my $self = shift;

    my ($res, $ocfs_alias) = $self->_AppliedTo;
    return $res unless $res;

    $res->Limit(
        ALIAS     => $ocfs_alias,
        FIELD     => 'id',
        OPERATOR  => 'IS NOT',
        VALUE     => 'NULL',
    );

    return $res;
}

=head1 NotAppliedTo

Returns collection of Queues this Class is not applied to.

Doesn't takes into account if object is applied globally.

=cut

sub NotAppliedTo {
    my $self = shift;

    my ($res, $ocfs_alias) = $self->_AppliedTo;
    return $res unless $res;

    $res->Limit(
        ALIAS     => $ocfs_alias,
        FIELD     => 'id',
        OPERATOR  => 'IS',
        VALUE     => 'NULL',
    );

    return $res;
}

sub _AppliedTo {
    my $self = shift;

    my $res = RT::Queues->new( $self->CurrentUser );

    $res->OrderBy( FIELD => 'Name' );
    my $ocfs_alias = $res->Join(
        TYPE   => 'LEFT',
        ALIAS1 => 'main',
        FIELD1 => 'id',
        TABLE2 => 'FM_ObjectClasses',
        FIELD2 => 'ObjectId',
    );
    $res->Limit(
        LEFTJOIN => $ocfs_alias,
        ALIAS    => $ocfs_alias,
        FIELD    => 'Class',
        VALUE    => $self->id,
    );
    return ($res, $ocfs_alias);
}

=head2 IsApplied

Takes object id and returns corresponding L<RT::ObjectClass>
record if this Class is applied to the object. Use 0 to check
if Class is applied globally.

=cut

sub IsApplied {
    my $self = shift;
    my $id = shift;
    return unless defined $id;
    my $oc = RT::FM::ObjectClass->new( $self->CurrentUser );
    $oc->LoadByCols( Class=> $self->id, ObjectId => $id,
                     ObjectType => ( $id ? 'RT::Queue' : 'RT::FM::System' ));
    return undef unless $oc->id;
    return $oc;
}

=head2 AddToObject OBJECT

Apply this Class to a single object, to start with we support Queues

Takes an object

=cut


sub AddToObject {
    my $self  = shift;
    my $object = shift;
    my $id = $object->Id || 0;

    unless ( $object->CurrentUserHasRight('AdminClass') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    my $queue = RT::Queue->new( $self->CurrentUser );
    if ( $id ) {
        my ($ok, $msg) = $queue->Load( $id );
        unless ($ok) {
            return ( 0, $self->loc('Invalid Queue, unable to apply Class: [_1]',$msg ) );
        }

    }

    if ( $self->IsApplied( $id ) ) {
        return ( 0, $self->loc("Class is already applied to [_1]",$queue->Name) );
    }

    if ( $id ) {
        # applying locally
        return (0, $self->loc("Class is already applied Globally ") )
            if $self->IsApplied( 0 );
    }
    else {
        my $applied = RT::FM::ObjectClassCollection->new( $self->CurrentUser );
        $applied->LimitToClass( $self->id );
        while ( my $record = $applied->Next ) {
            $record->Delete;
        }
    }

    my $oc = RT::FM::ObjectClass->new( $self->CurrentUser );
    my ( $oid, $msg ) = $oc->Create(
        ObjectId => $id, Class => $self->id,
        ObjectType => ( $id ? 'RT::Queue' : 'RT::FM::System' ),
    );
    return ( $oid, $msg );
}


=head2 RemoveFromObject OBJECT

Remove this custom field  for a single object, such as a queue or group.

Takes an object

=cut

sub RemoveFromObject {
    my $self = shift;
    my $object = shift;
    my $id = $object->Id || 0;

    unless ( $object->CurrentUserHasRight('AdminClass') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    my $ocf = $self->IsApplied( $id );
    unless ( $ocf ) {
        return ( 0, $self->loc("This custom field does not apply to that object") );
    }

    # XXX: Delete doesn't return anything
    my ( $oid, $msg ) = $ocf->Delete;
    return ( $oid, $msg );
}

1;

