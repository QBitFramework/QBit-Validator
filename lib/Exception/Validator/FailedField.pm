package Exception::Validator::FailedField;

use base qw(Exception::Validator);

sub import {
    FF->export_to_level(1);
}

package FF;

use base qw(Exception::Validator::FailedField Exporter);

1;
