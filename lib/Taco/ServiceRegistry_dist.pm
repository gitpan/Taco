package Taco::Services;

# To add services to Taco, add entries to the %Services::registry hash.
# Type "perldoc Taco::ServiceRegistry" for more information.


# Any modules you want to use must be loaded here:
use Taco::Generic;


$root_dir = "/your/directory/here";

# Set up the services here:
%registry = (

  "test_service" => {
    "Modules" => [ "Taco::Generic" ],
    "TemplatePath" => ["t/templates", "/etc/templates"],
  },
);

1;
