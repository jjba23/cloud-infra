# Joe's Cloud Infra
# Copyright (C) 2024  Josep Jesus Bigorra Algaba (jjbigorra@gmail.com)

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

{ lib, ... }:

let tf = import ../tf.nix { inherit lib; };
in {
  mkZone = { zone, env }: {
    aws_route53_zone."${tf.tfName zone}" = {
      name = zone;
      tags = { Environment = env; };
    };
  };

  mkRecordAliasCloudfront = { name, zone, type, value }: {
    aws_route53_record."${tf.tfName name}" = {
      allow_overwrite = true;
      zone_id = lib.tfRef "aws_route53_zone.${tf.tfName zone}.zone_id";
      inherit name type;

      alias = {
        name = lib.tfRef
          "aws_cloudfront_distribution.${tf.tfName value}.domain_name";
        zone_id = lib.tfRef
          "aws_cloudfront_distribution.${tf.tfName zone}.hosted_zone_id";
        evaluate_target_health = true;
      };
    };
  };

  mkRecord = { name, zone, type, value }: {
    aws_route53_record."${tf.tfName name}" = {
      inherit name type;
      zone_id = lib.tfRef "aws_route53_zone.${tf.tfName zone}.zone_id";
      records = [ value ];
      ttl = 100;
    };
  };
}
