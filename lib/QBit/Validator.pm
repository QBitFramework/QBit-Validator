package QBit::Validator;

use qbit;

use base qw(QBit::Class);

use Exception::Validator;

#TODO: write test for errors structure
#TODO: write type "variable"
#TODO: Benchmark (one create vs more and more create vs more)

__PACKAGE__->mk_ro_accessors(qw(app));

__PACKAGE__->mk_accessors(qw(template data dpath));

my %available_fields = map {$_ => TRUE} qw(data template app throw pre_run dpath);

sub init {
    my ($self) = @_;

    foreach (qw(template)) {
        throw Exception::Validator gettext('Expected "%s"', $_) unless exists($self->{$_});
    }

    my @bad_fields = grep {!$available_fields{$_}} keys(%{$self});
    throw Exception::Validator gettext('Unknown options: %s', join(', ', @bad_fields))
      if @bad_fields;

    if (exists($self->{'pre_run'})) {
        throw Exception::Validator gettext('Option "pre_run" must be code')
          if !defined($self->{'pre_run'}) || ref($self->{'pre_run'}) ne 'CODE';

        $self->{'pre_run'}($self);
    }

    $self->{'dpath'} //= '/';

    $self->_init_template();

    my $data = $self->data;

    $self->validate($self->data) if exists($self->{'data'});

    $self->throw_exception() if $self->has_errors && $self->{'throw'};
}

sub _init_template {
    my ($self) = @_;

    $self->{'__CHECKS__'} = [];

    my $template = $self->template;

    throw Exception::Validator gettext('Key "%s" must be HASH', 'template')
      if !defined($template) || ref($template) ne 'HASH';

    my ($type_obj, $final_template) = $self->_get_type_and_template($template);

    push(@{$self->{'__CHECKS__'}}, $type_obj->get_checks_by_template($self, $final_template, []));
}

sub _get_type_and_template {
    my ($self, $template) = @_;

    my $exists_check = exists($template->{'check'});
    my $check = delete($template->{'check'});

    throw Exception::Validator gettext('Option "%s" must be defined', 'check')
      if $exists_check && !defined($check);

    my $type  = delete($template->{'type'}) // 'scalar';

    my $type_obj = $self->_get_type_by_name($type);

    if ($type_obj->can('get_template')) {
        my $base_template = $type_obj->get_template();

        if (exists($base_template->{'check'}) && ref($base_template->{'check'}) ne 'ARRAY') {
            $base_template->{'check'} = [$base_template->{'check'}];
        }

        $template = {%$base_template, %$template};

        push(@{$template->{'check'}}, ref($check) eq 'ARRAY' ? @$check : $check) if defined($check);

        return $self->_get_type_and_template($template);
    } else {
        $template->{'type'} = $type;

        push(@{$template->{'check'}}, ref($check) eq 'ARRAY' ? @$check : $check) if defined($check);

        return ($type_obj, $template);
    }
}

sub validate {
    my ($self, $data) = @_;

    #TODO: прокидывать data в глубь
    $self->data($data) unless $self->{'data'};

    my @checks = @{$self->{'__CHECKS__'}};

    my $res = TRUE;
    try {
        foreach my $check (@checks) {
            last unless $check->($self, $data);
        }
    }
    catch {
        my ($exception) = @_;

        my $error;
        if ($exception->{'check_error'} || !$self->{'__CUSTOM_ERRORS__'}) {
            $error = $exception->message;
        } else {
            $error = $self->{'__CUSTOM_ERRORS__'};
        }

        push(@{$self->{'__ERRORS__'}}, $error);

        $res = FALSE;
    };

    return $res;
}

sub get_errors {
    $_[0]->{'__ERRORS__'} // [];
}

sub _get_type_by_name {
    my ($self, $type_name) = @_;

    unless (exists($self->{'__TYPES__'}{$type_name})) {
        #TODO: use stash and require_class
        my $type_class = 'QBit::Validator::Type::' . $type_name;
        my $type_fn    = "$type_class.pm";
        $type_fn =~ s/::/\//g;

        try {
            require $type_fn;
        }
        catch {
            throw Exception::Validator gettext('Unknown type "%s": %s', $type_name, shift->message);
        };

        $self->{'__TYPES__'}{$type_name} = $type_class->new();
    }

    return $self->{'__TYPES__'}{$type_name};
}

sub throw_exception {
    my ($self) = @_;

    throw Exception::Validator $self->get_all_errors;
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

    my $errors = $self->get_errors;

    my @res = ();
    foreach my $err (@$errors) {
        push(@res, _get_node([], $err));
    }

    return @res;
}

sub _get_node {
    if (ref($_[1]) eq 'HASH') {
        return map {_get_node([@{$_[0]}, $_], $_[1]->{$_})} sort keys(%{$_[1]});
    } else {
        return {path => $_[0], msgs => ref($_[1]) eq 'ARRAY' ? $_[1] : [$_[1]]};
    }
}

sub has_error {
    my ($self, $field) = @_;

    my $key = $self->_get_key($field);

    foreach ($self->get_fields_with_error()) {
        return TRUE if $key eq $self->_get_key($_->{'path'});
    }

    return FALSE;
}

sub has_errors {
    return scalar(@{$_[0]->{'__ERRORS__'} // []});
}

sub _get_key {
    my ($self, $path_field) = @_;

    $path_field //= [];

    $path_field = [$path_field] unless ref($path_field) eq 'ARRAY';

    return join(' => ', @$path_field);
}

TRUE;

__END__

=encoding utf8

=head1 Name

QBit::Validator - It is used for validation of input parameters.

=head1 GitHub

https://github.com/QBitFramework/QBit-Validator

=head1 Install

=over

=item *

cpanm QBit::Validator

=back

=head1 Package methods

=head2 new

create object QBit::Validator and check data using template

B<Arguments:>

=over

=item

B<data> - checking data

=item

B<template> - template for check

=item

B<pre_run> - function is executed before checking

=item

B<app> - model using in check

=item

B<throw> - throw (boolean type, throw exception if an error has occurred)

=back

B<Example:>

  my $data = {
      hello => 'hi, qbit-validator'
  };

  my $qv = QBit::Validator->new(
      data => $data,
      template => {
          type => 'hash',
          fields => {
              hello => {
                  max_len => 5,
              },
          },
      },
  );

=head2 template

get or set template

B<Example:>

  my $template = $qv->template;

  $qv->template($template);

=head2 has_errors

return boolean result (TRUE if an error has occurred or FALSE)

B<Example:>

  if ($qv->has_errors) {
      ...
  }

=head2 data

return data

B<Example:>

  $self->db->table->edit($qv->data) unless $qv->has_errors;

=head2 get_fields_with_error

return list fields with error

B<Example:>

  if ($qv->has_errors) {
      my @fields = $qv->get_fields_with_error;

      ldump(\@fields);

      # [
      #     {
      #         msgs => ['Error'],
      #         path => ['hello']
      #     }
      # ]
      #
      # path => [''] - error in root
  }

=head2 get_error

return error by path

B<Example:>

  if ($qv->has_errors) {
      my $error = $qv->get_error('hello'); # or ['hello']

      print $error; # 'Error'
  }

=head2 get_all_errors

return all errors join "\n"

B<Example:>

  if ($qv->has_errors) {
      my $errors = $qv->get_all_errors();

      print $errors; # 'Error'
  }

=head2 throw_exception

throw Exception::Validator with error message from get_all_errors

B<Example:>

  $qv->throw_exception if $qv->has_errors;

=head1 Default types

=head2 scalar (string/number)

=over

=item

optional

=item

eq

=item

regexp

=item

min

=item

max

=item

len_min

=item

len

=item

len_max

=item

in

=back

For more information see tests

=head2 array (ref array)

=over

=item

optional

=item

size_min

=item

size

=item

size_max

=item

all

=item

contents

=back

For more information see tests

=head2 hash (ref hash)

=over

=item

optional

=item

deps

=item

fields

=item

extra

=item

one_of

=item

any_of

=back

For more information see tests

=cut
