#!/usr/bin/env bash

export PATH=${PATH}:${PWD}/dart-sdk/bin

REQUESTER_COUNT="${REQUESTER_COUNT}"

if [ -z ${REQUESTER_COUNT} ]
then
 REQUESTER_COUNT="2"
fi

cleanup() {
  echo "Cleaning up..."
  local pids=$(jobs -pr)
  [ -n "$pids" ] && kill -KILL $pids
  exit 0
}
trap "cleanup" INT QUIT TERM EXIT

rm -rf conns.json broker.json

export BROKER_PORT=${PORT}
dart .pub/bin/dslink/broker.dart.snapshot --docker &
BROKER_PID=$!
sleep 2
dart bin/responder.dart --broker http://127.0.0.1:${PORT}/conn &
RESPONDER_PID=$!
sleep 2
REQUESTER_PID=""
for i in $(seq 1 ${REQUESTER_COUNT})
do
  dart bin/requester.dart --broker http://127.0.0.1:${PORT}/conn --path /conns/Benchmark --silent --id "Requester ${i}" --name="Benchmarker-${i}" &
  REQUESTER_PID="$REQUESTER_PID $!"
done

waitall() { # PID...
  ## Wait for children to exit and indicate whether all exited with 0 status.
  local errors=0
  while :; do
    for pid in "$@"; do
      shift
      if kill -0 "$pid" 2>/dev/null; then
        set -- "$@" "$pid"
      elif wait "$pid"; then
        echo "$pid exited with zero exit status."
      else
        echo "$pid exited with non-zero exit status."
        ((++errors))
      fi
    done
    (("$#" > 0)) || break
    # TODO: how to interrupt this sleep when a child terminates?
    sleep ${WAITALL_DELAY:-1}
   done
  ((errors == 0))
}

waitall ${BROKER_PID} ${RESPONDER_PID} ${REQUESTER_PID}
