use Test::More tests => 51;
use Test::Deep;

use qbit;
use QBit::Validator;
use Exception::Validator::FailedField;

############
# VARIABLE #
############

#deps with cases

ok(
    !QBit::Validator->new(
        data     => {key => 1, key2 => 2, key3 => 3},
        template => {
            type   => 'hash',
            fields => {
                key  => {},
                key2 => {},
                key3 => {eq => 3},
            },
            deps => {key3 => [qw(key key2)],}
        },
      )->has_errors,
    'Option "deps", all keys exists (no error)'
  );

ok(
    QBit::Validator->new(
        data     => {key => 1, key2 => 2, key3 => 3},
        template => {
            type   => 'hash',
            fields => {
                key  => {},
                key2 => {},
                key3 => {eq => 3},
            },
            deps => {key3 => [qw(key4)],}
        },
      )->has_errors,
    'Option "deps", key does not exists (error)'
  );

ok(
    !QBit::Validator->new(
        data     => {key => 1, key2 => 2, key3 => 3},
        template => {
            type   => 'hash',
            fields => {
                key  => {},
                key2 => {},
                key3 => {eq => 3},
            },
            deps => {
                key3 => {
                    fields => [qw(key key2)],
                    cases  => [[{key => {eq => 2}, key2 => {eq => 2}}, {eq => 2}], [{key => {eq => 2}}, {eq => undef}],]
                },

            }
        },
      )->has_errors,
    'Option "deps", default check (no error)'
  );

ok(
    QBit::Validator->new(
        data     => {key => 1, key2 => 2, key3 => 4},
        template => {
            type   => 'hash',
            fields => {
                key  => {},
                key2 => {},
                key3 => {eq => 3},
            },
            deps => {
                key3 => {
                    fields => [qw(key key2)],
                    cases  => [[{key => {eq => 2}, key2 => {eq => 2}}, {eq => 2}], [{key => {eq => 2}}, {eq => undef}],]
                },
            }
        },
      )->has_errors,
    'Option "deps", default check (error)'
  );

ok(
    QBit::Validator->new(
        data     => {key => 2, key2 => 2, key3 => 3},
        template => {
            type   => 'hash',
            fields => {
                key  => {},
                key2 => {},
                key3 => {eq => 3},
            },
            deps => {
                key3 => {
                    fields => [qw(key key2)],
                    cases  => [[{key => {eq => 2}, key2 => {eq => 2}}, {eq => 2}], [{key => {eq => 2}}, {eq => undef}],]
                },
            }
        },
      )->has_errors,
    'Option "deps", check from cases 1 (error)'
  );

ok(
    !QBit::Validator->new(
        data     => {key => 2, key2 => 2, key3 => 2},
        template => {
            type   => 'hash',
            fields => {
                key  => {},
                key2 => {},
                key3 => {eq => 3},
            },
            deps => {
                key3 => {
                    fields => [qw(key key2)],
                    cases  => [[{key => {eq => 2}, key2 => {eq => 2}}, {eq => 2}], [{key => {eq => 2}}, {eq => undef}],]
                },
            }
        },
      )->has_errors,
    'Option "deps", check from cases 1 (no error)'
  );

ok(
    QBit::Validator->new(
        data     => {key => 2, key2 => 3, key3 => 3},
        template => {
            type   => 'hash',
            fields => {
                key  => {},
                key2 => {},
                key3 => {eq => 3},
            },
            deps => {
                key3 => {
                    fields => [qw(key key2)],
                    cases  => [[{key => {eq => 2}, key2 => {eq => 2}}, {eq => 2}], [{key => {eq => 2}}, {eq => undef}],]
                },
            }
        },
      )->has_errors,
    'Option "deps", check from cases: 2 (error)'
  );

ok(
    !QBit::Validator->new(
        data     => {key => 2, key2 => 3, key3 => undef},
        template => {
            type   => 'hash',
            fields => {
                key  => {},
                key2 => {},
                key3 => {eq => 3},
            },
            deps => {
                key3 => {
                    fields => [qw(key key2)],
                    cases  => [[{key => {eq => 2}, key2 => {eq => 2}}, {eq => 2}], [{key => {eq => 2}}, {eq => undef}],]
                },
            }
        },
      )->has_errors,
    'Option "deps", check from cases: 2 (no error)'
  );

ok(
    !QBit::Validator->new(
        data     => {key => 1, key2 => 2, key3 => 3},
        template => {
            type   => 'hash',
            fields => {
                key  => {},
                key2 => {},
                key3 => {eq => 3},
            },
            deps => {
                key3 => {
                    fields       => [qw(key key2)],
                    set_template => sub {
                        my ($qv, $data) = @_;

                        if ($data->{'key'} == 2 && $data->{'key2'} == 2) {
                            return {eq => 2};
                        } elsif ($data->{'key'} == 2) {
                            return {eq => undef};
                        }
                      }
                },
            }
        },
      )->has_errors,
    'Option "deps", default check (no error)'
  );

ok(
    QBit::Validator->new(
        data     => {key => 1, key2 => 2, key3 => 4},
        template => {
            type   => 'hash',
            fields => {
                key  => {},
                key2 => {},
                key3 => {eq => 3},
            },
            deps => {
                key3 => {
                    fields       => [qw(key key2)],
                    set_template => sub {
                        my ($qv, $data) = @_;

                        if ($data->{'key'} == 2 && $data->{'key2'} == 2) {
                            return {eq => 2};
                        } elsif ($data->{'key'} == 2) {
                            return {eq => undef};
                        }
                      }
                },
            }
        },
      )->has_errors,
    'Option "deps", default check (error)'
  );

ok(
    !QBit::Validator->new(
        data     => {key => 2, key2 => 2, key3 => 2},
        template => {
            type   => 'hash',
            fields => {
                key  => {},
                key2 => {},
                key3 => {eq => 3},
            },
            deps => {
                key3 => {
                    fields       => [qw(key key2)],
                    set_template => sub {
                        my ($qv, $data) = @_;

                        if ($data->{'key'} == 2 && $data->{'key2'} == 2) {
                            return {eq => 2};
                        } elsif ($data->{'key'} == 2) {
                            return {eq => undef};
                        }
                      }
                },
            }
        },
      )->has_errors,
    'Option "deps", check from set_template 2 & 2 (no error)'
  );

ok(
    QBit::Validator->new(
        data     => {key => 2, key2 => 2, key3 => 3},
        template => {
            type   => 'hash',
            fields => {
                key  => {},
                key2 => {},
                key3 => {eq => 3},
            },
            deps => {
                key3 => {
                    fields       => [qw(key key2)],
                    set_template => sub {
                        my ($qv, $data) = @_;

                        if ($data->{'key'} == 2 && $data->{'key2'} == 2) {
                            return {eq => 2};
                        } elsif ($data->{'key'} == 2) {
                            return {eq => undef};
                        }
                      }
                },
            }
        },
      )->has_errors,
    'Option "deps", check from set_template 2 & 2 (error)'
  );

ok(
    !QBit::Validator->new(
        data     => {key => 2, key2 => 3, key3 => undef},
        template => {
            type   => 'hash',
            fields => {
                key  => {},
                key2 => {},
                key3 => {eq => 3},
            },
            deps => {
                key3 => {
                    fields       => [qw(key key2)],
                    set_template => sub {
                        my ($qv, $data) = @_;

                        if ($data->{'key'} == 2 && $data->{'key2'} == 2) {
                            return {eq => 2};
                        } elsif ($data->{'key'} == 2) {
                            return {eq => undef};
                        }
                      }
                },
            }
        },
      )->has_errors,
    'Option "deps", check from set_template 2 & 3 (no error)'
  );

ok(
    QBit::Validator->new(
        data     => {key => 2, key2 => 3, key3 => 3},
        template => {
            type   => 'hash',
            fields => {
                key  => {},
                key2 => {},
                key3 => {eq => 3},
            },
            deps => {
                key3 => {
                    fields       => [qw(key key2)],
                    set_template => sub {
                        my ($qv, $data) = @_;

                        if ($data->{'key'} == 2 && $data->{'key2'} == 2) {
                            return {eq => 2};
                        } elsif ($data->{'key'} == 2) {
                            return {eq => undef};
                        }
                      }
                },
            }
        },
      )->has_errors,
    'Option "deps", check from set_template 2 & 3 (error)'
  );
