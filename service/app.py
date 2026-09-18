import os
import socket
from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/")
def index():
    return jsonify({
        "app": os.environ.get("APP_NAME", "unknown"),
        "version": os.environ.get("VERSION", "unknown"),
        "pod": socket.gethostname(),
    })

@app.route("/healthz")
def healthz():
    return "ok", 200

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
