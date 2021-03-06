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
# Autogenerated by DBIx::SearchBuilder factory (by <jesse@bestpractical.com>)
# WARNING: THIS FILE IS AUTOGENERATED. ALL CHANGES TO THIS FILE WILL BE LOST.  
# 
# !! DO NOT EDIT THIS FILE !!
#


=head1 NAME

RT::FM::ObjectTopic


=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=cut

no warnings 'redefine';
package RT::FM::ObjectTopic;
use RT::FM::Record; 
use RT::FM::Topic;


use base qw( RT::FM::Record );

sub _Init {
  my $self = shift; 

  $self->Table('FM_ObjectTopics');
  $self->SUPER::_Init(@_);
}





=item Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  int(11) 'Topic'.
  varchar(64) 'ObjectType'.
  int(11) 'ObjectId'.

=cut




sub Create {
    my $self = shift;
    my %args = ( 
                Topic => '0',
                ObjectType => '',
                ObjectId => '0',

		  @_);
    $self->SUPER::Create(
                         Topic => $args{'Topic'},
                         ObjectType => $args{'ObjectType'},
                         ObjectId => $args{'ObjectId'},
);

}



=item id

Returns the current value of id. 
(In the database, id is stored as int(11).)


=cut


=item Topic

Returns the current value of Topic. 
(In the database, Topic is stored as int(11).)



=item SetTopic VALUE


Set Topic to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Topic will be stored as a int(11).)


=cut


=item TopicObj

Returns the Topic Object which has the id returned by Topic


=cut

sub TopicObj {
	my $self = shift;
	my $Topic =  RT::FM::Topic->new($self->CurrentUser);
	$Topic->Load($self->Topic());
	return($Topic);
}

=item ObjectType

Returns the current value of ObjectType. 
(In the database, ObjectType is stored as varchar(64).)



=item SetObjectType VALUE


Set ObjectType to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectType will be stored as a varchar(64).)


=cut


=item ObjectId

Returns the current value of ObjectId. 
(In the database, ObjectId is stored as int(11).)



=item SetObjectId VALUE


Set ObjectId to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectId will be stored as a int(11).)


=cut



sub _CoreAccessible {
    {
     
        id =>
		{read => 1, type => 'int(11)', default => ''},
        Topic => 
		{read => 1, write => 1, type => 'int(11)', default => '0'},
        ObjectType => 
		{read => 1, write => 1, type => 'varchar(64)', default => ''},
        ObjectId => 
		{read => 1, write => 1, type => 'int(11)', default => '0'},

 }
};


        eval "require RT::FM::ObjectTopic_Overlay";
        if ($@ && $@ !~ /^Can't locate/) {
            die $@;
        };

        eval "require RT::FM::ObjectTopic_Local";
        if ($@ && $@ !~ /^Can't locate/) {
            die $@;
        };




=head1 SEE ALSO

This class allows "overlay" methods to be placed
into the following files _Overlay is for a System overlay by the original author,
while _Local is for site-local customizations.  

These overlay files can contain new subs or subs to replace existing subs in this module.

If you'll be working with perl 5.6.0 or greater, each of these files should begin with the line 

   no warnings qw(redefine);

so that perl does not kick and scream when you redefine a subroutine or variable in your overlay.

RT::FM::ObjectTopic_Overlay, RT::FM::ObjectTopic_Local

=cut


1;
