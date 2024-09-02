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
  mkBucket = { bucket, description, env, isPublicBucket ? false
    , isStaticWebsiteBucket ? false, isVersionedBucket ? false }: {
      aws_s3_bucket."${tf.tfName bucket}" = {
        inherit bucket;
        tags = {
          Name = description;
          Environment = env;
        };
      };

      aws_s3_bucket_website_configuration."${tf.tfName bucket}" =
        lib.mkIf isStaticWebsiteBucket {
          inherit bucket;
          index_document = { suffix = "index.html"; };
          error_document = { key = "index.html"; };
        };

      aws_s3_bucket_ownership_controls."${tf.tfName bucket}" =
        lib.mkIf isPublicBucket {
          inherit bucket;
          rule = { object_ownership = "BucketOwnerPreferred"; };
        };

      aws_s3_bucket_public_access_block."${tf.tfName bucket}" =
        lib.mkIf isPublicBucket {
          inherit bucket;
          block_public_acls = false;
          block_public_policy = false;
          ignore_public_acls = false;
          restrict_public_buckets = false;
        };

      aws_s3_bucket_policy."${tf.tfName bucket}-public-read" =
        lib.mkIf isPublicBucket {
          inherit bucket;

          policy = builtins.toJSON {
            Version = "2012-10-17";
            Statement = [{
              Sid = "PublicRead";
              Effect = "Allow";
              Principal = "*";
              Action = "s3:GetObject";
              Resource = "\${aws_s3_bucket.${tf.tfName bucket}.arn}/*";
            }];
          };
        };
      aws_s3_bucket_versioning."${tf.tfName bucket}" =
        lib.mkIf isVersionedBucket {
          bucket = lib.tfRef "aws_s3_bucket.${tf.tfName bucket}.id";
          versioning_configuration = { status = "Enabled"; };
        };
    };
}
