# from http.server import HTTPServer, SimpleHTTPRequestHandler

# class CORSRequestHandler(SimpleHTTPRequestHandler):
#     def end_headers(self):
#         self.send_header('Access-Control-Allow-Origin', '*')
#         self.send_header('Access-Control-Allow-Methods', 'GET')
#         self.send_header('Access-Control-Allow-Headers', 'Content-Type')
#         super().end_headers()

# HTTPServer(('0.0.0.0', 8181), CORSRequestHandler).serve_forever()

import os
from http.server import HTTPServer, SimpleHTTPRequestHandler

os.chdir("canvaskit")  # folder chứa file để public

class CORSRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

HTTPServer(('0.0.0.0', 8381), CORSRequestHandler).serve_forever()
