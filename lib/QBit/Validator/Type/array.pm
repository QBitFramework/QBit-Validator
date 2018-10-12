package QBit::Validator::Type::array;

use qbit;

use base qw(QBit::Validator::Type);

use Exception::Validator;
use Exception::Validator::FailedField;

#order is important
sub get_options_name {
    qw(type size_min size size_max all contents);
}

sub type {
    return sub {
        throw gettext('Data must be ARRAY') unless ref($_[1]) eq 'ARRAY';

        return TRUE;
      }
}

sub size_min {
    my ($qv, $size_min) = @_;

    throw Exception::Validator gettext('Option "%s" must be positive number', 'size_min')
      if !defined($size_min) || $size_min !~ /\A[0-9]+\z/;

    return sub {
        throw FF gettext('Data size "%s" less then "%s"', scalar(@{$_[1]}), $size_min) if @{$_[1]} < $size_min;

        return TRUE;
    };
}

sub size {
    my ($qv, $size) = @_;

    throw Exception::Validator gettext('Option "%s" must be positive number', 'size')
      if !defined($size) || $size !~ /\A[0-9]+\z/;

    return sub {
        throw FF gettext('Data size "%s" not equal "%s"', scalar(@{$_[1]}), $size) unless @{$_[1]} == $size;

        return TRUE;
    };
}

sub size_max {
    my ($qv, $size_max) = @_;

    throw Exception::Validator gettext('Option "%s" must be positive number', 'size_max')
      if !defined($size_max) || $size_max !~ /\A[0-9]+\z/;

    return sub {
        throw FF gettext('Data size "%s" more than "%s"', scalar(@{$_[1]}), $size_max) if @{$_[1]} > $size_max;

        return TRUE;
    };
}

sub all {
    my ($qv, $template) = @_;

    my $dpath = $qv->dpath;

    my $new_qv = QBit::Validator->new(template => $template);
    $new_qv->data($qv->data);

    return sub {
        my %errors = ();
        my $num    = 0;
        foreach (@{$_[1]}) {
            $new_qv->dpath($dpath . "$num/");

            unless ($new_qv->validate($_)) {
                $errors{$num} = $new_qv->get_errors;
            }

            $num++;
        }

        throw FF \%errors if %errors;

        return TRUE;
    };
}

sub contents {
    my ($qv, $templates) = @_;

    throw Exception::Validator gettext('Option "%s" must be ARRAY', 'contents')
      if !defined($templates) || ref($templates) ne 'ARRAY';

    my $dpath = $qv->dpath;
    my $data = $qv->data;

    my @validators = ();
    my $i = 0;
    foreach my $template (@$templates) {
        my $validator = QBit::Validator->new(template => $template, dpath => $dpath . "$i/");

        $validator->data($data);

        push(@validators, $validator);

        $i++;
    }

    return sub {
        throw FF gettext('Data size "%s" no equal "%s"', scalar(@{$_[1]}), scalar(@validators))
          unless @{$_[1]} == @validators;

        my %errors = ();
        my $num    = 0;
        foreach (@{$_[1]}) {
            unless ($validators[$num]->validate($_)) {
                $errors{$num} = $validators[$num]->get_errors;
            }

            $num++;
        }

        throw FF \%errors if %errors;

        return TRUE;
    };
}

sub init {
    my ($self) = @_;

    $self->SUPER::init();

    foreach ($self->get_options_name) {
        $self->{$_} = \&$_;
    }
}

TRUE;
