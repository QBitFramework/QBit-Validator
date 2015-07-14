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

__PACKAGE__->mk_accessors(qw(data template));

sub init {
    my ($self) = @_;

    $self->{'__CHECK_FIELDS__'} = {};

    my $data     = $self->data;
    my $template = $self->template;

    $self->_validation($data, $template);

    $self->throw_exception() if $self->has_errors && $self->{'throw_exception'};
}

sub _validation {
    my ($self, $data, $template, @path_fields) = @_;

    if ($template->{'skip'}) {
        $self->_add_ok(@path_fields);

        return FALSE;
    }

    $template->{'type'} //= 'scalar';

    $self->_add_error($template, gettext('Data must be defined'))
      if !$template->{'optional'} && !defined($data);

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

    if (exists($template->{'regexp'})) {
        throw Exception::Validator gettext('Key "regexp" must be type "Regexp"')
          if !defined($template->{'regexp'}) || ref($template->{'regexp'}) ne 'Regexp';

        $self->_add_error($template, gettext('Data do not fit the regular expression'), @path_fields)
          if $data !~ $template->{'regexp'};
    }

    if (exists($template->{'min'})) {
        throw Exception::Validator gettext('Key "min" must be defined') unless defined($template->{'min'});

        $self->_add_error($template, gettext('Data less then "%s"', $template->{'min'}), @path_fields)
          if $data < $template->{'min'};
    }

    if (exists($template->{'eq'})) {
        throw Exception::Validator gettext('Key "eq" must be defined') unless defined($template->{'eq'});

        $self->_add_error($template, gettext('Data not equal "%s"', $template->{'eq'}), @path_fields)
          unless $data == $template->{'eq'};
    }

    if (exists($template->{'max'})) {
        throw Exception::Validator gettext('Key "max" must be defined') unless defined($template->{'max'});

        $self->_add_error($template, gettext('Data more than "%s"', $template->{'max'}), @path_fields)
          if $data > $template->{'max'};
    }

    if (exists($template->{'len_min'})) {
        throw Exception::Validator gettext('Key "len_min" must be positive number')
          if !defined($template->{'len_min'}) || $template->{'len_min'} !~ /\A[0-9]+\z/;

        $self->_add_error($template, gettext('Length data less then "%s"', $template->{'len_min'}), @path_fields)
          if length($data) < $template->{'len_min'};
    }

    if (exists($template->{'len'})) {
        throw Exception::Validator gettext('Key "len" must be positive number')
          if !defined($template->{'len'}) || $template->{'len'} !~ /\A[0-9]+\z/;

        $self->_add_error($template, gettext('Length data not equal "%s"', $template->{'len'}), @path_fields)
          unless length($data) == $template->{'len'};
    }

    if (exists($template->{'len_max'})) {
        throw Exception::Validator gettext('Key "len_max" must be positive number')
          if !defined($template->{'len_max'}) || $template->{'len_max'} !~ /\A[0-9]+\z/;

        $self->_add_error($template, gettext('Length data more than "%s"', $template->{'len_max'}), @path_fields)
          if length($data) > $template->{'len_max'};
    }

    if (exists($template->{'in'})) {
        throw Exception::Validator gettext('Key "in" must be defined') unless defined($template->{'in'});

        $template->{'in'} = [$template->{'in'}] if ref($template->{'in'}) ne 'ARRAY';

        $self->_add_error($template, gettext('Data not in array: %s', join(', ', @{$template->{'in'}})), @path_fields)
          unless in_array($data, $template->{'in'});
    }

    $self->_add_ok(@path_fields);
}

sub _validation_hash {
    my ($self, $data, $template, @path_fields) = @_;

    unless (ref($data) eq 'HASH') {
        $self->_add_error($template, gettext('Data must be HASH'), @path_fields);

        return FALSE;
    }

    my @fields = keys(%{$template->{'fields'}});

    foreach my $field (@fields) {
        my @path = (@path_fields, $field);

        if (exists($template->{'fields'}{$field}{'deps'})) {
            $self->_add_error($template, gettext('Option deps must be defined'), @path_fields)
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

    if (exists($template->{'size_min'})) {
        throw Exception gettext('Key "size_min" must be positive number')
          if !defined($template->{'size_min'}) || $template->{'size_min'} !~ /\A[0-9]+\z/;

        $self->_add_error($template, gettext('Size data less then "%s"', $template->{'size_min'}), @path_fields)
          if @$data < $template->{'size_min'};
    }

    if (exists($template->{'size'})) {
        throw Exception gettext('Key "size" must be positive number')
          if !defined($template->{'size'}) || $template->{'size'} !~ /\A[0-9]+\z/;

        $self->_add_error($template, gettext('Size data not equal "%s"', $template->{'size'}), @path_fields)
          unless @$data == $template->{'size'};
    }

    if (exists($template->{'size_max'})) {
        throw Exception gettext('Key "size_max" must be positive number')
          if !defined($template->{'size_max'}) || $template->{'size_max'} !~ /\A[0-9]+\z/;

        $self->_add_error($template, gettext('Size data more than "%s"', $template->{'size_max'}), @path_fields)
          if @$data > $template->{'size_max'};
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
            $self->_add_error($template, gettext('Size data no equal "%s"', scalar(@{$template->{'contents'}})),
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

TRUE;
