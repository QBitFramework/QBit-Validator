use Test::More tests => 23;

use qbit;
use QBit::Validator;

#########
# ARRAY #
#########

ok(QBit::Validator->new(data => undef, template => {ARRAY},)->has_errors, 'Use type ARRAY and data = undef');

ok(!QBit::Validator->new(data => undef, template => {ARRAY, OPT},)->has_errors, 'Use OPT and data = undef');

ok(QBit::Validator->new(data => 'scalar', template => {ARRAY},)->has_errors, 'Use type ARRAY and data = scalar');

ok(QBit::Validator->new(data => {}, template => {ARRAY},)->has_errors, 'Use type ARRAY and data = hash');

ok(!QBit::Validator->new(data => [], template => {ARRAY},)->has_errors, 'Use type ARRAY and data = array');

#
# size_min
#

my $error;
try {
    QBit::Validator->new(data => [], template => {ARRAY, size_min => -3},);
}
catch {
    $error = TRUE;
};
ok($error, 'Option "size_min" must be positive number');

ok(
    !QBit::Validator->new(
        data     => [1, 2],
        template => {
            ARRAY,
            size_min => 1,
        },
      )->has_errors,
    'Option "size_min" (no error)'
  );

ok(
    QBit::Validator->new(
        data     => [1, 2],
        template => {
            ARRAY,
            size_min => 3,
        },
      )->has_errors,
    'Option "size_min" (error)'
  );

#
# size
#

$error = FALSE;
try {
    QBit::Validator->new(data => [], template => {ARRAY, size => undef},);
}
catch {
    $error = TRUE;
};
ok($error, 'Option "size" must be positive number');

ok(
    !QBit::Validator->new(
        data     => [],
        template => {
            ARRAY,
            size => 0,
        },
      )->has_errors,
    'Option "size" (no error)'
  );

ok(
    QBit::Validator->new(
        data     => [1, 2],
        template => {
            ARRAY,
            size => 1,
        },
      )->has_errors,
    'Option "size" (error)'
  );

#
# size_max
#

$error = FALSE;
try {
    QBit::Validator->new(data => [], template => {ARRAY, size_max => 3.4},);
}
catch {
    $error = TRUE;
};
ok($error, 'Option "size_max" must be positive number');

ok(
    !QBit::Validator->new(
        data     => [1, 2],
        template => {
            ARRAY,
            size_max => 3,
        },
      )->has_errors,
    'Option "size_max" (no error)'
  );

ok(
    QBit::Validator->new(
        data     => [1, 2],
        template => {
            ARRAY,
            size_max => 1,
        },
      )->has_errors,
    'Option "size_max" (error)'
  );

#
# all
#

$error = FALSE;
try {
    QBit::Validator->new(data => [], template => {ARRAY, all => undef},);
}
catch {
    $error = TRUE;
};
ok($error, 'Option "all" must be HASH');

ok(
    !QBit::Validator->new(
        data     => [1, 20, 300],
        template => {
            ARRAY,
            all => {},
        },
      )->has_errors,
    'Option "all" (no error)'
  );

ok(
    QBit::Validator->new(
        data     => [1, 20, 300],
        template => {
            ARRAY,
            all => {max => 30},
        },
      )->has_errors,
    'Option "all" (error)'
  );

#
# contents
#

$error = FALSE;
try {
    QBit::Validator->new(data => [], template => {ARRAY, contents => undef},);
}
catch {
    $error = TRUE;
};
ok($error, 'Option "contents" must be ARRAY');

ok(
    !QBit::Validator->new(
        data     => [1, {key => 2}, 'qbit'],
        template => {
            ARRAY,
            contents => [{}, {HASH, fields => {key => {}}}, {in => 'qbit'}],
        },
      )->has_errors,
    'Option "contents" (no error)'
  );

ok(
    QBit::Validator->new(
        data     => [1, {key => 2}, 'qbit'],
        template => {
            ARRAY,
            contents => [{}, {HASH, key => {}},],
        },
      )->has_errors,
    'Option "contents" (error)'
  );

#
# check
#

$error = FALSE;
try {
    QBit::Validator->new(data => [], template => {ARRAY, check => undef,},);
}
catch {
    $error = TRUE;
};
ok($error, 'Option "check" must be code');

ok(
    !QBit::Validator->new(
        data     => [1, 2, 3],
        template => {
            ARRAY,
            check => sub {
                $_[1]->[2] != $_[1]->[0] + $_[1]->[1] ? gettext('[2] must be equal [0] + [1]') : '';
            },
        },
      )->has_errors,
    'Option "check" (no error)'
  );

ok(
    QBit::Validator->new(
        data     => [1, 2, 4],
        template => {
            ARRAY,
            check => sub {
                $_[1]->[2] != $_[1]->[0] + $_[1]->[1] ? gettext('[2] must be equal [0] + [1]') : '';
            },
        },
      )->has_errors,
    'Option "check" (error)'
  );

