import base64
import os
import sys
import time
from pathlib import Path

import jwt
import requests

KEY_ID = os.environ.get("ASC_KEY_ID", "WDXGY9WX55")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "2be0734f-943a-4d61-9dc9-5d9045c46fec")
KEY_PATH = Path.home() / ".appstoreconnect" / "private_keys" / f"AuthKey_{KEY_ID}.p8"
BUNDLE_ID = "com.tokyonasu.keirinpredictor"
PROFILE_NAME = "KeirinPredictor App Store CI"
BASE_URL = "https://api.appstoreconnect.apple.com/v1"


def token():
    now = int(time.time())
    key = KEY_PATH.read_text()
    return jwt.encode(
        {"iss": ISSUER_ID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        key,
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


def first(path, label):
    payload = api("GET", path)
    items = payload.get("data") or []
    if not items:
        raise RuntimeError(f"{label} not found")
    return items[0]


def profile_content(profile_id):
    payload = api("GET", f"/profiles/{profile_id}")
    content = (payload.get("data") or {}).get("attributes", {}).get("profileContent")
    if not content:
        raise RuntimeError(f"profileContent missing for profile {profile_id}")
    return content


def main():
    out_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("KeirinPredictor.mobileprovision")
    bundle = first(f"/bundleIds?filter[identifier]={BUNDLE_ID}", "bundle id")
    bundle_id = bundle["id"]

    profiles = api(
        "GET",
        f"/profiles?filter[profileType]=IOS_APP_STORE&filter[name]={PROFILE_NAME}&limit=10",
    ).get("data") or []
    for profile in profiles:
        if profile["attributes"].get("name") == PROFILE_NAME:
            out_path.write_bytes(base64.b64decode(profile_content(profile["id"])))
            print(PROFILE_NAME)
            return

    cert = first("/certificates?filter[certificateType]=IOS_DISTRIBUTION&limit=10", "iOS distribution certificate")
    payload = api(
        "POST",
        "/profiles",
        json={
            "data": {
                "type": "profiles",
                "attributes": {"name": PROFILE_NAME, "profileType": "IOS_APP_STORE"},
                "relationships": {
                    "bundleId": {"data": {"type": "bundleIds", "id": bundle_id}},
                    "certificates": {"data": [{"type": "certificates", "id": cert["id"]}]},
                },
            }
        },
    )
    profile_id = payload["data"]["id"]
    content = payload["data"].get("attributes", {}).get("profileContent") or profile_content(profile_id)
    out_path.write_bytes(base64.b64decode(content))
    print(PROFILE_NAME)


if __name__ == "__main__":
    main()
