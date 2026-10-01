from flask import Flask, jsonify, request

app = Flask(__name__)

# Sent on every response, including errors. This is a JSON-only API, so the
# CSP allows nothing to load and nothing to frame it. ZAP's baseline scan
# (Phase 3) fails the pipeline if these go missing.
SECURITY_HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Content-Security-Policy": "default-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
    "Permissions-Policy": "camera=(), geolocation=(), microphone=()",
    "Cross-Origin-Resource-Policy": "same-origin",
    "Referrer-Policy": "no-referrer",
    "Cache-Control": "no-store",
}


@app.after_request
def set_security_headers(response):
    response.headers.update(SECURITY_HEADERS)
    return response

@app.route("/", methods=["GET"])
def index():
    return jsonify({"status": "ok", "message": "DevSecOps Demo API"})

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy"})

@app.route("/api/items", methods=["GET"])
def get_items():
    items = [
        {"id": 1, "name": "Widget A", "price": 9.99},
        {"id": 2, "name": "Widget B", "price": 19.99},
    ]
    return jsonify({"items": items})

@app.route("/api/items", methods=["POST"])
def create_item():
    data = request.get_json()
    if not data or "name" not in data:
        return jsonify({"error": "name is required"}), 400
    return jsonify({"id": 3, "name": data["name"]}), 201

if __name__ == "__main__":
    # Local dev server only. The container runs gunicorn (see Dockerfile).
    app.run(host="127.0.0.1", port=5000)
