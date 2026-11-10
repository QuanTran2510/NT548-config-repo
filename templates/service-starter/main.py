"""Smallest useful service: GET / and GET /healthz. Standard library only, listens on $PORT (default 8080)."""
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

SERVICE = os.environ.get("SERVICE_NAME", "service-starter")


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/healthz":
            body, ctype = b"ok", "text/plain"
        elif self.path == "/":
            body, ctype = json.dumps({"service": SERVICE, "status": "running"}).encode(), "application/json"
        else:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):          # one line per request on stdout (kubectl logs)
        print(self.address_string(), fmt % args, flush=True)


def make_server(port=None):
    return HTTPServer(("0.0.0.0", int(port if port is not None else os.environ.get("PORT", "8080"))), Handler)


if __name__ == "__main__":
    make_server().serve_forever()
