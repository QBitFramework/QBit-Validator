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

use constant SKIP    => (__ELEM_SKIP__ => TRUE);
use constant OPT    => (__ELEM_OPTIONAL__ => TRUE);
use constant EXTRA  => (__ELEM_EXTRA__    => TRUE);
use constant SCALAR => (__ELEM_TYPE__     => 'SCALAR');
use constant HASH   => (__ELEM_TYPE__     => 'HASH');
use constant ARRAY  => (__ELEM_TYPE__     => 'ARRAY');

use constant POSITIVE_NUMBER => (
    __ELEM_TYPE__ => 'SCALAR',
    regexp        => qr/^[0-9]+$/,
    min           => 0,
    __ELEM_MSG__  => gettext('Data must be positive number')
);

__PACKAGE__->mk_accessors(qw(data template));

sub init {
    my ($self) = @_;

    $self->{'__CHECK_FIELDS__'} = {};

    my $data     = $self->data;
    my $template = $self->template;

    $self->validation($data, $template);

    $self->throw_exception() if $self->has_errors && $self->{'throw_exception'};
}

sub validation {
    my ($self, $data, $template, @path_fields) = @_;

    if ($template->{'__ELEM_SKIP__'}) {
        $self->add_ok(@path_fields);

        return FALSE;
    }

    $template->{'__ELEM_TYPE__'} //= 'SCALAR';

    $self->add_error($template, gettext('Data must be defined'))
      if !$template->{'__ELEM_OPTIONAL__'} && !defined($data);

    if (defined($data)) {
        if (exists($template->{'__ELEM_CHECK__'})) {
            throw Exception::Validator gettext('Option "__ELEM_CHECK__" must be code')
              if !defined($template->{'__ELEM_CHECK__'}) || ref($template->{'__ELEM_CHECK__'}) ne 'CODE';

            my $error = $template->{'__ELEM_CHECK__'}($self, $data, $template, @path_fields);

            $self->add_error($template, $error, @path_fields) if $error;
        }

        if ($template->{'__ELEM_TYPE__'} eq 'SCALAR') {
            $self->validation_scalar($data, $template, @path_fields);
        } elsif ($template->{'__ELEM_TYPE__'} eq 'HASH') {
            $self->validation_hash($data, $template, @path_fields);
        } elsif ($template->{'__ELEM_TYPE__'} eq 'ARRAY') {
            $self->validation_array($data, $template, @path_fields);
        } else {
            throw Exception::Validator gettext('Unknown __ELEM_TYPE__ "%s"', $template->{'__ELEM_TYPE__'});
        }
    }
}

sub throw_exception {
    my ($self) = @_;

    throw Exception::Validator $self->get_all_errors;
}

sub validation_scalar {
    my ($self, $data, $template, @path_fields) = @_;

    if (ref($data)) {
        $self->add_error($template, gettext('Data must be SCALAR'), @path_fields);

        return FALSE;
    }

    if (exists($template->{'regexp'})) {
        throw Exception::Validator gettext('Key "regexp" must be type "Regexp"')
          if !defined($template->{'regexp'}) || ref($template->{'regexp'}) ne 'Regexp';

        $self->add_error($template, gettext('Data do not fit the regular expression'), @path_fields)
          if $data !~ $template->{'regexp'};
    }

    if (exists($template->{'min'})) {
        throw Exception::Validator gettext('Key "min" must be defined') unless defined($template->{'min'});

        $self->add_error($template, gettext('Data less then "%s"', $template->{'min'}), @path_fields)
          if $data < $template->{'min'};
    }

    if (exists($template->{'eq'})) {
        throw Exception::Validator gettext('Key "eq" must be defined') unless defined($template->{'eq'});

        $self->add_error($template, gettext('Data not equal "%s"', $template->{'eq'}), @path_fields)
          unless $data == $template->{'eq'};
    }

    if (exists($template->{'max'})) {
        throw Exception::Validator gettext('Key "max" must be defined') unless defined($template->{'max'});

        $self->add_error($template, gettext('Data more than "%s"', $template->{'max'}), @path_fields)
          if $data > $template->{'max'};
    }

    if (exists($template->{'len_min'})) {
        throw Exception::Validator gettext('Key "len_min" must be defined') unless defined($template->{'len_min'});

        $self->add_error($template, gettext('Length data less then "%s"', $template->{'len_min'}), @path_fields)
          if length($data) < $template->{'len_min'};
    }

    if (exists($template->{'len'})) {
        throw Exception::Validator gettext('Key "len" must be defined') unless defined($template->{'len'});

        $self->add_error($template, gettext('Length data not equal "%s"', $template->{'len'}), @path_fields)
          unless length($data) == $template->{'len'};
    }

    if (exists($template->{'len_max'})) {
        throw Exception::Validator gettext('Key "len_max" must be defined') unless defined($template->{'len_max'});

        $self->add_error($template, gettext('Length data more than "%s"', $template->{'len_max'}), @path_fields)
          if length($data) > $template->{'len_max'};
    }

    if (exists($template->{'in'})) {
        throw Exception::Validator gettext('Key "in" must be defined') unless defined($template->{'in'});

        $template->{'in'} = [$template->{'in'}] if ref($template->{'in'}) ne 'ARRAY';

        $self->add_error($template, gettext('Data not in array: %s', join(', ', @{$template->{'in'}})), @path_fields)
          unless in_array($data, $template->{'in'});
    }

    $self->add_ok(@path_fields);
}

sub validation_hash {
    my ($self, $data, $template, @path_fields) = @_;

    unless (ref($data) eq 'HASH') {
        $self->add_error($template, gettext('Data must be HASH'), @path_fields);

        return FALSE;
    }

    my @fields = grep {!$reserved_keys{$_}} keys(%$template);

    my %template_fields = ();
    foreach my $field (@fields) {
        $template_fields{$field} = TRUE;

        my @path = (@path_fields, $field);

        if (exists($template->{$field}{'__ELEM_DEPS__'})) {
            $self->add_error($template, gettext('Option __ELEM_DEPS__ must be defined'), @path_fields)
              unless defined($template->{$field}{'__ELEM_DEPS__'});

            $template->{$field}{'__ELEM_DEPS__'} = [$template->{$field}{'__ELEM_DEPS__'}]
              if ref($template->{$field}{'__ELEM_DEPS__'}) ne 'ARRAY';

            foreach my $dep_field (@{$template->{$field}{'__ELEM_DEPS__'}}) {
                unless (defined($data->{$dep_field})) {
                    $self->add_error($template, gettext('Key "%s" depends from "%s"', $field, $dep_field), @path);

                    return FALSE;
                }
            }
        }

        $self->add_error($template, gettext('Key "%s" required', $field), @path)
          if !$template->{$field}{'__ELEM_OPTIONAL__'} && !defined($data->{$field});

        $self->validation($data->{$field}, $template->{$field}, @path);
    }

    my @extra_fields = grep {!$template_fields{$_}} keys(%$data);

    $self->add_error($template, gettext('Extra fields: %s', join(', ', @extra_fields)))
      if @extra_fields && !$template->{'__ELEM_EXTRA__'};

    $self->add_ok(@path_fields);
}

sub validation_array { }

sub add_error {
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

sub add_ok {
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
