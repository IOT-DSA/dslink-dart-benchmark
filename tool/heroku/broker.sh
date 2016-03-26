#!/usr/bin/env bash
export PATH=${PATH}:${PWD}/dart-sdk/bin
export BROKER_PORT=${PORT}

rm -rf conns.json broker.json tmp

wget https://ci.dev.dglogik.com/repository/download/Dsa_CBroker/.lastSuccessful/linux_x64_broker --http-user guest --http-passwd guest -O broker
chmod +x broker

cat <<EOF > broker.json
{
  "http": {
    "enabled": true,
    "host": "0.0.0.0",
    "port": ${BROKER_PORT}
  },
  "log_level": "info"
}
EOF

./broker
