#!/usr/bin/env bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

set -e
set -x

# shellcheck disable=SC1090
source ~/.common.sh

eval "$(ssh-agent -s)"
mkdir -p .ssh
retry ssh-keyscan github.com >> .ssh/known_hosts

# Get AWS credentials for GCE to be able to read from Credstash
if [[ "$EC2SPOTMANAGER_PROVIDER" = "GCE" ]]; then
  mkdir -p .aws
  retry berglas access fuzzmanager-cluster-secrets/credstash-aws-auth > .aws/credentials
  chmod 0600 .aws/credentials
elif [[ "$TASKCLUSTER_PROXY_URL" != "" ]]; then
  mkdir -p .aws
  curl -L "$TASKCLUSTER_PROXY_URL/secrets/v1/secret/project/fuzzing/credstash-aws-auth" | python -c 'import json, sys; a = json.load(sys.stdin); open(".aws/credentials", "w").write(a["secret"]["key"])' &&
  chmod 0600 .aws/credentials
fi

# Get deployment keys from credstash
retry credstash get deploy-grizzly-config.pem > .ssh/id_ecdsa.grizzly_config
chmod 0600 .ssh/id_ecdsa.grizzly_config

# Setup Additional Key Identities
cat << EOF >> .ssh/config

Host grizzly-config
HostName github.com
IdentitiesOnly yes
IdentityFile ~/.ssh/id_ecdsa.grizzly_config
EOF

# Checkout fuzzer including framework, install everything
retry git clone -v --depth 1 --no-tags git@grizzly-config:MozillaSecurity/grizzly-config.git config
if [[ "$BEARSPRAY" = "1" ]]; then
  ./config/aws/setup-bearspray.sh
else
  ./config/aws/setup-grizzly.sh
fi
