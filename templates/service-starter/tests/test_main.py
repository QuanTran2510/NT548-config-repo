import json
import os
import sys
import threading
import unittest
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import main


class ServiceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = main.make_server(0)
        cls.base = f"http://127.0.0.1:{cls.server.server_port}"
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()

    def test_health(self):
        with urllib.request.urlopen(self.base + "/healthz") as r:
            self.assertEqual((r.status, r.read()), (200, b"ok"))

    def test_root_reports_the_service(self):
        with urllib.request.urlopen(self.base + "/") as r:
            self.assertEqual(json.load(r)["status"], "running")

    def test_unknown_path_is_404(self):
        with self.assertRaises(urllib.error.HTTPError) as cm:
            urllib.request.urlopen(self.base + "/nope")
        self.assertEqual(cm.exception.code, 404)


if __name__ == "__main__":
    unittest.main()
