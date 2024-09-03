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

HOME="/root"


echo "Starting bootstrap of EC2 instance"

echo "Updating Nix channels"
nix-channel --update

echo "Increasing tmpfs size to 10GB temporarily"
nix-shell -p mount --run "mount -o remount,size=20G tmpfs"

echo "Preparing folders"
mkdir -p $HOME/Ontwikkeling
mkdir -p $HOME/.config/sops/age

echo "Fetching age key for sops nix process"
rm -f $HOME/.config/sops/age/keys.txt
nix-shell -p awscli2 git jq \
	  --run "aws secretsmanager get-secret-value --secret-id prod/age_key | jq -r '.SecretString' >> $HOME/.config/sops/age/keys.txt"

echo "Preparing dotfiles"
rm -rf $HOME/Ontwikkeling/dotfiles-ec2
nix-shell -p git gnumake \
	  --run "git clone https://github.com/jjba23/dotfiles-ec2 $HOME/Ontwikkeling/dotfiles-ec2"

echo "Installing EC2 dotfiles"
cd $HOME/Ontwikkeling/dotfiles-ec2 || exit
nix-shell -p git gnumake direnv awscli2 \
	  --run "direnv allow && direnv reload && make nr"   

echo "Cloning Wikimusic repo"
rm -rf $HOME/Ontwikkeling/wikimusic-api
nix-shell -p git gnumake \
	  --run "git clone https://github.com/jjba23/wikimusic-api $HOME/Ontwikkeling/wikimusic-api"

echo "Cloning Wikimusic frontend repo"
rm -rf $HOME/Ontwikkeling/wikimusic-ssr
nix-shell -p git gnumake \
	  --run "git clone https://github.com/jjba23/wikimusic-ssr $HOME/Ontwikkeling/wikimusic-ssr"

# echo "Cloning JDB API repo"
# rm -rf $HOME/Ontwikkeling/jdb-api
# nix-shell -p git gnumake \
# 	  --run "git clone https://gitlab.com/projekt-dobos/jdb-api $HOME/Ontwikkeling/jdb-api"

echo "Fetching latest backup file for WikiMusic"
WIKIMUSIC_DB_BACKUP_FILE=$(nix-shell -p awscli2 git jq --run "aws s3 ls s3://cloud-infra-state-jjba/wikimusic/backups/postgresql/ | grep wikimusic_database_ | sort | tail -n 1 | awk '{print \$4}'")
nix-shell -p awscli2 git jq \
	  --run "aws s3 cp s3://cloud-infra-state-jjba/wikimusic/backups/postgresql/$WIKIMUSIC_DB_BACKUP_FILE $HOME/$WIKIMUSIC_DB_BACKUP_FILE"

echo "Creating needed users and roles in PostgreSQL"
DB_KEY=$(cat /run/secrets/wikimusic_postgres_key)
nix-shell -p postgresql \
	  --run "psql -U postgres -p 55432 -c \"CREATE ROLE wikimusic_admin WITH LOGIN PASSWORD '$DB_KEY' CREATEDB; GRANT postgres TO wikimusic_admin; \""
nix-shell -p postgresql \
	  --run "psql -U postgres -p 55432 -c \"CREATE DATABASE wikimusic_database;\""
nix-shell -p postgresql \
	  --run "psql -U postgres -p 55432 -d wikimusic_database -c \"GRANT ALL PRIVILEGES ON DATABASE wikimusic_database TO wikimusic_admin; GRANT USAGE, CREATE ON SCHEMA public TO wikimusic_admin; GRANT ALL ON SCHEMA public TO wikimusic_admin;\" "
nix-shell -p postgresql \
	  --run "psql -U postgres -p 55432 -c \"CREATE ROLE jdbapi_admin WITH LOGIN PASSWORD '$DB_KEY' CREATEDB; GRANT postgres TO jdbapi_admin; \""
nix-shell -p postgresql \
	  --run "psql -U postgres -p 55432 -c \"CREATE DATABASE jdbapi_database;\""
nix-shell -p postgresql \
	  --run "psql -U postgres -p 55432 -d jdbapi_database -c \"GRANT ALL PRIVILEGES ON DATABASE jdbapi_database TO jdbapi_admin; GRANT USAGE, CREATE ON SCHEMA public TO jdbapi_admin; GRANT ALL ON SCHEMA public TO jdbapi_admin;\" "


echo "Restoring WikiMusic from latest database backup"
nix-shell -p postgresql \
	  --run "psql -U wikimusic_admin wikimusic_database -p 55432 < $HOME/$WIKIMUSIC_DB_BACKUP_FILE"

echo "Restarting WikiMusic API"
systemctl restart wikimusic-api

echo "Restarting WikiMusic Frontend"
systemctl restart wikimusic-ssr

