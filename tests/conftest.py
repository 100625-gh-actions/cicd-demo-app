"""
Pytest fixtures for the CI/CD Demo App test suite.
"""

import sys
import os
import pytest

# ---------------------------------------------------------------------------
# Make sure the app package is importable regardless of how pytest is invoked.
# ---------------------------------------------------------------------------
sys.path.insert(
    0, os.path.join(os.path.dirname(__file__), os.pardir, "app")
)

from app import app as flask_app  # noqa: E402


@pytest.fixture()
def app():
    """Create and configure the Flask application for testing."""
    flask_app.config.update({"TESTING": True})
    yield flask_app


@pytest.fixture()
def client(app):
    """Provide a Flask test client."""
    return app.test_client()
