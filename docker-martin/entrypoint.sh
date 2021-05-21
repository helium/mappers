#!/bin/sh

set -e

config='/app/config/docker/config.yaml'
sed -i '/^connection_string:.*/d' $config
sed -i '/^listen_addresses:.*/d' $config
echo connection_string: $DATABASE_URL >> $config
echo listen_addresses: "0.0.0.0:$PORT" >> $config

martin --config /app/config/docker/config.yaml