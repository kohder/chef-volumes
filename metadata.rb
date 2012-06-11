name             'volumes'
maintainer       "Rob Lewis"
maintainer_email "rob@kohder.com"
license          "Apache 2.0"
description      "Installs/Configures volumes"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "0.0.5"
recipe           "volumes", "Configures disks/volumes"
depends          "aws"
depends          "lvm"
