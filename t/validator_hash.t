use Test::More tests => 17;

use qbit;
use QBit::Validator;

########
# HASH #
########

ok(!QBit::Validator->new(data => {}, template => {HASH},)->has_errors, 'Use constant HASH');

ok(!QBit::Validator->new(data => undef, template => {HASH, OPT, fields => {key => {}}},)->has_errors, 'HASH and OPT');

ok(QBit::Validator->new(data => [], template => {HASH},)->has_errors, 'Data must be type HASH');

ok(QBit::Validator->new(data => {}, template => {HASH, fields => {key => {}}},)->has_errors, 'Check required keys');

ok(!QBit::Validator->new(data => {}, template => {HASH, fields => {key => {OPT}}},)->has_errors, 'Check key with OPT');

ok(!QBit::Validator->new(data => {key => 1}, template => {HASH, fields => {key => {}}},)->has_errors,
    'Check key with scalar data');

ok(
    QBit::Validator->new(data => {key => 'abc'}, template => {HASH, fields => {key => {regexp => qr/^\d+$/}}},)
      ->has_errors,
    'Check key with scalar data and check data'
  );

ok(
    !QBit::Validator->new(
        data => {key => 'abc', key2 => 5},
        template => {HASH, fields => {key => {regexp => qr/^[abc]{3}$/}, key2 => {eq => 5}}},
      )->has_errors,
    'Check two key with scalar data and check data'
  );

ok(
    QBit::Validator->new(
        data => {key => {key2 => 7}},
        template => {HASH, fields => {key => {HASH, fields => {key2 => {max => 4}}}}},
      )->has_errors,
    'Check key with hash data and check data'
  );

ok(QBit::Validator->new(data => {key => 1, key2 => 2}, template => {HASH, fields => {key => {}}},)->has_errors,
    'Check extra keys');

ok(
    !QBit::Validator->new(data => {key => 1, key2 => 2}, template => {HASH, EXTRA, fields => {key => {}}},)->has_errors,
    'Don\'t check extra keys with EXTRA'
  );

#
# check
#

my $error;
try {
    QBit::Validator->new(data => {key => 1}, template => {HASH, check => undef, fields => {key => {}}},);
}
catch {
    $error = TRUE;
};
ok($error, 'Option "check" must be code');

ok(
    !QBit::Validator->new(
        data     => {key => 2, key2 => 3, key3 => 5},
        template => {
            HASH,
            check => sub {
                $_[1]->{'key3'} != $_[1]->{'key'} + $_[1]->{'key2'} ? gettext('Key3 must be equal key + key2') : '';
            },
            fields => {
                key  => {},
                key2 => {},
                key3 => {}
            }
        },
      )->has_errors,
    'Option "check" (no error)'
  );

ok(
    QBit::Validator->new(
        data     => {key => 2, key2 => 3, key3 => 7},
        template => {
            HASH,
            check => sub {
                $_[1]->{'key3'} != $_[1]->{'key'} + $_[1]->{'key2'} ? gettext('Key3 must be equal key + key2') : '';
            },
            fields => {
                key  => {},
                key2 => {},
                key3 => {}
            }
        },
      )->has_errors,
    'Option "check" (error)'
  );

#
# deps
#

ok(
    !QBit::Validator->new(
        data     => {key => 1, key2 => 2,},
        template => {
            HASH,
            fields => {
                key  => {},
                key2 => {deps => ['key']},
            }
        },
      )->has_errors,
    'Option "deps" (no error)'
  );

ok(
    QBit::Validator->new(
        data     => {key2 => 2,},
        template => {
            HASH,
            fields => {
                key  => {OPT},
                key2 => {deps => ['key']},
            }
        },
      )->has_errors,
    'Option "deps" (error)'
  );

#
# SKIP
#

ok(
    !QBit::Validator->new(
        data     => {key => 1, key2 => {key3 => 3, key4 => 4}},
        template => {
            HASH,
            fields => {
                key  => {},
                key2 => {SKIP},
            }
        },
      )->has_errors,
    'Use SKIP'
  );
