
use strict;
no warnings qw/redefine/;


sub Description {
    my $self = shift;
    if ($self->Type eq 'Core') { 
        return ($self->loc("[_1] changed from '[_2]' to '[_3]'",$self->Field , $self->OldContent, $self->NewContent));

    } elsif ($self->Type eq 'Link') {
    if ($self->NewContent) {
        return ($self->loc("This article now [_1] '[_2]'",$self->Field , $self->NewContent));
    } else {
        return ($self->loc("This article no longer [_1] '[_2]'",$self->Field , $self->OldContent));

    }


    } elsif ($self->Type eq 'Custom') {
        my $cf = RT::FM::CustomField->new($self->CurrentUser);
        $cf->Load($self->Field);
        
        if ($self->NewContent && $self->OldContent) {
            return $self->loc("[_1] value '[_2]' changed to '[_3]'",$cf->Name, $self->OldContent, $self->NewContent);


        } elsif ($self->NewContent) {
            return $self->loc("[_1] value '[_2]' added",$cf->Name, $self->NewContent);
        
        } elsif ($self->OldContent) {
            return $self->loc("[_1] value '[_2]' delete",$cf->Name, $self->OldContent);

        }
    } elsif ($self->Type eq 'Create') { 
            return $self->loc("Article created");
    }
     
}

1;