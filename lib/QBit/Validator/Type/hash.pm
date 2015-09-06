package QBit::Validator::Type::hash;

use qbit;

use base qw(QBit::Validator::Type);

#order is important
my $OPTIONS = [
    {name => 'optional', required => TRUE},
    {name => 'deps'},
    {name => 'fields'},
    {name => 'extra', required => TRUE},
];

sub _get_options {
    return clone($OPTIONS);
}

sub _get_options_name {
    return map {$_->{'name'}} @$OPTIONS;
}

sub optional {
    my ($self, $qv, $data, $template, $option, @path_field) = @_;
    
    if ($template->{$option}) {
        if (defined($data)) {
            unless (ref($data) eq 'HASH') {
                $qv->_add_error($template, gettext('Data must be HASH'), \@path_field);
        
                return FALSE;
            }
        } else {
            $qv->_add_ok(\@path_field);

            return FALSE;
        }
    } else {
        if (!defined($data)) {
            $qv->_add_error($template, gettext('Data must be defined'), \@path_field);
    
            return FALSE;
        } else {
            unless (ref($data) eq 'HASH') {
                $qv->_add_error($template, gettext('Data must be HASH'), \@path_field);
        
                return FALSE;
            }
        }
    }
    
    return TRUE;
}

sub deps {
    my ($self, $qv, $data, $template, $option, @path_field) = @_;

    throw Exception::Validator gettext('Option "%s" must be HASH', $option) unless ref($template->{$option}) eq 'HASH';

    my $no_error = TRUE;

    foreach my $field (keys(%{$template->{$option}})) {
        my @field_path = (@path_field, $field);

        if (exists($data->{$field})) {
            my $deps = $template->{$option}{$field};

            throw Exception::Validator gettext('You must specify the fields on which the field "%s"', $field)
              unless defined($deps);

            $deps = [$deps] unless ref($deps) eq 'ARRAY';

            foreach my $dep_field (@$deps) {
                unless (exists($data->{$dep_field})) {
                    $qv->_add_error($template, gettext('Key "%s" depends from "%s"', $field, $dep_field),
                        \@field_path);

                    $no_error = FALSE;

                    next;
                }

                my @dep_path = (@path_field, $dep_field);

                $qv->_validation($data->{$dep_field}, $template->{'fields'}{$dep_field}, undef, @dep_path)
                  unless $qv->checked(\@dep_path);

                $no_error = FALSE if $qv->has_error(\@dep_path);
            }
        }
    }

    return $no_error;
}

sub fields {
    my ($self, $qv, $data, $template, $option, @path_field) = @_;

    my $no_error = TRUE;

    foreach my $field (keys(%{$template->{$option}})) {
        my @path = (@path_field, $field);

        next if $qv->checked(\@path);

        if (!$template->{$option}{$field}{'optional'} && !exists($data->{$field})) {
            $qv->_add_error($template, gettext('Key "%s" required', $field), \@path);

            $no_error = FALSE;

            next;
        }

        $qv->_validation($data->{$field}, $template->{$option}{$field}, undef, @path);

        $no_error = FALSE if $qv->has_error(\@path);
    }

    return $no_error;
}

sub extra {
    my ($self, $qv, $data, $template, $option, @path_field) = @_;

    my @extra_fields = grep {!$template->{'fields'}{$_}} keys(%$data);

    if (@extra_fields && !$template->{$option}) {
        $qv->_add_error($template, gettext('Extra fields: %s', join(', ', @extra_fields)));

        return FALSE;
    }

    return TRUE;
}

TRUE;
