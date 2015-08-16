#!/usr/bin/env bash

REQUESTER_COUNT="${REQUESTER_COUNT}"

if [ -z ${REQUESTER_COUNT} ]
then
 REQUESTER_COUNT="2"
fi

export PATH=${PATH}:${PWD}/dart-sdk/bin

sleep 10

cleanup() {
  echo "Cleaning up..."
  local pids=$(jobs -pr)
  [ -n "$pids" ] && kill -KILL $pids
  exit 0
}
trap "cleanup" INT QUIT TERM EXIT

REQUESTER_PID=""
for i in $(seq 1 ${REQUESTER_COUNT})
do
  X="$((${DYNO##*.} * ${i}))"

  if $((${X} > 1))
  then
    X=$((${X} + 1))
  fi

  BNAME="Benchmark-${X}"
  NAME="Benchmarker-${X}"
  echo "My Name is ${NAME} and I subscribe to ${BNAME}"
  dart bin/requester.dart --broker https://dsa-benchmarks.herokuapp.com/conn --path "/conns/${BNAME}" --silent --id "Requester ${X}" --name="${NAME}" &
  REQUESTER_PID="$REQUESTER_PID $!"
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

waitall ${REQUESTER_PID}
