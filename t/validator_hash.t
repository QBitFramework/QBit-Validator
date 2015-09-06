use Test::More tests => 17;

use qbit;
use QBit::Validator;

########
# HASH #
########

ok(!QBit::Validator->new(data => {}, template => {type => 'hash'},)->has_errors, 'Use constant type => \'hash\'');

ok(
    !QBit::Validator->new(data => undef, template => {type => 'hash', optional => TRUE, fields => {key => {}}},)
      ->has_errors,
    'type => \'hash\' and optional => TRUE'
  );

ok(QBit::Validator->new(data => [], template => {type => 'hash'},)->has_errors, 'Data must be type type => \'hash\'');

ok(QBit::Validator->new(data => {}, template => {type => 'hash', fields => {key => {}}},)->has_errors,
    'Check required keys');

ok(
    !QBit::Validator->new(data => {}, template => {type => 'hash', fields => {key => {optional => TRUE}}},)->has_errors,
    'Check key with optional => TRUE'
  );

ok(!QBit::Validator->new(data => {key => 1}, template => {type => 'hash', fields => {key => {}}},)->has_errors,
    'Check key with scalar data');

ok(
    QBit::Validator->new(
        data     => {key  => 'abc'},
        template => {type => 'hash', fields => {key => {regexp => qr/^\d+$/}}},
      )->has_errors,
    'Check key with scalar data and check data'
  );

ok(
    !QBit::Validator->new(
        data     => {key  => 'abc',  key2   => 5},
        template => {type => 'hash', fields => {key => {regexp => qr/^[abc]{3}$/}, key2 => {eq => 5}}},
      )->has_errors,
    'Check two key with scalar data and check data'
  );

ok(
    QBit::Validator->new(
        data => {key => {key2 => 7}},
        template => {type => 'hash', fields => {key => {type => 'hash', fields => {key2 => {max => 4}}}}},
      )->has_errors,
    'Check key with hash data and check data'
  );

ok(
    QBit::Validator->new(data => {key => 1, key2 => 2}, template => {type => 'hash', fields => {key => {}}},)
      ->has_errors,
    'Check extra keys'
  );

ok(
    !QBit::Validator->new(data => {key => 1, key2 => 2}, template => {type => 'hash', extra => TRUE, fields => {key => {}}},)
      ->has_errors,
    'Don\'t check extra keys with extra => TRUE'
  );

#
# check
#

my $error;
try {
    QBit::Validator->new(data => {key => 1}, template => {type => 'hash', check => undef, fields => {key => {}}},);
}
catch {
    $error = TRUE;
};
ok($error, 'Option "check" must be code');

ok(
    !QBit::Validator->new(
        data     => {key => 2, key2 => 3, key3 => 5},
        template => {
            type  => 'hash',
            check => sub {
                throw FF gettext('Key3 must be equal key + key2') if $_[1]->{'key3'} != $_[1]->{'key'} + $_[1]->{'key2'};
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
            type  => 'hash',
            check => sub {
                throw FF gettext('Key3 must be equal key + key2') if $_[1]->{'key3'} != $_[1]->{'key'} + $_[1]->{'key2'};
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
            type   => 'hash',
            fields => {
                key  => {},
                key2 => {},
            },
            deps => {
                key2 => 'key'
            }
        },
      )->has_errors,
    'Option "deps" (no error)'
  );

ok(
    QBit::Validator->new(
        data     => {key2 => 2,},
        template => {
            type   => 'hash',
            fields => {
                key  => {optional => TRUE},
                key2 => {},
            },
            deps => {
                key2 => ['key'],
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
            type   => 'hash',
            fields => {
                key  => {},
                key2 => {skip => TRUE},
            }
        },
      )->has_errors,
    'Use SKIP'
  );
