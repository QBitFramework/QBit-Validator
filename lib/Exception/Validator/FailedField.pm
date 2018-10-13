package Exception::Validator::FailedField;

use base qw(Exception::Validator);

sub import {
    FF->export_to_level(1);
}

sub new {
    my ($this, $text, %data) = @_;

    my $class = ref($this) || $this;

    $text = '' if !defined $text;

    my $self   = {
        %data,
        (
            blessed($text) && $text->isa('Exception')
            ? (text => $text->{'text'}, parent => $text)
            : (text => $text)
        ),
    };

    return bless $self, $class;
}

package FF;

use base qw(Exception::Validator::FailedField Exporter);

1;
