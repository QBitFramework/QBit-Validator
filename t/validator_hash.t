use Test::More tests => 17;

use qbit;
use QBit::Validator;

########
# HASH #
########

ok(!QBit::Validator->new(data => {}, template => {HASH},)->has_errors, 'Use constant HASH');

ok(!QBit::Validator->new(data => undef, template => {HASH, OPT, key => {}},)->has_errors, 'HASH and OPT');

ok(QBit::Validator->new(data => [], template => {HASH},)->has_errors, 'Data must be type HASH');

ok(QBit::Validator->new(data => {}, template => {HASH, key => {}},)->has_errors, 'Check required keys');

ok(!QBit::Validator->new(data => {}, template => {HASH, key => {OPT}},)->has_errors, 'Check key with OPT');

ok(!QBit::Validator->new(data => {key => 1}, template => {HASH, key => {}},)->has_errors, 'Check key with scalar data');

ok(QBit::Validator->new(data => {key => 'abc'}, template => {HASH, key => {regexp => qr/^\d+$/}},)->has_errors,
    'Check key with scalar data and check data');

ok(
    !QBit::Validator->new(
        data => {key => 'abc', key2 => 5},
        template => {HASH, key => {regexp => qr/^[abc]{3}$/}, key2 => {eq => 5}},
      )->has_errors,
    'Check two key with scalar data and check data'
  );

ok(
    QBit::Validator->new(data => {key => {key2 => 7}}, template => {HASH, key => {HASH, key2 => {max => 4}}},)
      ->has_errors,
    'Check key with hash data and check data'
  );

ok(QBit::Validator->new(data => {key => 1, key2 => 2}, template => {HASH, key => {}},)->has_errors, 'Check extra keys');

ok(!QBit::Validator->new(data => {key => 1, key2 => 2}, template => {HASH, EXTRA, key => {}},)->has_errors,
    'Don\'t check extra keys with __ELEM_EXTRA__');

#
# __ELEM_CHECK__
#

my $error;
try {
    QBit::Validator->new(data => {key => 1}, template => {HASH, __ELEM_CHECK__ => undef, key => {}},);
}
catch {
    $error = TRUE;
};
ok($error, 'Option __ELEM_CHECK__ must be code');

ok(
    !QBit::Validator->new(
        data     => {key => 2, key2 => 3, key3 => 5},
        template => {
            HASH,
            __ELEM_CHECK__ => sub {
                $_[1]->{'key3'} != $_[1]->{'key'} + $_[1]->{'key2'} ? gettext('Key3 must be equal key + key2') : '';
            },
            key  => {},
            key2 => {},
            key3 => {}
        },
      )->has_errors,
    'Option __ELEM_CHECK__ (no error)'
  );

ok(
    QBit::Validator->new(
        data     => {key => 2, key2 => 3, key3 => 7},
        template => {
            HASH,
            __ELEM_CHECK__ => sub {
                $_[1]->{'key3'} != $_[1]->{'key'} + $_[1]->{'key2'} ? gettext('Key3 must be equal key + key2') : '';
            },
            key  => {},
            key2 => {},
            key3 => {}
        },
      )->has_errors,
    'Option __ELEM_CHECK__ (error)'
  );

#
# __ELEM_DEPS__
#

ok(
    !QBit::Validator->new(
        data     => {key => 1, key2 => 2,},
        template => {
            HASH,
            key  => {},
            key2 => {__ELEM_DEPS__ => ['key']},
        },
      )->has_errors,
    'Option __ELEM_DEPS__ (no error)'
  );

ok(
    QBit::Validator->new(
        data     => {key2 => 2,},
        template => {
            HASH,
            key  => {OPT},
            key2 => {__ELEM_DEPS__ => ['key']},
        },
      )->has_errors,
    'Option __ELEM_DEPS__ (error)'
  );

#
# SKIP => HASH, EXTRA
#

ok(
    !QBit::Validator->new(
        data     => {key => 1, key2 => {key3 => 3, key4 => 4}},
        template => {
            HASH,
            key  => {},
            key2 => {SKIP},
        },
      )->has_errors,
    'Option __ELEM_SKIP__'
  );

