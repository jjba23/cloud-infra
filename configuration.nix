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

{ config, lib, ... }:

let
  tf = import ./src/tf.nix { inherit lib; };
  s3 = import ./src/aws/s3.nix { inherit lib; };
  cloudfront = import ./src/aws/cloudfront.nix { inherit config lib; };
  acm = import ./src/aws/acm.nix { inherit config lib; };
  route53 = import ./src/aws/route53.nix { inherit lib; };
  prl = import ./src/prelude.nix;
  ec2 = import ./src/aws/ec2.nix { inherit lib; };
  sqs = import ./src/aws/sqs.nix { inherit lib; };
  iam = import ./src/aws/iam.nix { inherit lib; };

  region = "eu-west-3";
  alternativeRegion = "us-east-1";
  v = "lambda-35";
  prod = "Production";

  certificates = [
    (prl.prodCertificate {
      domainName = "carvoeirowaterfun.com";
      alternativeNames = [ "www.carvoeirowaterfun.com" ];
    })
    (prl.prodCertificate {
      domainName = "jointhefreeworld.org";
      alternativeNames = [ "www.jointhefreeworld.org" ];
    })
    (prl.prodCertificate {
      domainName = "assets.wikimusic.jointhefreeworld.org";
    })
    (prl.prodCertificate {
      domainName = "wikimusic.jointhefreeworld.org";
      alternativeNames = [ "www.wikimusic.jointhefreeworld.org" ];
    })
    (prl.prodCertificate {
      domainName = "grafana.jointhefreeworld.org";
      alternativeNames = [ ];
    })
    (prl.prodCertificate {
      domainName = "prometheus.jointhefreeworld.org";
      alternativeNames = [ ];
    })
    (prl.prodCertificate { domainName = "api.wikimusic.jointhefreeworld.org"; })
    (prl.prodCertificate {
      domainName = "casadelcata.es";
      alternativeNames = [ "www.casadelcata.es" ];
    })
  ];

  instances = [{
    name = "jjba-${v}";
    env = prod;
    instanceType = "m7g.medium";
    availabilityZone = "eu-west-3a";
    publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIJDyoK3CG6oBA+YsYwJTv7Ue+438rQ3xaxwwUIbAfUU";
    publicKeyName = "gitlab_prive";
    userData = builtins.readFile ./src/user-data/jjba.bash;
    ingressRules = [
      {
        port = "50050";
        groupName = "jjba-${v}";
        cidr = "0.0.0.0/0";
      }
      {
        port = "6923";
        groupName = "jjba-${v}";
        cidr = "0.0.0.0/0";
      }
      {
        port = "443";
        groupName = "jjba-${v}";
        cidr = "0.0.0.0/0";
      }
      {
        port = "80";
        groupName = "jjba-${v}";
        cidr = "0.0.0.0/0";
      }
      {
        port = "22";
        groupName = "jjba-${v}";
        cidr = "0.0.0.0/0";
      }
      {
        port = "7979";
        groupName = "jjba-${v}";
        cidr = "0.0.0.0/0";
      }
    ];
    canManageBuckets = true;
    canManageSecrets = true;
    canManageQueues = true;
  }];

  records = [
    {
      name = "_dmarc.jointhefreeworld.org";
      type = "TXT";
      value = "v=DMARC1; p=none;";
      zone = "jointhefreeworld.org";
    }
    {
      name = "q4y7axv3bw3lnfvj4e24vzy7m4p47zeo._domainkey.jointhefreeworld.org";
      type = "CNAME";
      value = "q4y7axv3bw3lnfvj4e24vzy7m4p47zeo.dkim.amazonses.com";
      zone = "jointhefreeworld.org";
    }
    {
      name = "cfobj3hbwz4xxhbzzzsrg3kw7rbpes3u._domainkey.jointhefreeworld.org";
      type = "CNAME";
      value = "cfobj3hbwz4xxhbzzzsrg3kw7rbpes3u.dkim.amazonses.com";
      zone = "jointhefreeworld.org";
    }
    {
      name = "wglhx2sadvsh3cnza3y5nnm4panonw2u._domainkey.jointhefreeworld.org";
      type = "CNAME";
      value = "wglhx2sadvsh3cnza3y5nnm4panonw2u.dkim.amazonses.com";
      zone = "jointhefreeworld.org";
    }
  ];

  buckets = [
    {
      bucket = "cloud-infra-state-jjba";
      description = "Cloud Infrastructure State";
      env = prod;
      isVersionedBucket = true;
    }
    (prl.prodPublicStaticWebsiteBucket "carvoeirowaterfun.com")
    (prl.prodPublicStaticWebsiteBucket "jointhefreeworld.org")
    (prl.prodPublicStaticWebsiteBucket "casadelcata.es")
    (prl.prodPublicStaticWebsiteBucket "assets.wikimusic.jointhefreeworld.org")
  ];

  zones = [
    {
      zone = "jointhefreeworld.org";
      env = prod;
    }
    {
      zone = "casadelcata.es";
      env = prod;
    }
    {
      zone = "carvoeirowaterfun.com";
      env = prod;
    }
  ];

  cloudfrontRecords = [
    {
      name = "jointhefreeworld.org";
      zone = "jointhefreeworld.org";
      value = "jointhefreeworld.org";
      type = "A";
    }
    {
      name = "www.jointhefreeworld.org";
      zone = "jointhefreeworld.org";
      value = "jointhefreeworld.org";
      type = "A";
    }
    {
      name = "assets.wikimusic.jointhefreeworld.org";
      value = "assets.wikimusic.jointhefreeworld.org";
      zone = "jointhefreeworld.org";
      type = "A";
    }
    {
      name = "wikimusic.jointhefreeworld.org";
      value = "wikimusic.jointhefreeworld.org";
      zone = "jointhefreeworld.org";
      type = "A";
    }
    {
      name = "www.wikimusic.jointhefreeworld.org";
      value = "wikimusic.jointhefreeworld.org";
      zone = "jointhefreeworld.org";
      type = "A";
    }
    {
      name = "api.wikimusic.jointhefreeworld.org";
      zone = "jointhefreeworld.org";
      value = "api.wikimusic.jointhefreeworld.org";
      type = "A";
    }
    {
      name = "casadelcata.es";
      zone = "casadelcata.es";
      value = "casadelcata.es";
      type = "A";
    }
    {
      name = "www.casadelcata.es";
      zone = "casadelcata.es";
      value = "casadelcata.es";
      type = "A";
    }
    {
      name = "carvoeirowaterfun.com";
      zone = "carvoeirowaterfun.com";
      value = "carvoeirowaterfun.com";
      type = "A";
    }
    {
      name = "www.carvoeirowaterfun.com";
      zone = "carvoeirowaterfun.com";
      value = "carvoeirowaterfun.com";
      type = "A";
    }
    {
      name = "grafana.jointhefreeworld.org";
      zone = "jointhefreeworld.org";
      value = "grafana.jointhefreeworld.org";
      type = "A";
    }
    {
      name = "prometheus.jointhefreeworld.org";
      zone = "jointhefreeworld.org";
      value = "prometheus.jointhefreeworld.org";
      type = "A";
    }
  ];

  bucketDistributions = [
    {
      bucket = "carvoeirowaterfun.com";
      description = "Carvoeiro Water Fun Website S3";
      env = prod;
      aliases = [ "carvoeirowaterfun.com" "www.carvoeirowaterfun.com" ];
      certificateArn = lib.tfRef
        "aws_acm_certificate.${tf.tfName "carvoeirowaterfun.com"}.arn";
    }
    {
      bucket = "jointhefreeworld.org";
      description = "Join the Free World Website S3";
      env = prod;
      aliases = [ "jointhefreeworld.org" "www.jointhefreeworld.org" ];
      certificateArn =
        lib.tfRef "aws_acm_certificate.${tf.tfName "jointhefreeworld.org"}.arn";
    }
    {
      bucket = "casadelcata.es";
      description = "Casa del Cata Website S3";
      env = prod;
      aliases = [ "casadelcata.es" "www.casadelcata.es" ];
      certificateArn =
        lib.tfRef "aws_acm_certificate.${tf.tfName "casadelcata.es"}.arn";
    }
    {
      bucket = "assets.wikimusic.jointhefreeworld.org";
      description = "WikiMusic Assets S3";
      env = prod;
      aliases = [ "assets.wikimusic.jointhefreeworld.org" ];
      certificateArn = lib.tfRef "aws_acm_certificate.${
          tf.tfName "assets.wikimusic.jointhefreeworld.org"
        }.arn";
      minTTL = 30000000;
      defaultTTL = 30000000;
      maxTTL = 60000000;
      hasCors = true;
      corsOrigins = [
        "wikimusic.jointhefreeworld.org"
        "jointhefreeworld.org"
        "127.0.0.1"
        "10.0.2.2"
        "127.0.0.1:6923"
      ];
      customHeaders = [{
        header = "cache-control";
        override = true;
        value = "public, max-age=${builtins.toString 30000000}";
      }];
    }
  ];

  instanceDistributions = [
    {
      cf = "api.wikimusic.jointhefreeworld.org";
      instance = "jjba-${v}";
      description = "API WikiMusic";
      env = prod;
      aliases = [ "api.wikimusic.jointhefreeworld.org" ];
      certificateArn = lib.tfRef "aws_acm_certificate.${
          tf.tfName "api.wikimusic.jointhefreeworld.org"
        }.arn";
      httpPort = 50050;
      httpsPort = 50050;
    }
    {
      cf = "wikimusic.jointhefreeworld.org";
      instance = "jjba-${v}";
      description = "SSR WikiMusic";
      env = prod;
      aliases = [
        "wikimusic.jointhefreeworld.org"
        "www.wikimusic.jointhefreeworld.org"
      ];
      certificateArn = lib.tfRef
        "aws_acm_certificate.${tf.tfName "wikimusic.jointhefreeworld.org"}.arn";
      httpPort = 6923;
      httpsPort = 6923;
    }
    {
      cf = "grafana.jointhefreeworld.org";
      instance = "jjba-${v}";
      description = "Grafana Jointhefreeworld";
      env = prod;
      aliases = [ "grafana.jointhefreeworld.org" ];
      certificateArn = lib.tfRef
        "aws_acm_certificate.${tf.tfName "grafana.jointhefreeworld.org"}.arn";
      httpPort = 7979;
      httpsPort = 7979;
    }
    {
      cf = "prometheus.jointhefreeworld.org";
      instance = "jjba-${v}";
      description = "Prometheus Jointhefreeworld";
      env = prod;
      aliases = [ "prometheus.jointhefreeworld.org" ];
      certificateArn = lib.tfRef "aws_acm_certificate.${
          tf.tfName "prometheus.jointhefreeworld.org"
        }.arn";
      httpPort = 7979;
      httpsPort = 7979;
    }
  ];

  fifoQueues = [
    {
      name = "wikimusic-version-release";
      env = prod;
    }
    {
      name = "dotfiles-ec2-version-release";
      env = prod;
    }
    {
      name = "asset-manager-version-release";
      env = prod;
    }
    {
      name = "wikimusic-frontend-version-release";
      env = prod;
    }
  ];

  groups = [
    {
      name = "queue-admins";
      path = "/automation/";
      policyName = "queue-admins";
      policyStatements = [{
        Effect = "Allow";
        Action = [ "sqs:*" ];
        Resource = "*";
      }];
    }
    {
      name = "mail-senders";
      path = "/automation/";
      policyName = "mail-senders";
      policyStatements = [{
        Effect = "Allow";
        Action = [ "ses:*" ];
        Resource = "*";
      }];
    }
  ];

  users = [
    {
      name = "queue-master";
      path = "/automation/";
      groups = [ "queue-admins" ];
      tags = { };
    }
    {
      name = "mail-sender";
      path = "/automation/";
      groups = [ "mail-senders" ];
      tags = { };
    }
  ];

  resources = [
    (map cloudfront.mkBucketDistribution bucketDistributions)
    (map acm.mkCertificate certificates)
    (map s3.mkBucket buckets)
    (map route53.mkZone zones)
    (map route53.mkRecordAliasCloudfront cloudfrontRecords)
    (map route53.mkRecord records)
    (map ec2.mkInstance instances)
    (map cloudfront.mkInstanceDistribution instanceDistributions)
    (map sqs.mkFifoQueue fifoQueues)
    (map iam.mkUserGroup groups)
    (map iam.mkUser users)
  ];

in {
  provider.aws = [
    { inherit region; }
    {
      alias = "us";
      region = alternativeRegion;
    }
  ];

  resource = lib.mkMerge (lib.lists.flatten resources);
  data = lib.mkMerge [ ec2.nixOSAMIData ];
}
