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
  mkFifoQueue = { name, env }: {
    aws_sqs_queue."${tf.tfName name}" = {
      name = "${name}.fifo";
      delay_seconds = 3;
      max_message_size = 262144;
      message_retention_seconds = 345600;
      receive_wait_time_seconds = 0;
      fifo_queue = true;
      content_based_deduplication = true;
      tags = { Environment = env; };
    };
  };
}
