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

fmt:
	-find . -name '*.nix' -exec nixfmt {} \;
	-statix check
	-deadnix
run: fmt
	@make pull-state
	AWS_PROFILE="master-infra" nix --experimental-features 'nix-command flakes' run ".#"
	@make save-state
apply: fmt
	@make pull-state
	AWS_PROFILE="master-infra" nix --experimental-features 'nix-command flakes' run ".#apply"
	@make save-state
destroy: fmt
	@make pull-state
	AWS_PROFILE="master-infra" nix --experimental-features 'nix-command flakes' run ".#destroy"
	@make save-state
plan: fmt
	@make pull-state
	AWS_PROFILE="master-infra" nix --experimental-features 'nix-command flakes' run ".#plan"
pull-state:
	AWS_PROFILE="master-infra" aws s3 cp s3://cloud-infra-state-jjba/cloud-infra/.terraform.lock.hcl ./
	AWS_PROFILE="master-infra" aws s3 cp s3://cloud-infra-state-jjba/cloud-infra/terraform.tfstate ./
	AWS_PROFILE="master-infra" aws s3 cp s3://cloud-infra-state-jjba/cloud-infra/terraform.tfstate.backup ./
	AWS_PROFILE="master-infra" aws s3 cp s3://cloud-infra-state-jjba/cloud-infra/terraform.tfstate.backup ./
save-state:
	AWS_PROFILE="master-infra" aws s3 cp .terraform.lock.hcl s3://cloud-infra-state-jjba/cloud-infra/
	AWS_PROFILE="master-infra" aws s3 cp terraform.tfstate s3://cloud-infra-state-jjba/cloud-infra/
	AWS_PROFILE="master-infra" aws s3 cp terraform.tfstate.backup s3://cloud-infra-state-jjba/cloud-infra/
	AWS_PROFILE="master-infra" aws s3 cp config.tf.json s3://cloud-infra-state-jjba/cloud-infra/
