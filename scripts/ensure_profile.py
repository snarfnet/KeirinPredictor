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


def all_items(path):
    items = []
    next_path = path
    while next_path:
        payload = api("GET", next_path)
        items.extend(payload.get("data") or [])
        next_url = payload.get("links", {}).get("next")
        if not next_url:
            break
        next_path = next_url.replace(BASE_URL, "")
    return items


def profile_content(profile_id):
    payload = api("GET", f"/profiles/{profile_id}?fields[profiles]=name,profileContent")
    content = (payload.get("data") or {}).get("attributes", {}).get("profileContent")
    if not content:
        raise RuntimeError(f"profileContent missing for profile {profile_id}")
    return content


def write_profile(out_path, content):
    normalized = "".join(str(content).split())
    data = base64.b64decode(normalized, validate=True)
    if not data:
        raise RuntimeError("downloaded provisioning profile is empty")
    out_path.write_bytes(data)


def main():
    out_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("KeirinPredictor.mobileprovision")
    bundle = first(f"/bundleIds?filter[identifier]={BUNDLE_ID}", "bundle id")
    bundle_id = bundle["id"]

    profiles = all_items("/profiles?filter[profileType]=IOS_APP_STORE&limit=200")
    for profile in profiles:
        if profile["attributes"].get("name") == PROFILE_NAME:
            write_profile(out_path, profile_content(profile["id"]))
            print(PROFILE_NAME)
            return

    for profile in profiles:
        profile_bundle = api("GET", f"/profiles/{profile['id']}/bundleId").get("data") or {}
        if profile_bundle.get("id") == bundle_id:
            profile_name = profile["attributes"].get("name") or PROFILE_NAME
            write_profile(out_path, profile_content(profile["id"]))
            print(profile_name)
            return

    certificates = all_items("/certificates?limit=200")
    cert = None
    for candidate in certificates:
        cert_type = candidate.get("attributes", {}).get("certificateType")
        if cert_type in {"IOS_DISTRIBUTION", "DISTRIBUTION"}:
            cert = candidate
            break
    if not cert:
        seen = ", ".join(sorted({c.get("attributes", {}).get("certificateType", "unknown") for c in certificates}))
        raise RuntimeError(f"iOS distribution certificate not found. Visible certificate types: {seen or 'none'}")

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
    write_profile(out_path, content)
    print(PROFILE_NAME)


if __name__ == "__main__":
    main()
