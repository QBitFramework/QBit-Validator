use Test::More tests => 34;

use qbit;
use QBit::Validator;

ok(QBit::Validator->new()->has_errors, 'Default - all data required');

ok(!QBit::Validator->new(template => {OPT})->has_errors, 'Use OPT');

##########
# SCALAR #
##########

ok(QBit::Validator->new(data => [], template => {},)->has_errors, 'Default type: SCALAR');

#
# regexp
#
my $error = FALSE;
try {
    QBit::Validator->new(data => 23, template => {regexp => 'regexp'},);
}
catch {
    $error = TRUE;
};
ok($error, 'Check "regexp" for scalar (bad regexp)');

ok(!QBit::Validator->new(data => 23, template => {regexp => qr/^\d+$/},)->has_errors,
    'Check "regexp" for scalar (no error)');

ok(QBit::Validator->new(data => '23a', template => {regexp => qr/^\d+$/},)->has_errors,
    'Check "regexp" for scalar (error)');

#
# min
#

$error = FALSE;
try {
    QBit::Validator->new(data => 7, template => {min => undef},);
}
catch {
    $error = TRUE;
};
ok($error, 'Check "min" for scalar (bad min)');

ok(!QBit::Validator->new(data => 7, template => {min => 5},)->has_errors, 'Check "min" for scalar (no error)');

ok(QBit::Validator->new(data => 5, template => {min => 7},)->has_errors, 'Check "min" for scalar (error)');

#
# eq
#

$error = FALSE;
try {
    QBit::Validator->new(data => 7, template => {eq => undef},);
}
catch {
    $error = TRUE;
};
ok($error, 'Check "eq" for scalar (bad eq)');

ok(!QBit::Validator->new(data => 7, template => {eq => 7},)->has_errors, 'Check "eq" for scalar (no error)');

ok(QBit::Validator->new(data => 7, template => {eq => 5},)->has_errors, 'Check "eq" for scalar (error)');

#
# max
#

$error = FALSE;
try {
    QBit::Validator->new(data => 7, template => {max => undef},);
}
catch {
    $error = TRUE;
};
ok($error, 'Check "max" for scalar (bad max)');

ok(!QBit::Validator->new(data => 5, template => {max => 7},)->has_errors, 'Check "max" for scalar (no error)');

ok(QBit::Validator->new(data => 7, template => {max => 5},)->has_errors, 'Check "max" for scalar (error)');

#
# len_min
#

$error = FALSE;
try {
    QBit::Validator->new(data => 1234567, template => {len_min => undef},);
}
catch {
    $error = TRUE;
};
ok($error, 'Check "len_min" for scalar (bad len_min)');

ok(!QBit::Validator->new(data => 1234567, template => {len_min => 5},)->has_errors,
    'Check "len_min" for scalar (no error)');

ok(QBit::Validator->new(data => 12345, template => {len_min => 7},)->has_errors, 'Check "len_min" for scalar (error)');

#
# len
#

$error = FALSE;
try {
    QBit::Validator->new(data => 1234567, template => {len => undef},);
}
catch {
    $error = TRUE;
};
ok($error, 'Check "len" for scalar (bad len)');

ok(!QBit::Validator->new(data => 1234567, template => {len => 7},)->has_errors, 'Check "len" for scalar (no error)');

ok(QBit::Validator->new(data => 1234567, template => {len => 5},)->has_errors, 'Check "len" for scalar (error)');

#
# len_max
#

$error = FALSE;
try {
    QBit::Validator->new(data => 1234567, template => {len_max => undef},);
}
catch {
    $error = TRUE;
};
ok($error, 'Check "len_max" for scalar (bad len_max)');

ok(!QBit::Validator->new(data => 12345, template => {len_max => 7},)->has_errors,
    'Check "len_max" for scalar (no error)');

ok(QBit::Validator->new(data => 1234567, template => {len_max => 5},)->has_errors,
    'Check "len_max" for scalar (error)');

#
# in
#

$error = FALSE;
try {
    QBit::Validator->new(data => 'qbit', template => {in => undef},);
}
catch {
    $error = TRUE;
};
ok($error, 'Check "in" for scalar (bad in)');

ok(!QBit::Validator->new(data => 'qbit', template => {in => 'qbit'},)->has_errors, 'Check "in" for scalar (no error)');

ok(!QBit::Validator->new(data => 'qbit', template => {in => [qw(qbit 7)]},)->has_errors,
    'Check "in" for scalar (no error)');

ok(QBit::Validator->new(data => 5, template => {in => 7},)->has_errors, 'Check "in" for scalar (error)');

#
# check
#

$error = FALSE;
try {
    QBit::Validator->new(data => 'qbit', template => {check => undef},);
}
catch {
    $error = TRUE;
};
ok($error, 'Option "check" must be code');

ok(
    !QBit::Validator->new(
        data     => 'qbit',
        template => {
            check => sub {
                $_[1] ne 'qbit' ? gettext('Data must be equal "qbit"') : '';
              }
        },
      )->has_errors,
    'Option "check" (no error)'
  );

ok(
    QBit::Validator->new(
        data     => 5,
        template => {
            check => sub {
                $_[1] == 5 ? gettext('Data must be no equal 5') : '';
              }
        },
      )->has_errors,
    'Option "check" (error)'
  );

#
# msg
#

is(
    QBit::Validator->new(data => 5, template => {in => 7, max => 2,},)->get_all_errors,
    join("\n", gettext('Data more than "%s"', 2), gettext('Data not in array: %s', 7)),
    'Get all errors'
  );

is(QBit::Validator->new(data => 5, template => {in => 7, max => 2, msg => 'my error msg'},)->get_error(),
    'my error msg', 'Get my error');

#
# throw_exception => TRUE
#

$error = FALSE;
try {
    QBit::Validator->new(data => 5, template => {in => 7, max => 2,}, throw_exception => TRUE);
}
catch Exception::Validator with {
    $error = TRUE;
};
ok($error, 'throw Exception');
