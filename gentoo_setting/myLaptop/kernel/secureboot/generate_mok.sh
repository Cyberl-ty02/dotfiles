#!/usr/bin/env bash
set -euo pipefail

DIR="/etc/kernel/secureboot"
PEM="${DIR}/MOK.pem"
CER="${DIR}/MOK.cer"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

install -d -m 0700 "$DIR"

if [[ -e "$PEM" ]]; then
  echo "$PEM already exists. Refusing to overwrite." >&2
  exit 1
fi

openssl req -new -nodes -utf8 -sha256 -x509 -days 36500 \
  -subj "/CN=Gentoo laptop Secure Boot module signing key/" \
  -outform PEM \
  -out "$PEM" \
  -keyout "$PEM"

chmod 0600 "$PEM"
chown root:root "$PEM"

openssl x509 -in "$PEM" -outform DER -out "$CER"
chmod 0644 "$CER"
chown root:root "$CER"

openssl x509 -inform DER -in "$CER" -noout -subject -issuer -dates

echo

echo "Generated:"
echo "  private key + cert: $PEM"
echo "  public cert for MOK: $CER"
echo "Next: sudo mokutil --import $CER"
