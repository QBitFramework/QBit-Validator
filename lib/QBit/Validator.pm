package Exception::Validator;

use base qw(Exception);

package QBit::Validator;

use qbit;

use base qw(QBit::Class);

use base qw(Exporter);

BEGIN {
    our (@EXPORT, @EXPORT_OK);

    @EXPORT = qw(
      SKIP
      OPT
      EXTRA
      SCALAR
      HASH
      ARRAY
      );
    @EXPORT_OK = @EXPORT;
}

use constant SKIP   => (skip     => TRUE);
use constant OPT    => (optional => TRUE);
use constant EXTRA  => (extra    => TRUE);
use constant SCALAR => (type     => 'scalar');
use constant HASH   => (type     => 'hash');
use constant ARRAY  => (type     => 'array');

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
    my ($self, $data, $template, @path_fields) = @_;

    throw Exception gettext('Key "template" must be HASH') if !defined($template) || ref($template) ne 'HASH';

    if ($template->{'skip'}) {
        $self->_add_ok(@path_fields);

        return TRUE;
    }

    if (!$template->{'optional'} && !defined($data)) {
        $self->_add_error($template, gettext('Data must be defined'));

        return FALSE;
    }

    $template->{'type'} //= 'scalar';

    $template->{'type'} = [$template->{'type'}] unless ref($template->{'type'}) eq 'ARRAY';

    foreach my $type (@{$template->{'type'}}) {
        if (defined($data)) {
            if ($type eq 'scalar') {
                $self->_validation_scalar($data, $template, @path_fields);
            } elsif ($type eq 'hash') {
                $self->_validation_hash($data, $template, @path_fields);
            } elsif ($type eq 'array') {
                $self->_validation_array($data, $template, @path_fields);
            } else {
                unless (exists($self->{'__REQUIRED_TYPE__'}{$type})) {
                    my $type_class = 'QBit::Validator::Type::' . $type;
                    my $type_fn    = "$type_class.pm";
                    $type_fn =~ s/::/\//g;

                    try {
                        require $type_fn;
                    }
                    catch {
                        throw Exception::Validator gettext('Unknown type "%s"', $type);
                    };

                    $self->{'__REQUIRED_TYPE__'}{$type} = $type_class->new();
                }

                $self->_validation($data, $self->{'__REQUIRED_TYPE__'}{$type}->get_template, @path_fields);
            }

            if (exists($template->{'check'})) {
                throw Exception::Validator gettext('Option "check" must be code')
                  if !defined($template->{'check'}) || ref($template->{'check'}) ne 'CODE';

                my $error = $template->{'check'}($self, $data, $template, @path_fields);

                $self->_add_error($template, $error, @path_fields) if $error;
            }
        } else {
            $self->_add_ok(@path_fields);
        }
    }
}

sub throw_exception {
    my ($self) = @_;

    throw Exception::Validator $self->get_all_errors;
}

sub _validation_scalar {
    my ($self, $data, $template, @path_fields) = @_;

    if (ref($data)) {
        $self->_add_error($template, gettext('Data must be SCALAR'), @path_fields);

        return FALSE;
    }

    my @bad_keys =
      grep {!in_array($_, [qw(type skip optional deps check msg regexp min eq max len_min len len_max in)])}
      keys(%$template);
    throw Exception::Validator gettext('Unknown options: %s', join(', ', @bad_keys)) if @bad_keys;

    if (exists($template->{'regexp'})) {
        throw Exception::Validator gettext('Key "regexp" must be type "Regexp"')
          if !defined($template->{'regexp'}) || ref($template->{'regexp'}) ne 'Regexp';

        if ($data !~ $template->{'regexp'}) {
            $self->_add_error($template, gettext('Got value "%s" do not fit the regular expression', $data),
                @path_fields);

            return FALSE;
        }
    }

    if (exists($template->{'min'})) {
        throw Exception::Validator gettext('Key "min" must be numeric') unless looks_like_number($template->{'min'});

        unless (looks_like_number($data)) {
            $self->_add_error($template, gettext('The data must be numeric, but got "%s"', $data), @path_fields);

            return FALSE;
        }

        if ($data < $template->{'min'}) {
            $self->_add_error($template, gettext('Got value "%s" less then "%s"', $data, $template->{'min'}),
                @path_fields);

            return FALSE;
        }
    }

    if (exists($template->{'eq'})) {
        throw Exception::Validator gettext('Key "eq" must be numeric') unless looks_like_number($template->{'eq'});

        unless (looks_like_number($data)) {
            $self->_add_error($template, gettext('The data must be numeric, but got "%s"', $data), @path_fields);

            return FALSE;
        }

        unless ($data == $template->{'eq'}) {
            $self->_add_error($template, gettext('Got value "%s" not equal "%s"', $data, $template->{'eq'}),
                @path_fields);

            return FALSE;
        }
    }

    if (exists($template->{'max'})) {
        throw Exception::Validator gettext('Key "max" must be numeric') unless looks_like_number($template->{'max'});

        unless (looks_like_number($data)) {
            $self->_add_error($template, gettext('The data must be numeric, but got "%s"', $data), @path_fields);

            return FALSE;
        }

        if ($data > $template->{'max'}) {
            $self->_add_error($template, gettext('Got value "%s" more than "%s"', $data, $template->{'max'}),
                @path_fields);

            return FALSE;
        }
    }

    if (exists($template->{'len_min'})) {
        throw Exception::Validator gettext('Key "len_min" must be positive number')
          if !defined($template->{'len_min'}) || $template->{'len_min'} !~ /\A[0-9]+\z/;

        if (length($data) < $template->{'len_min'}) {
            $self->_add_error($template, gettext('Length "%s" less then "%s"', $data, $template->{'len_min'}),
                @path_fields);

            return FALSE;
        }
    }

    if (exists($template->{'len'})) {
        throw Exception::Validator gettext('Key "len" must be positive number')
          if !defined($template->{'len'}) || $template->{'len'} !~ /\A[0-9]+\z/;

        unless (length($data) == $template->{'len'}) {
            $self->_add_error($template, gettext('Length "%s" not equal "%s"', $data, $template->{'len'}),
                @path_fields);

            return FALSE;
        }
    }

    if (exists($template->{'len_max'})) {
        throw Exception::Validator gettext('Key "len_max" must be positive number')
          if !defined($template->{'len_max'}) || $template->{'len_max'} !~ /\A[0-9]+\z/;

        if (length($data) > $template->{'len_max'}) {
            $self->_add_error($template, gettext('Length "%s" more than "%s"', $data, $template->{'len_max'}),
                @path_fields);

            return FALSE;
        }
    }

    if (exists($template->{'in'})) {
        throw Exception::Validator gettext('Key "in" must be defined') unless defined($template->{'in'});

        $template->{'in'} = [$template->{'in'}] if ref($template->{'in'}) ne 'ARRAY';

        unless (in_array($data, $template->{'in'})) {
            $self->_add_error($template,
                gettext('Got value "%s" not in array: %s', $data, join(', ', @{$template->{'in'}})), @path_fields);

            return FALSE;
        }
    }

    $self->_add_ok(@path_fields);
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
    my ($self, $template, $error, @path_fields) = @_;

    my $error_key = join(' => ', @path_fields);

    if (exists($self->{'__CHECK_FIELDS__'}{$error_key}{'error'})) {
        push(@{$self->{'__CHECK_FIELDS__'}{$error_key}{'error'}{'msgs'}}, $error)
          unless exists($template->{'msg'});
    } else {
        $self->{'__CHECK_FIELDS__'}{$error_key}{'error'} = {
            msgs => [exists($template->{'msg'}) ? $template->{'msg'} : $error],
            path => \@path_fields
        };
    }

    delete($self->{'__CHECK_FIELDS__'}{$error_key}{'ok'}) if exists($self->{'__CHECK_FIELDS__'}{$error_key}{'ok'});
}

sub get_all_errors {
    my ($self) = @_;

    my $error = '';

    $error .= join("\n", map {@{$_->{'msgs'}}} $self->get_fields_with_error());

    return $error;
}

sub get_error {
    my ($self, $field) = @_;

    $field //= '';

    my $error = '';
    foreach ($self->get_fields_with_error()) {
        $error = join("\n", @{$_->{'msgs'}}) if $field eq (pop(@{$_->{'path'}}) || '');
    }

    return $error;
}

sub get_fields_with_error {
    my ($self) = @_;

    return map {$self->{'__CHECK_FIELDS__'}{$_}{'error'}}
      grep     {$self->{'__CHECK_FIELDS__'}{$_}{'error'}} keys(%{$self->{'__CHECK_FIELDS__'}});
}

sub _add_ok {
    my ($self, @path_fields) = @_;

    my $ok_key = join(' => ', @path_fields);

    return if exists($self->{'__CHECK_FIELDS__'}{$ok_key}) && $self->{'__CHECK_FIELDS__'}{$ok_key}{'error'};

    $self->{'__CHECK_FIELDS__'}{$ok_key}{'ok'} = TRUE;
}

sub has_errors {
    my ($self) = @_;

    return !!$self->get_fields_with_error();
}

sub get_wrong_fields {
    my ($self) = @_;

    my @fields = ();
    foreach ($self->get_fields_with_error()) {
        push(@fields, pop(@{$_->{'path'}}) || '');
    }

    return @fields;
}

TRUE;
