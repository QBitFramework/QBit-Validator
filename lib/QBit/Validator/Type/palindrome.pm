package QBit::Validator::Type::palindrome;

use qbit;

use base qw(QBit::Validator::Type);

sub get_template {
    return {
        type    => 'scalar',
        len_min => 1,
        check   => sub {
            $_[1] eq reverse($_[1]) ? '' : gettext('String is not a palindrome');
          },
      }
}

TRUE;
