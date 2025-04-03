#!/bin/bash
mkdir -p ./pgpool/certs
openssl req -new -x509 -days 3650 -nodes \
  -out server.crt -keyout server.key \
  -subj "/C=US/ST=State/L=City/O=Company/CN=pgpool"

chmod 600 server.key

chmod -R 777 ./pgpool/certs

mkdir -p /opt/bitnami/pgpool/certs

openssl req -new -x509 -days 3650 -nodes \
  -out /opt/bitnami/pgpool/certs/server.crt \
  -keyout /opt/bitnami/pgpool/certs/server.key \
  -subj "/C=US/ST=State/L=City/O=Company/CN=pgpool"

chmod 600 /opt/bitnami/pgpool/certs/server.key
chmod 644 /opt/bitnami/pgpool/certs/server.crt