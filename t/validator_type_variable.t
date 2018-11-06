use Test::More tests => 51;
use Test::Deep;

use qbit;
use QBit::Validator;
use Exception::Validator::FailedField;

############
# VARIABLE #
############

#ldump(
#    QBit::Validator->new(
#        data     => 10,
#        template => {
#            type   => 'variable',
#            conditions => [
#                {max => 5},
#                {len_max => 1},
#            ]
#        },
#    )
#);
#exit;

#ldump(
#    QBit::Validator->new(
#        data     => 4,
#        template => {
#            type   => 'variable',
#            conditions => [
#                {if => {max => 5}},
#                {if => {len_max => 1}},
#            ]
#        },
#    )
#);
#exit;

#ldump(
#    QBit::Validator->new(
#        data     => {
#            key => 1,
#            key2 => 2,
#        },
#        template => {
#            type => 'hash',
#            fields => {
#                key => {in => [1, 2]},
#                key2 => {
#                    type   => 'variable',
#                    conditions => [
#                        {
#                            if => ['/key' => {eq => 1}],
#                            then => {eq => 2},
#                            else => {eq => 3}
#                        },
#                    ]
#                }
#            },
#            deps => {
#                key2 => 'key'
#            }
#        },
#    )
#);
#exit;

#ldump(
#    QBit::Validator->new(
#        data     => {
#            key => 1,
#            key2 => [
#                {
#                    key => 2,
#                    key2 => 3,
#                },
#                {
#                    key => 1,
#                    key2 => 2,
#                }
#            ],
#        },
#        template => {
#            type => 'hash',
#            fields => {
#                key => {in => [1, 2]},
#                key2 => {
#                    type => 'array',
#                    all => {
#                        type => 'hash',
#                        fields => {
#                            key => {},
#                            key2 => {
#                                type   => 'variable',
#                                conditions => [
#                                    {
#                                        if => ['../key' => {eq => 1}],
#                                        then => {eq => 2},
#                                        else => {eq => 3},
#                                    },
#                                ]
#                            }
#                        },
#                        deps => {
#                            key2 => 'key'
#                        }
#                    }
#                },
#            },
#        },
#    )
#);
#exit;

ldump(
    QBit::Validator->new(
        data => {
            key  => 1,
            key2 => [
                {
                    key3 => 2,
                    key4 => {
                        key5 => 1,
                        key6 => [
                            {
                                key7 => 7,
                                key8 => 8,
                            },
                            {
                                key7 => 7,
                                key8 => 8,
                            },
                        ]
                    },
                },
                {
                    key3 => 2,
                    key4 => {
                        key5 => 1,
                        key6 => [
                            {
                                key7 => 7,
                                key8 => 8,
                            },
                        ]
                    },
                }
            ],
        },
        template => {
            type   => 'hash',
            fields => {
                key  => {},
                key2 => {
                    type => 'array',
                    all  => {
                        type   => 'hash',
                        fields => {
                            key3 => {},
                            key4 => {
                                type   => 'hash',
                                fields => {
                                    key5 => {},
                                    key6 => {
                                        type => 'array',
                                        all  => {
                                            type   => 'hash',
                                            fields => {
                                                key7 => {in => [7, 8]},
                                                key8 => {
                                                    type       => 'variable',
                                                    conditions => [
                                                        {
                                                            if   => ['../key7' => {eq => 7}],
                                                            then => {eq        => 8},
                                                            else => {eq        => 9},
                                                        },
                                                    ]
                                                },
                                            },
                                            deps => {
                                                key8 => 'key7'
                                            }
                                        }
                                    }
                                },
                            }
                        },
                    }
                },
            },
        },
    )
);
exit;

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
