#!/usr/bin/env bash

export RESPONDER_COUNT=${REQUESTER_COUNT}
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
  NAME="Benchmark-$((${DYNO##*.} * ${i}))"
  echo "My Name is ${NAME}"
  dart bin/responder.dart --broker https://dsa-benchmarks.herokuapp.com/conn ${RESPONDER_CONFIG} --name="${NAME}" &
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
