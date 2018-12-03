package QBit::Validator::PathManager;

use qbit;

use base qw(QBit::Class);

use Exception::Validator::PathManager;

__PACKAGE__->mk_ro_accessors(qw(root delimiter concatenat hash_path array_path));

sub init {
    my ($self) = @_;

    $self->{'root'} = '/';

    $self->{'delimiter'} = '/';

    $self->{'concatenat'} = sub {"$_[0]$_[2]$_[1]"};

    $self->{'hash_path'} = sub {$_[0]};

    $self->{'array_path'} = sub {"[$_[0]]"};
}

sub get_absolute_path {
    my ($self, $path, $root_path) = @_;

    my $root = $self->root;

    return $path if $path =~ /^\Q$root\E/;

    my $delimiter = $self->delimiter;

    $root_path //= $root;

    return $self->concatenat->($root_path, $delimiter, $path);
}

sub get_path_part {
    my ($self, $type, $value) = @_;

    if ($type eq 'hash') {
        $value =~ s/%/%%/g;

        return $self->hash_path->($value);
    } elsif ($type eq 'array') {
        return $self->array_path->($value);
    } else {
        throw Exception::Validator::PathManager gettext('Unknown method: %s', $type);
    }
}

sub set_dynamic_part {push(@{$_[0]->{'__DYNAMIC__'}}, $_[1])}

sub reset_dynamic_part {pop(@{$_[0]->{'__DYNAMIC__'}})}

sub get_current_node_path {
    sprintf($_[1], map {$$_} @{$_[0]->{'__DYNAMIC__'}});
}

#TODO: check speed - get_data_by_path vs get_data_by_path2 and all packages:
#JSON::Pointer, JSON::Path
#Data::Path, Data::DPath, Data::SPath, Data::Nested
sub get_data_by_path {
    my ($self, $path, $data) = @_;
    #/a/[0]/b/[1]

    my $root = $self->root;
    $path =~ s/^\Q$root\E//;

    my @parts = split($self->delimiter, $path);

    my @perl_path = ();
    foreach (@parts) {
        if ($_ eq '.') {
            #nothing
        } elsif ($_ eq '..') {
            pop(@perl_path);
        } elsif ($_ =~ /^\[/) {
            push(@perl_path, $_);
        } else {
            push(@perl_path, "{$_}");
        }
    }

    return $data unless @perl_path;

    my $code = 'sub {$_[0]->' . join('', @perl_path) . '}';

    my $sub = eval($code) or throw Exception::Validator::PathManager gettext("%s\nCODE:\n%s", $@, $code);

    return $sub->($data);
}

sub get_data_by_path2 {
    my ($self, $path, $data) = @_;
    #/a/0/b/1
    # Этот вариант предпочтительней так как путь можно будет передавать [qw(a 0 b 1)]

    my $root = $self->root;
    $path =~ s/^\Q$root\E//;

    #TODO: removed .
    $path =~ s/\/[a-zA-Z_]+\/\.\.//g;

    my @parts = split($self->delimiter, $path);

    my $current = $data;
    foreach (@parts) {
        if (ref($data) eq 'HASH') {
            $current = $current->{$_};
        } elsif (ref($data) eq 'ARRAY') {
            $current = $current->[$_];
        } else {
            throw Exception::Validator::PathManager gettext('Unknow type: %s', ref($data));
        }
    }

    return $current;
}

TRUE;
