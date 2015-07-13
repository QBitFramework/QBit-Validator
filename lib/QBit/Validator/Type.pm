package QBit::Validator::Type;

use qbit;

use base qw(QBit::Class);

__PACKAGE__->abstract_methods(qw(get_template));

TRUE;
