package QBit::Validator::Type;

use qbit;

use base qw(QBit::Class);

__PACKAGE__->abstract_methods(qw(_get_options _get_options_name));

sub check_options {
    my ($self, $qv, $data, $template, @path_field) = @_;

    if ($template->{'skip'}) {
        $qv->_add_ok(@path_field);

        return TRUE;
    }

    $self->_check_options($qv, $data, $template, @path_field);

    if (exists($template->{'check'}) && !$qv->has_error(\@path_field)) {
        throw Exception::Validator gettext('Option "check" must be code')
          if !defined($template->{'check'}) || ref($template->{'check'}) ne 'CODE';

        my $error;
        try {
            $template->{'check'}($qv, $data, $template, @path_field);
        }
        catch Exception::Validator catch FF with {
            $error = shift->message;
        }
        catch {
            $error = gettext('Incorrect data');
        };

        $qv->_add_error($template, $error, @path_field) if $error;
    }
}

sub _check_options {
    my ($self, $qv, $data, $template, @path_field) = @_;

    my @options =
      map {$_->{'name'}} grep {exists($template->{$_->{'name'}}) || $_->{'required'}} @{$self->_get_options()};

    foreach my $option (@options) {
        if ($self->can($option)) {
            return unless $self->$option($qv, $data, $template, $option, @path_field);
        } else {
            throw Exception::Validator gettext('Option "%s" don\'t have check sub', $option);
        }
    }

    $qv->_add_ok(\@path_field);
}

sub get_options {
    my ($self) = @_;

    my %options = (
        skip  => TRUE,
        type  => TRUE,
        check => TRUE,
        msg   => TRUE,
    );

    $options{$_} = TRUE foreach $self->_get_options_name();

    return keys(%options);
}

TRUE;
