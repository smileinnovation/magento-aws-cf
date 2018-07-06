#!/usr/bin/env bash
export CURRENT_UID="$(id -u):0"
docker-compose -f ./docker-compose-dev.yml up
