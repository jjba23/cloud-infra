#!/usr/bin/env bash

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

MY_HOME="/home/joe"


echo "Starting bootstrap of EC2 instance"

echo "Updating Nix channels"
nix-channel --remove nixos || true
nix-channel --remove nixpkgs || true
nix-channel --add https://nixos.org/channels/nixpkgs-unstable || true
nix-channel --update || true
nix-channel --update || true 
nix-channel --update || true

echo "Increasing tmpfs size to 20GB temporarily"
nix-shell -p mount --run "mount -o remount,size=20G tmpfs"

echo "Preparing folders"
mkdir -p $MY_HOME/Ontwikkeling
mkdir -p $MY_HOME/.config/sops/age

echo "Fetching age key for sops nix process"
rm -f $MY_HOME/.config/sops/age/keys.txt
nix-shell -p awscli2 git jq \
	  --run "aws secretsmanager get-secret-value --secret-id prod/age_key | jq -r '.SecretString' >> $MY_HOME/.config/sops/age/keys.txt"

echo "Preparing dotfiles"
rm -rf $MY_HOME/Ontwikkeling/dotfiles-ec2
nix-shell -p git gnumake \
	  --run "git clone https://github.com/jjba23/dotfiles-ec2 $MY_HOME/Ontwikkeling/dotfiles-ec2"

echo "Installing EC2 dotfiles"
cd $MY_HOME/Ontwikkeling/dotfiles-ec2 || exit
nix-shell -p git gnumake direnv awscli2 \
	  --run "direnv allow && direnv reload && make nr"   

echo "Cloning Wikimusic repo"
rm -rf $MY_HOME/Ontwikkeling/wikimusic-api
nix-shell -p git gnumake \
	  --run "git clone https://github.com/jjba23/wikimusic-api $MY_HOME/Ontwikkeling/wikimusic-api"

echo "Cloning Wikimusic frontend repo"
rm -rf $MY_HOME/Ontwikkeling/wikimusic-ssr
nix-shell -p git gnumake \
	  --run "git clone https://github.com/jjba23/wikimusic-ssr $MY_HOME/Ontwikkeling/wikimusic-ssr"

echo "Fetching latest backup file for WikiMusic"

WIKIMUSIC_DB_BACKUP_FILE=$(nix-shell -p awscli2 git jq --run "aws s3 ls s3://cloud-infra-state-jjba/wikimusic/backups/sqlite/ | grep wikimusic-sqlite | sort | tail -n 1 | awk '{print \$4}'")

nix-shell -p awscli2 git jq \
	  --run "aws s3 cp s3://cloud-infra-state-jjba/wikimusic/backups/sqlite/$WIKIMUSIC_DB_BACKUP_FILE $MY_HOME/$WIKIMUSIC_DB_BACKUP_FILE"


echo "Restoring WikiMusic from latest database backup"
nix-shell -p unzip \
	  --run "cd $MY_HOME && unzip $MY_HOME/$WIKIMUSIC_DB_BACKUP_FILE"

chown -R joe $MY_HOME || true

echo "Restarting WikiMusic API"
systemctl restart wikimusic-api

echo "Restarting WikiMusic Frontend"
systemctl restart wikimusic-ssr


