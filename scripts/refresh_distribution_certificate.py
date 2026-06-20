import base64
import secrets
import subprocess
import sys
import time
from pathlib import Path

import jwt
import requests
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.x509.oid import NameOID

KEY_ID = "WDXGY9WX55"
ISSUER_ID = "2be0734f-943a-4d61-9dc9-5d9045c46fec"
KEY_PATH = Path.home() / ".appstoreconnect" / "private_keys" / f"AuthKey_{KEY_ID}.p8"
BASE_URL = "https://api.appstoreconnect.apple.com/v1"
REPO = "snarfnet/KeirinPredictor"


def token():
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER_ID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        KEY_PATH.read_text(),
        algorithm="ES256",
        headers={"kid": KEY_ID},
    )


def api(method, path, **kwargs):
    response = requests.request(
        method,
        f"{BASE_URL}{path}",
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"},
        **kwargs,
    )
    if not response.ok:
        raise RuntimeError(f"{method} {path} failed: {response.status_code} {response.text}")
    return response.json() if response.text else {}


def gh_secret(name, value):
    subprocess.run(
        ["gh", "secret", "set", name, "--repo", REPO],
        input=value,
        text=True,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def main():
    if not KEY_PATH.exists():
        raise RuntimeError(f"ASC API key missing: {KEY_PATH}")

    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    csr = (
        x509.CertificateSigningRequestBuilder()
        .subject_name(
            x509.Name(
                [
                    x509.NameAttribute(NameOID.COMMON_NAME, "KeirinPredictor CI Distribution"),
                    x509.NameAttribute(NameOID.ORGANIZATION_NAME, "satoshi amasaki"),
                    x509.NameAttribute(NameOID.COUNTRY_NAME, "JP"),
                ]
            )
        )
        .sign(private_key, hashes.SHA256())
    )
    csr_pem = csr.public_bytes(serialization.Encoding.PEM).decode("utf-8")

    payload = api(
        "POST",
        "/certificates",
        json={
            "data": {
                "type": "certificates",
                "attributes": {
                    "certificateType": "IOS_DISTRIBUTION",
                    "csrContent": csr_pem,
                },
            }
        },
    )

    attrs = payload["data"]["attributes"]
    cert_der = base64.b64decode("".join(attrs["certificateContent"].split()), validate=True)
    cert = x509.load_der_x509_certificate(cert_der)
    password = secrets.token_urlsafe(24)
    p12 = pkcs12.serialize_key_and_certificates(
        name=b"Apple Distribution",
        key=private_key,
        cert=cert,
        cas=None,
        encryption_algorithm=serialization.BestAvailableEncryption(password.encode("utf-8")),
    )

    gh_secret("DIST_CERT_BASE64", base64.b64encode(p12).decode("ascii"))
    gh_secret("DIST_CERT_PASSWORD", password)

    serial = attrs.get("serialNumber", cert.serial_number)
    expires = attrs.get("expirationDate", "unknown")
    print(f"Created and installed distribution certificate serial={serial} expires={expires}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
