my $dir = shift;

open REG, ">./blib/lib/Taco/ServiceRegistry.pm" or die $!;
print REG <<EOF;

package Taco::Services;
use Taco::DB;

\$root_dir = "$dir/t";

%registry = (

  "test_service" => {
    "Modules" => [ "Taco::Generic" ],
    "ServiceDir" => "$dir/t",
  },
);

1;

EOF

close REG;
