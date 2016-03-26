#!/usr/bin/env bash

RESPONDER_COUNT="${RESPONDER_COUNT}"
#URL="http://dsa-benchmarks.herokuapp.com/conn"
#URL="http://titan.directcode.org:8094/conn"
URL="http://benchmark.iot-dsa.org:8100/conn"

if [ -z ${RESPONDER_COUNT} ]
then
 RESPONDER_COUNT="2"
fi

export PATH=${PATH}:${PWD}/dart-sdk/bin

sleep 2

cleanup() {
  echo "Cleaning up..."
  local pids=$(jobs -pr)
  [ -n "$pids" ] && kill -KILL $pids
  exit 0
}
trap "cleanup" INT QUIT TERM EXIT

RESPONDER_PID=""
for i in $(seq 1 ${RESPONDER_COUNT})
do
  DID="$((${DYNO##*.} - 1))"
  X="$((${i} + (${DID} * ${RESPONDER_COUNT})))"
  NAME="Benchmark-${X}"
  dart bin/responder.dart --broker ${URL} ${RESPONDER_CONFIG} --name="${NAME}" &
  RESPONDER_PID="$RESPONDER_PID $!"
done

waitall() { # PID...
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
    sleep ${WAITALL_DELAY:-1}
   done
  ((errors == 0))
}

waitall ${RESPONDER_PID}
