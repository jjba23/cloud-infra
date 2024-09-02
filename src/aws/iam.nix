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
  addUserToGroup = { name, groups }: {
    "${tf.tfName name}-groups" = {
      user = lib.tfRef "aws_iam_user.${tf.tfName name}.name";
      groups = map (x: lib.tfRef "aws_iam_group.${tf.tfName x}.name") groups;
    };
  };
  mkRolePolicy = { name, rolePolicy }: {
    inherit name;
    role = lib.tfRef "aws_iam_role.${tf.tfName name}.id";
    policy = builtins.toJSON rolePolicy;
  };
in {
  mkUserGroup = { name, path, policyName, policyStatements ? [ ] }: {
    aws_iam_group."${name}" = { inherit name path; };
    aws_iam_group_policy."${tf.tfName policyName}" = {
      name = tf.tfName policyName;
      group = lib.tfRef "aws_iam_group.${tf.tfName policyName}.name";
      policy = builtins.toJSON {
        Version = "2012-10-17";
        Statement = policyStatements;
      };
    };
  };
  mkAccessKey = { name, user }: {
    aws_iam_access_key."${tf.tfName name}" = {
      user = lib.tfRef "aws_iam_user.${tf.tfName user}.name";
    };
  };

  mkUser = { name, tags ? { }, path, groups }: {
    aws_iam_user."${name}" = { inherit name tags path; };

    aws_iam_access_key."${name}" = {
      user = lib.tfRef "aws_iam_user.${name}.name";
    };
    aws_iam_user_group_membership = addUserToGroup { inherit name groups; };
  };
  mkInstanceRole = { name, policy, rolePolicy, tags }: {
    aws_iam_role."${tf.tfName name}" = {
      inherit name tags;
      assume_role_policy = builtins.toJSON policy;
    };
    aws_iam_role_policy."${tf.tfName name}" =
      mkRolePolicy { inherit name rolePolicy; };

    aws_iam_instance_profile."${tf.tfName name}" = {
      name = "${tf.tfName name}";
      role = lib.tfRef "aws_iam_role.${tf.tfName name}.name";
    };
  };
}
