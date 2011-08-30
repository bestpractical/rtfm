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

=head1 NAME

  RT::FM::Record - Base class for RT record objects

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 METHODS

=cut


package RT::FM::Record;
use strict;
use warnings;

use base qw(RT::Record);

use RT::FM;

=head2 Load <id | Name >

Loads an object, either by name or by id. If the value is an integer, it
presumes it's an id.

=cut 

sub Load {
    my $self = shift;
    my $id = shift;

    if ($id =~ /^(\d+)$/) {
        return $self->SUPER::Load($id);
    } else {
        return $self->LoadByCols( Name => $id);
    }
}


=head2 _ClassAccessible

Return this object's _ClassAccessible.

If we're running on RT 3.1 or newer, we need defer to the superclass

If we're running 3.0, dispatch to the CoreAccessible.



=cut

sub _ClassAccessible {
    my $self = shift;

    if ($RT::VERSION =~ /^3.0/)  {
        return $self->_CoreAccessible(); 
    } else  {
        return $self->SUPER::_ClassAccessible(); 
    }
}

sub WikiBase {
  return $RT::WebPath. "/RTFM/Article/Display.html?id=";
}

1;
