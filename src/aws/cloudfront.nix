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
let
  tf = import ../tf.nix { inherit lib; };
  defaultForwardedValues = {
    query_string = false;
    headers = [ "Origin" ];

    cookies = { forward = "none"; };
  };
  defaultInstanceForwardedValues = {
    query_string = true;
    headers = [ "*" ];

    cookies = { forward = "all"; };
  };
  defaultCustomErrorResponse = {
    response_code = 200;
    response_page_path = "/index.html";
    error_code = 404;
    error_caching_min_ttl = 60;
  };
in {
  mkBucketDistribution = { bucket, description, env, certificateArn ? ""
    , priceClass ? "PriceClass_100", aliases ? [ ]
    , customErrorResponse ? defaultCustomErrorResponse
    , allowedMethods ? [ "DELETE" "GET" "HEAD" "OPTIONS" "PATCH" "POST" "PUT" ]
    , cachedMethods ? [ "GET" "HEAD" "OPTIONS" ], minTTL ? 0, defaultTTL ? 100
    , maxTTL ? 300, hasCors ? false, corsOrigins ? [ ], customHeaders ? [ ] }: {

      aws_cloudfront_distribution."${tf.tfName bucket}" = {
        origin = {
          domain_name = lib.tfRef "aws_s3_bucket_website_configuration.${
              tf.tfName bucket
            }.website_endpoint";
          origin_id = lib.tfRef
            "aws_s3_bucket_website_configuration.${tf.tfName bucket}.id";

          custom_origin_config = {
            http_port = 80;
            https_port = 443;
            origin_keepalive_timeout = 5;
            origin_protocol_policy = "http-only";
            origin_read_timeout = 30;
            origin_ssl_protocols = [ "TLSv1.2" ];
          };
        };

        inherit aliases;
        enabled = true;
        is_ipv6_enabled = true;
        comment = description;
        price_class = priceClass;
        default_root_object = "index.html";

        tags = { Environment = env; };

        viewer_certificate = {
          acm_certificate_arn = certificateArn;
          ssl_support_method = "sni-only";
        };

        default_cache_behavior = {
          allowed_methods = allowedMethods;
          cached_methods = cachedMethods;
          target_origin_id = lib.tfRef "aws_s3_bucket.${tf.tfName bucket}.id";
          forwarded_values = defaultForwardedValues;
          viewer_protocol_policy = "redirect-to-https";
          min_ttl = minTTL;
          default_ttl = defaultTTL;
          max_ttl = maxTTL;
          response_headers_policy_id = lib.mkIf hasCors (lib.tfRef
            "aws_cloudfront_response_headers_policy.${tf.tfName bucket}.id");
        };

        custom_error_response = customErrorResponse;
        restrictions = {
          geo_restriction = {
            restriction_type = "blacklist";
            locations = [ "RU" ];
          };
        };
      };

      aws_cloudfront_response_headers_policy."${tf.tfName bucket}" =
        lib.mkIf hasCors {
          name = tf.tfName bucket;
          cors_config = {
            access_control_allow_credentials = true;
            access_control_allow_headers = { items = [ "origin" "accept" ]; };
            access_control_allow_methods = { items = [ "GET" ]; };
            access_control_allow_origins = { items = corsOrigins; };
            origin_override = true;
          };
          custom_headers_config = { items = customHeaders; };
        };

      aws_cloudfront_origin_access_control."${tf.tfName bucket}" = {
        name = tf.tfName bucket;
        inherit description;
        origin_access_control_origin_type = "s3";
        signing_behavior = "always";
        signing_protocol = "sigv4";
      };
    };

  mkInstanceDistribution = { cf, instance, description, env, certificateArn ? ""
    , priceClass ? "PriceClass_100", aliases ? [ ]
    , allowedMethods ? [ "DELETE" "GET" "HEAD" "OPTIONS" "PATCH" "POST" "PUT" ]
    , cachedMethods ? [ "HEAD" "GET" "OPTIONS" ], httpPort ? 80, httpsPort ? 443
    }: {

      aws_cloudfront_distribution."${tf.tfName cf}" = {
        origin = {
          domain_name =
            lib.tfRef "aws_instance.${tf.tfName instance}.public_dns";

          origin_id = lib.tfRef "aws_instance.${tf.tfName instance}.id";

          custom_origin_config = {
            http_port = httpPort;
            https_port = httpsPort;
            origin_keepalive_timeout = 5;
            origin_protocol_policy = "http-only";
            origin_read_timeout = 30;
            origin_ssl_protocols = [ "TLSv1.2" ];
          };
        };

        inherit aliases;
        enabled = true;
        is_ipv6_enabled = false;
        comment = description;
        price_class = priceClass;

        tags = { Environment = env; };

        viewer_certificate = {
          acm_certificate_arn = certificateArn;
          ssl_support_method = "sni-only";
        };

        default_cache_behavior = {
          allowed_methods = allowedMethods;
          cached_methods = cachedMethods;
          target_origin_id = lib.tfRef "aws_instance.${tf.tfName instance}.id";
          forwarded_values = defaultInstanceForwardedValues;
          viewer_protocol_policy = "redirect-to-https";
          min_ttl = 0;
          default_ttl = 100;
          max_ttl = 300;
        };

        restrictions = {
          geo_restriction = {
            restriction_type = "blacklist";
            locations = [ "RU" ];
          };
        };
      };

    };
}

