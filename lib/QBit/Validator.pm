package Exception::Validator;

use base qw(Exception);

package FF;

use base qw(Exception::Validator);

package QBit::Validator;

use qbit;

use base qw(QBit::Class);

__PACKAGE__->mk_ro_accessors(qw(data app));

__PACKAGE__->mk_accessors(qw(template));

my @available_fields = qw(data template app throw pre_run);

sub init {
    my ($self) = @_;

    foreach (qw(data template)) {
        throw Exception::Validator gettext('Expected "%s"', $_) unless exists($self->{$_});
    }

    my @bad_fields = grep {!in_array($_, \@available_fields)} keys(%{$self});
    throw Exception::Validator gettext('Unknown options: %s', join(', ', @bad_fields))
      if @bad_fields;

    if (exists($self->{'pre_run'})) {
        throw Exception::Validator gettext('Option "pre_run" must be code')
          if !defined($self->{'pre_run'}) || ref($self->{'pre_run'}) ne 'CODE';

        $self->{'pre_run'}($self);
    }

    $self->{'__CHECK_FIELDS__'} = {};

    my $data     = $self->data;
    my $template = $self->template;

    $self->_validation($data, $template);

    $self->throw_exception() if $self->has_errors && $self->{'throw'};
}

sub _validation {
    my ($self, $data, $template, $no_check_options, @path_field) = @_;

    throw Exception::Validator gettext('Key "template" must be HASH')
      if !defined($template) || ref($template) ne 'HASH';

    $template->{'type'} //= ['scalar'];

    $template->{'type'} = [$template->{'type'}] unless ref($template->{'type'}) eq 'ARRAY';

    my $already_check;
    foreach my $type_name (@{$template->{'type'}}) {
        my $type = $self->_get_type_by_name($type_name);

        if ($type->can('get_template')) {
            my $type_template = $type->get_template();

            my $new_template = {
                (map {$_ => $type_template->{$_}} grep {!exists($template->{$_})} keys(%$type_template)),
                map {$_ => $template->{$_}} grep {$_ ne 'type' && $_ ne 'check'} keys(%$template)
            };

            $self->_validation($data, $new_template, TRUE, @path_field);
        }

        unless ($self->has_error(\@path_field)) {
            $type->check_options($self, $data, $template, @path_field);
        } else {
            last;
        }

        if (exists($template->{'check'}) && !$already_check) {
            $already_check = TRUE;

            throw Exception::Validator gettext('Option "check" must be code')
              if !defined($template->{'check'}) || ref($template->{'check'}) ne 'CODE';

            next if !defined($data) && $template->{'optional'};

            my $error;
            my $error_msg;
            try {
                $template->{'check'}($self, $data, $template, @path_field);
            }
            catch Exception::Validator catch FF with {
                $error     = TRUE;
                $error_msg = shift->message;
            }
            catch {
                $error     = TRUE;
                $error_msg = gettext('Internal error');
            };

            if ($error) {
                $self->_add_error($template, $error_msg, \@path_field, check_error => TRUE);

                last;
            }
        }
    }

    unless ($no_check_options) {
        my $all_options = $self->_get_all_options_by_types($template->{'type'});

        my $diff = arrays_difference([keys(%$template)], $all_options);

        throw Exception::Validator gettext('Unknown options: %s', join(', ', @$diff)) if @$diff;
    }
}

sub _get_type_by_name {
    my ($self, $type_name) = @_;

    unless (exists($self->{'__TYPES__'}{$type_name})) {
        my $type_class = 'QBit::Validator::Type::' . $type_name;
        my $type_fn    = "$type_class.pm";
        $type_fn =~ s/::/\//g;

        try {
            require $type_fn;
        }
        catch {
            throw Exception::Validator gettext('Unknown type "%s"', $type_name);
        };

        $self->{'__TYPES__'}{$type_name} = $type_class->new();
    }

    return $self->{'__TYPES__'}{$type_name};
}

sub _get_all_options_by_types {
    my ($self, $types_name) = @_;

    $types_name //= 'scalar';
    $types_name = [$types_name] unless ref($types_name) eq 'ARRAY';

    my %uniq_options = ();

    foreach my $type_name (@$types_name) {
        my $type = $self->_get_type_by_name($type_name);

        if ($type->can('get_template')) {
            my $template = $type->get_template();

            $uniq_options{$_} = TRUE foreach @{$self->_get_all_options_by_types($template->{'type'})};
        }

        $uniq_options{$_} = TRUE foreach $type->get_all_options_name();
    }

    return [keys(%uniq_options)];
}

sub throw_exception {
    my ($self) = @_;

    throw Exception::Validator $self->get_all_errors;
}

sub _add_error {
    my ($self, $template, $error, $field, %opts) = @_;

    my $key = $self->_get_key($field);

    if ($opts{'check_error'}) {
        $self->{'__CHECK_FIELDS__'}{$key}{'error'} = {
            msgs => [$error],
            path => $field // []
        };
    } elsif ($self->has_error($field)) {
        push(@{$self->{'__CHECK_FIELDS__'}{$key}{'error'}{'msgs'}}, $error)
          unless exists($template->{'msg'});
    } else {
        $self->{'__CHECK_FIELDS__'}{$key}{'error'} = {
            msgs => [exists($template->{'msg'}) ? $template->{'msg'} : $error],
            path => $field // []
        };
    }

    delete($self->{'__CHECK_FIELDS__'}{$key}{'ok'}) if exists($self->{'__CHECK_FIELDS__'}{$key}{'ok'});
}

sub get_all_errors {
    my ($self) = @_;

    my $error = '';

    $error .= join("\n", map {@{$_->{'msgs'}}} $self->get_fields_with_error());

    return $error;
}

sub get_error {
    my ($self, $field) = @_;

    my $key = $self->_get_key($field);

    my $error = '';
    foreach ($self->get_fields_with_error()) {
        $error = join("\n", @{$_->{'msgs'}}) if $key eq $self->_get_key($_->{'path'});
    }

    return $error;
}

sub get_fields_with_error {
    my ($self) = @_;

    return map {$self->{'__CHECK_FIELDS__'}{$_}{'error'}}
      grep     {$self->{'__CHECK_FIELDS__'}{$_}{'error'}} keys(%{$self->{'__CHECK_FIELDS__'}});
}

sub _add_ok {
    my ($self, $field) = @_;

    return if $self->checked($field) && $self->has_error($field);

    $self->{'__CHECK_FIELDS__'}{$self->_get_key($field)}{'ok'} = TRUE;
}

sub checked {
    my ($self, $field) = @_;

    return exists($self->{'__CHECK_FIELDS__'}{$self->_get_key($field)});
}

sub has_error {
    my ($self, $field) = @_;

    return exists($self->{'__CHECK_FIELDS__'}{$self->_get_key($field)}{'error'});
}

sub has_errors {
    my ($self) = @_;

    return !!$self->get_fields_with_error();
}

sub _get_key {
    my ($self, $path_field) = @_;

    $path_field //= [];

    $path_field = [$path_field] unless ref($path_field) eq 'ARRAY';

    return join(' => ', @$path_field);
}

TRUE;
