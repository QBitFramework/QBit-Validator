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
      POSITIVE_NUMBER
      );
    @EXPORT_OK = @EXPORT;
}

my @reserved_keys = qw(
  __ELEM_OPTIONAL__
  __ELEM_EXTRA__
  __ELEM_TYPE__
  __ELEM_CHECK__
  __ELEM_MSG__
  __ELEM_DEPS__
  );

my %reserved_keys = map {$_ => TRUE} @reserved_keys;

use constant SKIP   => (__ELEM_SKIP__     => TRUE);
use constant OPT    => (__ELEM_OPTIONAL__ => TRUE);
use constant EXTRA  => (__ELEM_EXTRA__    => TRUE);
use constant SCALAR => (__ELEM_TYPE__     => 'SCALAR');
use constant HASH   => (__ELEM_TYPE__     => 'HASH');
use constant ARRAY  => (__ELEM_TYPE__     => 'ARRAY');

use constant POSITIVE_NUMBER => (
    __ELEM_TYPE__ => 'SCALAR',
    regexp        => qr/\A[0-9]+\z/,
    min           => 0,
    __ELEM_MSG__  => gettext('Data must be positive number')
);

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

    if ($template->{'__ELEM_SKIP__'}) {
        $self->_add_ok(@path_fields);

        return FALSE;
    }

    $template->{'__ELEM_TYPE__'} //= 'SCALAR';

    $self->_add_error($template, gettext('Data must be defined'))
      if !$template->{'__ELEM_OPTIONAL__'} && !defined($data);

    if (defined($data)) {
        if ($template->{'__ELEM_TYPE__'} eq 'SCALAR') {
            $self->_validation_scalar($data, $template, @path_fields);
        } elsif ($template->{'__ELEM_TYPE__'} eq 'HASH') {
            $self->_validation_hash($data, $template, @path_fields);
        } elsif ($template->{'__ELEM_TYPE__'} eq 'ARRAY') {
            $self->_validation_array($data, $template, @path_fields);
        } else {
            throw Exception::Validator gettext('Unknown __ELEM_TYPE__ "%s"', $template->{'__ELEM_TYPE__'});
        }

        if (exists($template->{'__ELEM_CHECK__'})) {
            throw Exception::Validator gettext('Option "__ELEM_CHECK__" must be code')
              if !defined($template->{'__ELEM_CHECK__'}) || ref($template->{'__ELEM_CHECK__'}) ne 'CODE';

            my $error = $template->{'__ELEM_CHECK__'}($self, $data, $template, @path_fields);

            $self->_add_error($template, $error, @path_fields) if $error;
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

    my @fields = grep {!$reserved_keys{$_}} keys(%$template);

    my %template_fields = ();
    foreach my $field (@fields) {
        $template_fields{$field} = TRUE;

        my @path = (@path_fields, $field);

        if (exists($template->{$field}{'__ELEM_DEPS__'})) {
            $self->_add_error($template, gettext('Option __ELEM_DEPS__ must be defined'), @path_fields)
              unless defined($template->{$field}{'__ELEM_DEPS__'});

            $template->{$field}{'__ELEM_DEPS__'} = [$template->{$field}{'__ELEM_DEPS__'}]
              if ref($template->{$field}{'__ELEM_DEPS__'}) ne 'ARRAY';

            foreach my $dep_field (@{$template->{$field}{'__ELEM_DEPS__'}}) {
                unless (defined($data->{$dep_field})) {
                    $self->_add_error($template, gettext('Key "%s" depends from "%s"', $field, $dep_field), @path);

                    return FALSE;
                }
            }
        }

        $self->_add_error($template, gettext('Key "%s" required', $field), @path)
          if !$template->{$field}{'__ELEM_OPTIONAL__'} && !defined($data->{$field});

        $self->_validation($data->{$field}, $template->{$field}, @path);
    }

    my @extra_fields = grep {!$template_fields{$_}} keys(%$data);

    $self->_add_error($template, gettext('Extra fields: %s', join(', ', @extra_fields)))
      if @extra_fields && !$template->{'__ELEM_EXTRA__'};

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
          unless exists($template->{'__ELEM_MSG__'});
    } else {
        $self->{'__CHECK_FIELDS__'}{$error_key}{'error'} = {
            msgs => [exists($template->{'__ELEM_MSG__'}) ? $template->{'__ELEM_MSG__'} : $error],
            path => \@path_fields
        };
    }
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
