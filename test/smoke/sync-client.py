# Does what Firefox does after sign-in: get a token from the tokenserver, then Hawk-sign storage requests.
# Usage: sync-client.py <app url> <public host> put|get <collection> <id> [payload]
# Prints the token's api_endpoint, then the payload for get.

import base64
import hashlib
import hmac
import json
import os
import sys
import time
import urllib.request
from urllib.parse import urlparse

app_url, public_host, action, collection, bso_id = sys.argv[1:6]
proxy_headers = {"Host": public_host, "X-Forwarded-Proto": "https"}

fxa_token = json.dumps({
    "status": 200,
    "body": {
        "user": "smoketestuser",
        "client_id": "smoketest",
        "scope": ["https://identity.mozilla.com/apps/oldsync"],
        "generation": 1,
    },
})
# X-KeyID is <keys_changed_at>-<url-safe base64 client state>
key_id = "1234-" + base64.urlsafe_b64encode(b"\x01" * 16).decode().rstrip("=")

request = urllib.request.Request(f"{app_url}/1.0/sync/1.5", headers={
    **proxy_headers, "Authorization": f"Bearer {fxa_token}", "X-KeyID": key_id,
})
token = json.load(urllib.request.urlopen(request))
print(token["api_endpoint"])


def hawk(method, path):
    # https://github.com/mozilla/hawk/blob/main/API.md
    ts = str(int(time.time()))
    nonce = base64.b64encode(os.urandom(6)).decode()
    normalized = f"hawk.1.header\n{ts}\n{nonce}\n{method}\n{path}\n{public_host}\n443\n\n\n"
    mac = base64.b64encode(hmac.new(token["key"].encode(), normalized.encode(), hashlib.sha256).digest()).decode()
    return f'Hawk id="{token["id"]}", ts="{ts}", nonce="{nonce}", mac="{mac}"'


path = f"{urlparse(token['api_endpoint']).path}/storage/{collection}/{bso_id}"
if action == "put":
    body = json.dumps({"payload": sys.argv[6]}).encode()
    request = urllib.request.Request(f"{app_url}{path}", data=body, method="PUT", headers={
        **proxy_headers, "Authorization": hawk("PUT", path), "Content-Type": "application/json",
    })
    urllib.request.urlopen(request)
else:
    request = urllib.request.Request(f"{app_url}{path}", headers={**proxy_headers, "Authorization": hawk("GET", path)})
    print(json.load(urllib.request.urlopen(request))["payload"])
