import os
import time

from asc_api import api, find_app_id, get_or_create_version, get_localization_id

APP_VERSION = os.environ.get("APP_VERSION", "1.0")
BUILD_NUMBER = os.environ.get("BUILD_NUMBER", "")
REVIEW_CONTACT = {
    "contactFirstName": "東京",
    "contactLastName": "なす",
    "contactEmail": "tokyonasu@yahoo.co.jp",
    "contactPhone": "+81 80-2368-9194",
}


def wait_for_build(app_id):
    print(f"Waiting for processed build (expecting build {BUILD_NUMBER or 'any'})...")
    latest_valid_id = None
    for attempt in range(90):
        payload = api("GET", f"/builds?filter[app]={app_id}&sort=-uploadedDate&limit=10")
        for item in payload.get("data", []):
            attrs = item["attributes"]
            version = attrs.get("version", "")
            state = attrs.get("processingState", "")
            print(f"  build {version}: {state}")
            if BUILD_NUMBER and version == str(BUILD_NUMBER) and state == "VALID":
                return item["id"]
            elif not BUILD_NUMBER and version and state == "VALID":
                return item["id"]
            if state == "VALID" and latest_valid_id is None:
                latest_valid_id = item["id"]
        print(f"  attempt {attempt + 1}/90, waiting 30s")
        time.sleep(30)
    if latest_valid_id:
        print("Target build not found, using latest valid build")
        return latest_valid_id
    raise RuntimeError("No valid processed build found")


def main():
    app_id = find_app_id()
    version_id = get_or_create_version(app_id, APP_VERSION)
    build_id = wait_for_build(app_id)

    try:
        api("PATCH", f"/builds/{build_id}", json={
            "data": {"type": "builds", "id": build_id, "attributes": {"usesNonExemptEncryption": False}}
        })
    except RuntimeError as e:
        if "409" in str(e):
            print("usesNonExemptEncryption already set, skipping")
        else:
            raise

    try:
        api("PATCH", f"/apps/{app_id}", json={
            "data": {
                "type": "apps",
                "id": app_id,
                "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"},
            }
        })
    except RuntimeError as e:
        if "409" in str(e):
            print("contentRightsDeclaration already set, skipping")
        else:
            raise

    # Set pricing (free) if not already set
    try:
        # Find free price point for JPN
        price_data = api("GET", f"/apps/{app_id}/appPricePoints?filter[territory]=JPN&limit=200")
        free_point_id = None
        for pp in price_data.get("data", []):
            if pp["attributes"].get("customerPrice") == "0.0" or pp["attributes"].get("customerPrice") == "0":
                free_point_id = pp["id"]
                break
        if free_point_id:
            api("POST", "/appPriceSchedules", json={
                "data": {
                    "type": "appPriceSchedules",
                    "relationships": {
                        "app": {"data": {"type": "apps", "id": app_id}},
                        "baseTerritory": {"data": {"type": "territories", "id": "JPN"}},
                        "manualPrices": {"data": [{"type": "appPrices", "id": "${price1}"}]}
                    }
                },
                "included": [{
                    "type": "appPrices",
                    "id": "${price1}",
                    "attributes": {"startDate": None},
                    "relationships": {
                        "appPricePoint": {"data": {"type": "appPricePoints", "id": free_point_id}}
                    }
                }]
            })
            print("Pricing set to free")
        else:
            print("WARNING: Could not find free price point")
    except RuntimeError as e:
        print(f"Pricing: {e}")

    # Set copyright on the version
    try:
        api("PATCH", f"/appStoreVersions/{version_id}", json={
            "data": {
                "type": "appStoreVersions", "id": version_id,
                "attributes": {"copyright": "2026 tokyonasu"}
            }
        })
        print("Copyright set")
    except RuntimeError as e:
        print(f"Copyright: {e}")

    review_details = api("GET", f"/appStoreVersions/{version_id}/appStoreReviewDetail")
    attrs = {**REVIEW_CONTACT, "demoAccountRequired": False, "demoAccountName": "", "demoAccountPassword": ""}
    if review_details.get("data"):
        detail_id = review_details["data"]["id"]
        api("PATCH", f"/appStoreReviewDetails/{detail_id}", json={
            "data": {"type": "appStoreReviewDetails", "id": detail_id, "attributes": attrs}
        })
    else:
        api("POST", "/appStoreReviewDetails", json={
            "data": {
                "type": "appStoreReviewDetails",
                "attributes": attrs,
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
            }
        })

    for attempt in range(5):
        try:
            api("PATCH", f"/appStoreVersions/{version_id}/relationships/build", json={
                "data": {"type": "builds", "id": build_id}
            })
            print("Build linked to version")
            break
        except RuntimeError as e:
            if "409" in str(e):
                print("Build already linked to version, skipping")
                break
            elif attempt < 4:
                print(f"Build link attempt {attempt + 1} failed, retrying in 30s...")
                time.sleep(30)
            else:
                raise

    loc_id = get_localization_id(version_id)
    if loc_id:
        try:
            api("PATCH", f"/appStoreVersionLocalizations/{loc_id}", json={
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "id": loc_id,
                    "attributes": {
                        "whatsNew": "初回リリース",
                        "privacyPolicyUrl": "https://snarfnet.github.io/",
                        "marketingUrl": "https://snarfnet.github.io/",
                        "supportUrl": "https://snarfnet.github.io/",
                    },
                }
            })
            print("whatsNew set")
        except RuntimeError as e:
            if "409" in str(e):
                print("whatsNew already set, skipping")
            else:
                raise

    # Clean up ALL stale review submissions
    canceled = False
    for state in ["READY_FOR_REVIEW", "COMPLETING", "UNRESOLVED_ISSUES", "WAITING_FOR_REVIEW"]:
        try:
            existing = api("GET", f"/apps/{app_id}/reviewSubmissions?filter[state]={state}")
            for item in existing.get("data", []):
                try:
                    api("PATCH", f"/reviewSubmissions/{item['id']}", json={
                        "data": {"type": "reviewSubmissions", "id": item["id"], "attributes": {"canceled": True}}
                    })
                    print(f"Canceled {item['id']} ({state})")
                    canceled = True
                except RuntimeError as e:
                    print(f"Cancel {item['id']} failed: {e}")
        except RuntimeError:
            pass

    if canceled:
        print("Waiting 30s for cancellations...")
        time.sleep(30)

    # Try reusing existing empty READY_FOR_REVIEW submission
    review_id = None
    try:
        existing = api("GET", f"/apps/{app_id}/reviewSubmissions?filter[state]=READY_FOR_REVIEW&limit=10")
        for sub in existing.get("data", []):
            sid = sub["id"]
            items = api("GET", f"/reviewSubmissions/{sid}/items")
            if not items.get("data"):
                review_id = sid
                print(f"Reusing submission: {review_id}")
                break
    except RuntimeError:
        pass

    if not review_id:
        for attempt in range(5):
            try:
                review = api("POST", "/reviewSubmissions", json={
                    "data": {
                        "type": "reviewSubmissions",
                        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                    }
                })
                review_id = review["data"]["id"]
                print(f"Created submission: {review_id}")
                break
            except RuntimeError as e:
                print(f"Create attempt {attempt+1}/5: {e}")
                time.sleep(15)

    if not review_id:
        print("Could not create review submission")
        return

    try:
        api("POST", "/reviewSubmissionItems", json={
            "data": {
                "type": "reviewSubmissionItems",
                "relationships": {
                    "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": review_id}},
                    "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                },
            }
        })
        print("Item added")
    except RuntimeError as e:
        print(f"Add item failed: {e}")
        return

    try:
        api("PATCH", f"/reviewSubmissions/{review_id}", json={
            "data": {"type": "reviewSubmissions", "id": review_id, "attributes": {"submitted": True}}
        })
        print("Submitted for review!")
    except RuntimeError as e:
        print(f"Submit failed: {e}")


if __name__ == "__main__":
    main()
