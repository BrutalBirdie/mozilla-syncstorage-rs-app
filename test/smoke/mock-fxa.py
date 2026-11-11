# Mock Mozilla accounts OAuth server: the bearer token is the JSON /v1/verify should answer with.
# Based on https://github.com/mozilla-services/syncstorage-rs/blob/master/tools/integration_tests/tokenserver/mock_fxa_server.py

import json
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def reply(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        # no keys makes the tokenserver fall back to /v1/verify
        if self.path == "/v1/jwks":
            self.reply(200, {"keys": []})
        else:
            self.reply(404, {})

    def do_POST(self):
        if self.path != "/v1/verify":
            self.reply(404, {})
            return
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        token = json.loads(body["token"])
        self.reply(token["status"], token["body"])


HTTPServer(("0.0.0.0", 6000), Handler).serve_forever()
