package Exception::Validator;

use base qw(Exception);

package FF;

use base qw(Exception::Validator);

package QBit::Validator;

use qbit;

use base qw(QBit::Class);

__PACKAGE__->mk_ro_accessors(qw(data template app));

my @available_fields = qw(data template app throw);

sub init {
    my ($self) = @_;

    foreach (qw(data template)) {
        throw Exception::Validator gettext('Expected "%s"', $_) unless exists($self->{$_});
    }

    my @bad_fields = grep {!in_array($_, \@available_fields)} keys(%{$self});
    throw Exception::Validator gettext('Unknown options: %s', join(', ', @bad_fields))
      if @bad_fields;

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

    $template->{'type'} //= 'scalar';

    $template->{'type'} = [$template->{'type'}] unless ref($template->{'type'}) eq 'ARRAY';

    foreach my $type (@{$template->{'type'}}) {
        next if $self->has_error(\@path_field);

        unless (exists($self->{'__TYPES__'}{$type})) {
            my $type_class = 'QBit::Validator::Type::' . $type;
            my $type_fn    = "$type_class.pm";
            $type_fn =~ s/::/\//g;

            try {
                require $type_fn;
            }
            catch {
                ldump(shift->message);
                throw Exception::Validator gettext('Unknown type "%s"', $type);
            };

            $self->{'__TYPES__'}{$type} = $type_class->new();
        }

        if (!$self->has_error(\@path_field) && $self->{'__TYPES__'}{$type}->can('get_template')) {
            my $new_template = {
                %{$self->{'__TYPES__'}{$type}->get_template},
                map {$_ => $template->{$_}} grep {$_ ne 'type'} keys(%$template)
            };

            $self->_validation($data, $new_template, TRUE, @path_field);
        }

        $self->{'__TYPES__'}{$type}->check_options($self, $data, $template, @path_field)
          unless $self->has_error(\@path_field);
    }
    
    unless ($no_check_options) {
        my $all_options = $self->_get_all_options_by_type($template->{'type'});

        my $diff = arrays_difference([keys($template)], $all_options);

        throw Exception::Validator gettext('Unknown options: %s', join(', ', @$diff)) if @$diff;
    }
}

sub _get_all_options_by_type {
    my ($self, $types) = @_;
    
    $types //= 'scalar';
    $types = [$types] unless ref($types) eq 'ARRAY';

    my %uniq_options = ();

    foreach my $type (@$types) {
        if ($self->{'__TYPES__'}{$type}->can('get_template')) {
            my $template = $self->{'__TYPES__'}{$type}->get_template();

            $uniq_options{$_} = TRUE foreach @{$self->_get_all_options_by_type($template->{'type'})};
        }

        $uniq_options{$_} = TRUE foreach $self->{'__TYPES__'}{$type}->get_options();
    }

    return [keys(%uniq_options)];
}

sub throw_exception {
    my ($self) = @_;

    throw Exception::Validator $self->get_all_errors;
}

sub _validation_hash {
    my ($self, $data, $template, @path_fields) = @_;

    unless (ref($data) eq 'HASH') {
        $self->_add_error($template, gettext('Data must be HASH'), @path_fields);

        return FALSE;
    }

    my @bad_keys =
      grep {!in_array($_, [qw(type skip optional extra deps check msg fields)])}
      keys(%$template);
    throw Exception::Validator gettext('Unknown options: %s', join(', ', @bad_keys)) if @bad_keys;

    my @fields = keys(%{$template->{'fields'}});

    foreach my $field (@fields) {
        my @path = (@path_fields, $field);

        if (exists($template->{'fields'}{$field}{'deps'}) && defined($data->{$field})) {
            throw Exception::Validator gettext('Option deps must be defined')
              unless defined($template->{'fields'}{$field}{'deps'});

            $template->{'fields'}{$field}{'deps'} = [$template->{'fields'}{$field}{'deps'}]
              if ref($template->{'fields'}{$field}{'deps'}) ne 'ARRAY';

            foreach my $dep_field (@{$template->{'fields'}{$field}{'deps'}}) {
                unless (defined($data->{$dep_field})) {
                    $self->_add_error($template, gettext('Key "%s" depends from "%s"', $field, $dep_field), @path);

                    return FALSE;
                }
            }
        }

        $self->_add_error($template, gettext('Key "%s" required', $field), @path)
          if !$template->{'fields'}{$field}{'optional'} && !defined($data->{$field});

        $self->_validation($data->{$field}, $template->{'fields'}{$field}, @path);
    }

    my @extra_fields = grep {!$template->{'fields'}{$_}} keys(%$data);

    $self->_add_error($template, gettext('Extra fields: %s', join(', ', @extra_fields)))
      if @extra_fields && !$template->{'extra'};

    $self->_add_ok(@path_fields);
}

sub _validation_array {
    my ($self, $data, $template, @path_fields) = @_;

    unless (ref($data) eq 'ARRAY') {
        $self->_add_error($template, gettext('Data must be ARRAY'), @path_fields);

        return FALSE;
    }

    my @bad_keys =
      grep {!in_array($_, [qw(type skip optional deps check msg size_min size size_max all contents)])}
      keys(%$template);
    throw Exception::Validator gettext('Unknown options: %s', join(', ', @bad_keys)) if @bad_keys;

    if (exists($template->{'size_min'})) {
        throw Exception gettext('Key "size_min" must be positive number')
          if !defined($template->{'size_min'}) || $template->{'size_min'} !~ /\A[0-9]+\z/;

        if (@$data < $template->{'size_min'}) {
            $self->_add_error($template,
                gettext('Data size "%s" less then "%s"', scalar(@$data), $template->{'size_min'}), @path_fields);

            return FALSE;
        }
    }

    if (exists($template->{'size'})) {
        throw Exception gettext('Key "size" must be positive number')
          if !defined($template->{'size'}) || $template->{'size'} !~ /\A[0-9]+\z/;

        unless (@$data == $template->{'size'}) {
            $self->_add_error($template, gettext('Data size "%s" not equal "%s"', scalar(@$data), $template->{'size'}),
                @path_fields);

            return FALSE;
        }
    }

    if (exists($template->{'size_max'})) {
        throw Exception gettext('Key "size_max" must be positive number')
          if !defined($template->{'size_max'}) || $template->{'size_max'} !~ /\A[0-9]+\z/;

        if (@$data > $template->{'size_max'}) {
            $self->_add_error($template,
                gettext('Data size "%s" more than "%s"', scalar(@$data), $template->{'size_max'}), @path_fields);

            return FALSE;
        }
    }

    if (exists($template->{'all'}) && exists($template->{'contents'})) {
        throw Exception::Validator gettext('Options "all" and "contents" can not be used together');
    } elsif (exists($template->{'all'})) {
        throw Exception::Validator gettext('Option "all" must be HASH')
          if !defined($template->{'all'}) || ref($template->{'all'}) ne 'HASH';

        my $num = 0;
        foreach (@$data) {
            my @path = (@path_fields, $num);

            $self->_validation($_, $template->{'all'}, @path);

            $num++;
        }
    } elsif (exists($template->{'contents'})) {
        throw Exception::Validator gettext('Option "contents" must be ARRAY')
          if !defined($template->{'contents'}) || ref($template->{'contents'}) ne 'ARRAY';

        if (@$data != @{$template->{'contents'}}) {
            $self->_add_error($template,
                gettext('Data size "%s" no equal "%s"', scalar(@$data), scalar(@{$template->{'contents'}})),
                @path_fields);

            return FALSE;
        }

        my $num = 0;
        foreach (@$data) {
            my @path = (@path_fields, $num);

            $self->_validation($_, $template->{'contents'}[$num], @path);

            $num++;
        }
    }

    $self->_add_ok(@path_fields);
}

sub _add_error {
    my ($self, $template, $error, $field) = @_;

    my $key = $self->_get_key($field);

    if ($self->has_error($field)) {
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
