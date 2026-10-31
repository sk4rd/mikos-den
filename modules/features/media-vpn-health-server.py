import json
import os
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

STATUS_FILE = "/run/media-vpn-health/status.json"
MAX_AGE_SECONDS = 180


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/health":
            self.send_error(404)
            return

        try:
            age = time.time() - os.stat(STATUS_FILE).st_mtime
            with open(STATUS_FILE, encoding="utf-8") as handle:
                data = json.load(handle)
            healthy = bool(data.get("ok")) and age <= MAX_AGE_SECONDS
            data["age_seconds"] = round(age)
        except Exception as exc:  # noqa: BLE001
            data = {"ok": False, "error": str(exc)}
            healthy = False

        body = json.dumps(data).encode("utf-8")
        self.send_response(200 if healthy else 503)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, _format, *_args):
        pass


HTTPServer(("127.0.0.1", 9188), Handler).serve_forever()
