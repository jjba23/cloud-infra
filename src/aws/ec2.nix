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
  iam = import ./iam.nix { inherit lib; };

  mkIngressRule = { port, groupName
    , cidr ? (lib.tfRef "aws_vpc.${tf.tfName groupName}.cidr_block") }: {
      "${tf.tfName groupName}-${port}" = {
        security_group_id =
          lib.tfRef "aws_security_group.${tf.tfName groupName}.id";
        cidr_ipv4 = cidr;
        from_port = port;
        to_port = port;
        ip_protocol = "tcp";
      };
    };
  roleGen = { name, canManageSecrets, canManageBuckets, canManageQueues }: {
    inherit name;
    policy = {
      Version = "2012-10-17";
      Statement = [{
        Action = "sts:AssumeRole";
        Principal = { Service = "ec2.amazonaws.com"; };
        Effect = "Allow";
        Sid = "";
      }];
    };
    rolePolicy = {
      Version = "2012-10-17";
      Statement = lib.lists.flatten [
        (lib.lists.optional canManageSecrets {
          Action = [ "secretsmanager:*" ];
          Effect = "Allow";
          Resource = "*";
        })
        (lib.lists.optional canManageBuckets {
          Action = [ "s3:*" ];
          Effect = "Allow";
          Resource = "*";
        })
        (lib.lists.optional canManageQueues {
          Action = [ "sqs:*" ];
          Effect = "Allow";
          Resource = "*";
        })
      ];
    };
    tags = { };
  };
in {
  mkInstance = { env, name, instanceType ? "m7g.medium", publicKey
    , publicKeyName, availabilityZone, userData, ingressRules ? [ ]
    , canManageBuckets ? false, canManageSecrets ? false
    , canManageQueues ? false }:
    {
      aws_instance."${tf.tfName name}" = {
        instance_type = instanceType;
        availability_zone = availabilityZone;
        ami = lib.tfRef "data.aws_ami.nixos_arm64.id";
        tags = { Name = name; };
        user_data = userData;
        associate_public_ip_address = true;
        monitoring = true;
        subnet_id = lib.tfRef "aws_subnet.${tf.tfName name}.id";
        vpc_security_group_ids =
          [ (lib.tfRef "aws_security_group.${tf.tfName name}.id") ];
        root_block_device = {
          volume_size = 50; # in GB
          volume_type = "gp3";
        };
        iam_instance_profile =
          lib.tfRef "aws_iam_instance_profile.${tf.tfName name}.id";
        key_name = lib.tfRef
          "aws_key_pair.${tf.tfName name}-${tf.tfName publicKeyName}.key_name";
      };
      aws_internet_gateway."${tf.tfName name}" = {
        vpc_id = lib.tfRef "aws_vpc.${tf.tfName name}.id";
      };
      aws_vpc."${tf.tfName name}" = {
        cidr_block = "10.0.0.0/16";
        enable_dns_hostnames = true;
        enable_dns_support = true;
      };
      aws_subnet."${tf.tfName name}" = {
        vpc_id = lib.tfRef "aws_vpc.${tf.tfName name}.id";
        availability_zone = availabilityZone;
        cidr_block =
          lib.tfRef "cidrsubnet(aws_vpc.${tf.tfName name}.cidr_block, 3, 1)";

        tags = {
          Name = name;
          Env = env;
        };
      };
      aws_key_pair."${tf.tfName name}-${tf.tfName publicKeyName}" = {
        key_name = "${tf.tfName name}-${tf.tfName publicKeyName}";
        public_key = publicKey;
      };
      aws_ec2_instance_state."${tf.tfName name}" = {
        instance_id = lib.tfRef "aws_instance.${tf.tfName name}.id";
        state = "running";
      };

      aws_eip."${tf.tfName name}" = {
        instance = lib.tfRef "aws_instance.${tf.tfName name}.id";
        domain = "vpc";
      };

      aws_route_table."${tf.tfName name}" = {
        vpc_id = lib.tfRef "aws_vpc.${tf.tfName name}.id";
      };

      aws_route."${tf.tfName name}-in" = {
        destination_cidr_block = "0.0.0.0/0";
        gateway_id = lib.tfRef "aws_internet_gateway.${tf.tfName name}.id";
        route_table_id = lib.tfRef "aws_route_table.${tf.tfName name}.id";
      };

      aws_route_table_association."${tf.tfName name}-subnet_association" = {
        subnet_id = lib.tfRef "aws_subnet.${tf.tfName name}.id";
        route_table_id = lib.tfRef "aws_route_table.${tf.tfName name}.id";
      };

      aws_security_group."${tf.tfName name}" = {
        inherit name;
        description = "${name} security group";
        vpc_id = lib.tfRef "aws_vpc.${tf.tfName name}.id";

      };

      aws_vpc_security_group_egress_rule."${tf.tfName name}" = {
        security_group_id = lib.tfRef "aws_security_group.${tf.tfName name}.id";
        cidr_ipv4 = "0.0.0.0/0";
        from_port = -1;
        to_port = -1;
        ip_protocol = "-1";
      };

      aws_ec2_serial_console_access."${tf.tfName name}" = { enabled = true; };

      aws_vpc_security_group_ingress_rule =
        lib.mkMerge (map mkIngressRule ingressRules);

    } // (iam.mkInstanceRole (roleGen {
      inherit name canManageBuckets canManageSecrets canManageQueues;
    }));
  nixOSAMIData = {
    aws_ami.nixos_amd64 = {
      owners = [ "427812963091" ];
      most_recent = true;

      filter = [
        {
          name = "name";
          values = [ "nixos/23.11*" ];
        }
        {
          name = "architecture";
          values = [ "x86_64" ];
        }
      ];
    };
    aws_ami.nixos_arm64 = {
      owners = [ "427812963091" ];
      most_recent = true;

      filter = [
        {
          name = "name";
          values = [ "nixos/23.11*" ];
        }
        {
          name = "architecture";
          values = [ "arm64" ];
        }
      ];
    };
  };
}
