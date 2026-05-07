from flask import Flask, jsonify, request

app = Flask(__name__)

@app.route("/")
def index():
    return jsonify({"status": "ok", "message": "DevSecOps Demo API"})

@app.route("/health")
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
    app.run(host="0.0.0.0", port=5000)
