my $dir = shift;

my $file = "blib/lib/Taco/ServiceRegistry.pm";
open REG, ">$file" or die $!;
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

chmod 0644, $file or warn "Couldn't 'chmod 0066 $file': $!";
