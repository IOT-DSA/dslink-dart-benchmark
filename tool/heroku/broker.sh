#!/usr/bin/env bash
export BROKER_PORT=${PORT}
pub run dslink:broker --docker
