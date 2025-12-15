import http.server
import ssl
import socket

server_address = ('0.0.0.0', 5005)
httpd = http.server.HTTPServer(server_address, http.server.SimpleHTTPRequestHandler)

context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(
    certfile=r"C:\Users\viet.ta\192.168.123.185.pem",
    keyfile=r"C:\Users\viet.ta\192.168.123.185-key.pem"
)


httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

print("Serving HTTPS on 0.0.0.0 port 5005 ...")
httpd.serve_forever()
