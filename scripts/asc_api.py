import os
import time
from pathlib import Path

import jwt
import requests

KEY_ID = os.environ.get("ASC_KEY_ID", "WDXGY9WX55")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "2be0734f-943a-4d61-9dc9-5d9045c46fec")
KEY_PATH = Path.home() / ".appstoreconnect" / "private_keys" / f"AuthKey_{KEY_ID}.p8"
BUNDLE_ID = "com.tokyonasu.keirinpredictor"
BASE_URL = "https://api.appstoreconnect.apple.com/v1"
_TOKEN = None
_TOKEN_EXPIRES_AT = 0


def make_token():
    global _TOKEN, _TOKEN_EXPIRES_AT
    now = int(time.time())
    if _TOKEN and now < _TOKEN_EXPIRES_AT - 60:
        return _TOKEN
    key = KEY_PATH.read_text()
    _TOKEN_EXPIRES_AT = now + 900
    _TOKEN = jwt.encode(
        {"iss": ISSUER_ID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        key, algorithm="ES256", headers={"kid": KEY_ID},
    )
    return _TOKEN


def headers():
    return {"Authorization": f"Bearer {make_token()}", "Content-Type": "application/json"}


def api(method, path, **kwargs):
    response = requests.request(method, f"{BASE_URL}{path}", headers=headers(), **kwargs)
    if not response.ok:
        raise RuntimeError(f"{method} {path} failed: {response.status_code} {response.text}")
    return response.json() if response.text else {}


def find_app_id():
    payload = api("GET", f"/apps?filter[bundleId]={BUNDLE_ID}")
    items = payload.get("data", [])
    if not items:
        raise RuntimeError(f"App not found for bundle id: {BUNDLE_ID}")
    return items[0]["id"]


def get_or_create_version(app_id, version_string):
    # First try: search all versions (no state filter) for exact match
    payload = api("GET", f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=10")
    for item in payload.get("data", []):
        if item["attributes"].get("versionString") == version_string:
            print(f"Found existing version {version_string} (state: {item['attributes'].get('appStoreState')})")
            return item["id"]
    # Second try: find editable version to update
    editable_states = "PREPARE_FOR_SUBMISSION,DEVELOPER_REJECTED,REJECTED,METADATA_REJECTED"
    payload = api("GET", f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&filter[appStoreState]={editable_states}&limit=10")
    for item in payload.get("data", []):
        old_version = item["attributes"].get("versionString", "")
        print(f"Found editable version {old_version}, updating to {version_string}")
        api("PATCH", f"/appStoreVersions/{item['id']}", json={
            "data": {"type": "appStoreVersions", "id": item["id"],
                     "attributes": {"versionString": version_string}}
        })
        return item["id"]
    payload = api("POST", "/appStoreVersions", json={
        "data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": version_string},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    })
    return payload["data"]["id"]


def get_localization_id(version_id):
    payload = api("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations")
    items = payload.get("data", [])
    if items:
        return items[0]["id"]
    payload = api("POST", "/appStoreVersionLocalizations", json={
        "data": {
            "type": "appStoreVersionLocalizations",
            "attributes": {
                "locale": "ja",
                "description": "競輪レースの予測をRPGバトル風UIで楽しめるアプリ。2400人以上の選手データ・40会場の特性・ライン相性を分析して勝敗を予測。逆張りAIモードで穴狙いも。",
                "keywords": "競輪,予測,レース,選手,バンク,RPG,ライン,逆張り,ギャンブル,keirin",
                "marketingUrl": "https://snarfnet.github.io/",
                "supportUrl": "https://snarfnet.github.io/",
                "whatsNew": "パフォーマンス改善と不具合修正",
            },
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
        }
    })
    return payload["data"]["id"]
