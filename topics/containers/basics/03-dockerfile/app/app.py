"""
basics/03-dockerfile/app/app.py
Minimal Flask app — demonstrates the python.dockerfile Dockerfile.

Routes:
  GET /         service info
  GET /health   health check (used by Dockerfile HEALTHCHECK)
"""

import os
import platform
import sys

from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/health")
def health():
    return jsonify({"status": "ok"}), 200


@app.get("/")
def index():
    return jsonify({
        "message":     "Hello from Docker!",
        "hostname":    platform.node(),
        "platform":    platform.system(),
        "python":      sys.version.split()[0],
        "environment": os.getenv("FLASK_ENV", "unknown"),
    })


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8000"))
    app.run(host="0.0.0.0", port=port)