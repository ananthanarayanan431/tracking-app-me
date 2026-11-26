#!/bin/bash
# Creates a self-signed "Spent Local Signing" code-signing certificate in the login keychain.
# It never leaves this Mac; remove it any time in Keychain Access.
set -euo pipefail
if security find-identity 2>/dev/null | grep -q '"Spent Local Signing"'; then echo "Already exists"; exit 0; fi
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cat > "$T/cert.cnf" <<'CNF'
[req]
distinguished_name=dn
x509_extensions=ext
prompt=no
[dn]
CN=Spent Local Signing
[ext]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
CNF
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$T/key.pem" -out "$T/cert.pem" -days 3650 -config "$T/cert.cnf" 2>/dev/null
P=$(openssl rand -hex 12)
openssl pkcs12 -export -legacy -inkey "$T/key.pem" -in "$T/cert.pem" -name "Spent Local Signing" -out "$T/spent.p12" -passout "pass:$P"
security import "$T/spent.p12" -k ~/Library/Keychains/login.keychain-db -P "$P" -T /usr/bin/codesign
echo "Created Spent Local Signing"
