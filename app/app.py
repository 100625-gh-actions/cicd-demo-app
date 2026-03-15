"""
CI/CD Demo App - A Flask application for demonstrating CI/CD pipelines.

This app provides:
- A visual HTML UI showing app version, environment, and features
- REST API endpoints for health checks, versioning, and item management
"""

import os
from flask import Flask, render_template, jsonify

app = Flask(__name__)

# ---------------------------------------------------------------------------
# Configuration from environment variables
# ---------------------------------------------------------------------------
APP_VERSION = os.environ.get("APP_VERSION", "0.1.0")
ENVIRONMENT = os.environ.get("ENVIRONMENT", "development")
BUILD_SHA = os.environ.get("BUILD_SHA", "local")

# ---------------------------------------------------------------------------
# Demo data
# ---------------------------------------------------------------------------
ITEMS = [
    {"id": 1, "name": "Widget A", "price": 9.99},
    {"id": 2, "name": "Widget B", "price": 14.99},
    {"id": 3, "name": "Gadget C", "price": 24.50},
    {"id": 4, "name": "Gizmo D", "price": 7.25},
    {"id": 5, "name": "Doohickey E", "price": 19.99},
]

FEATURES = [
    {
        "name": "Health Monitoring",
        "description": "Real-time health checks to ensure the application is running smoothly.",
        "icon": "&#128154;",  # green heart
    },
    {
        "name": "Version Tracking",
        "description": "Automatic version and build SHA tracking through environment variables.",
        "icon": "&#128196;",  # page facing up
    },
    {
        "name": "REST API",
        "description": "Full RESTful API for managing items with JSON responses.",
        "icon": "&#128268;",  # electric plug
    },
    {
        "name": "Automated Testing",
        "description": "Comprehensive test suite with pytest for reliable deployments.",
        "icon": "&#9989;",  # check mark
    },
]

# ---------------------------------------------------------------------------
# HTML UI
# ---------------------------------------------------------------------------


@app.route("/")
def index():
    """Render the main dashboard page."""
    return render_template(
        "index.html",
        version=APP_VERSION,
        environment=ENVIRONMENT,
        build_sha=BUILD_SHA,
        features=FEATURES,
    )


# ---------------------------------------------------------------------------
# REST API
# ---------------------------------------------------------------------------


@app.route("/api/health")
def api_health():
    """Return application health status."""
    return jsonify(
        {
            "status": "healthy",
            "version": APP_VERSION,
            "environment": ENVIRONMENT,
        }
    )


@app.route("/api/version")
def api_version():
    """Return version and build information."""
    return jsonify(
        {
            "version": APP_VERSION,
            "build_sha": BUILD_SHA,
            "environment": ENVIRONMENT,
        }
    )


@app.route("/api/items")
def api_items():
    """Return the list of all demo items."""
    return jsonify(ITEMS)


@app.route("/api/items/<int:item_id>")
def api_item(item_id):
    """Return a single item by its id, or 404 if not found."""
    for item in ITEMS:
        if item["id"] == item_id:
            return jsonify(item)
    return jsonify({"error": "Item not found"}), 404


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=True)
