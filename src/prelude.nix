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
  prodCertificate = { domainName, alternativeNames ? [ ] }: {
    inherit domainName alternativeNames;
    env = "Production";
  };
  prodPublicStaticWebsiteBucket = x: {
    bucket = x;
    description = "${x} static website hosted on S3";
    env = "Production";
    isStaticWebsiteBucket = true;
    isPublicBucket = true;
  };
  prodPublicFileBucket = { bucket, description }: {
    inherit bucket description;
    env = "Production";
    isStaticWebsiteBucket = false;
    isPublicBucket = true;
  };
}
