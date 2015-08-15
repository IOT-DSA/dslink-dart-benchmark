#!/usr/bin/env bash
export PATH=${PATH}:${PWD}/dart-sdk/bin
export BROKER_PORT=${PORT}

rm -rf conns.json broker.json tmp

dart .pub/bin/dslink/broker.dart.snapshot --docker
