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

{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, terranix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        tofu = pkgs.opentofu;
        tfConfiguration = terranix.lib.terranixConfiguration {
          inherit system;
          modules = [ ./configuration.nix ];
        };

      in {
        defaultPackage = tfConfiguration;
        # nix develop
        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.opentofu
            pkgs.gnumake
            terranix.defaultPackage.${system}
            pkgs.nixfmt-classic
            pkgs.statix
            pkgs.deadnix
            pkgs.awscli2
          ];
          shellHook = "unset TMPDIR";
        };
        apps = {

          # nix run ".#apply"
          apply = {
            type = "app";
            program = toString (pkgs.writers.writeBash "apply" ''
              if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
              cp ${tfConfiguration} config.tf.json \
                && ${tofu}/bin/tofu init \
                && ${tofu}/bin/tofu apply -auto-approve
            '');
          };
          # nix run ".#destroy"
          destroy = {
            type = "app";
            program = toString (pkgs.writers.writeBash "destroy" ''
              if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
              cp ${tfConfiguration} config.tf.json \
                && ${tofu}/bin/tofu init \
                && ${tofu}/bin/tofu destroy
            '');
          };
          # nix run ".#plan"
          plan = {
            type = "app";
            program = toString (pkgs.writers.writeBash "plan" ''
              if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
              cp ${tfConfiguration} config.tf.json \
                && ${tofu}/bin/tofu init \
                && ${tofu}/bin/tofu plan
            '');
          };
        };
        # nix run
        defaultApp = self.apps.${system}.apply;
      });
}

