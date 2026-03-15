"""
Comprehensive tests for the CI/CD Demo App.

Covers:
- Home page rendering
- Health endpoint
- Version endpoint
- Items list endpoint
- Single item endpoint
"""


class TestHomePage:
    """Tests for the HTML UI served at /."""

    def test_home_returns_200(self, client):
        """Home page should return HTTP 200."""
        response = client.get("/")
        assert response.status_code == 200

    def test_home_contains_app_name(self, client):
        """Home page should contain the application name."""
        response = client.get("/")
        assert b"CI/CD Demo App" in response.data

    def test_home_contains_version(self, client):
        """Home page should display the current version."""
        response = client.get("/")
        assert b"0.1.0" in response.data

    def test_home_contains_environment(self, client):
        """Home page should display the current environment."""
        response = client.get("/")
        assert b"development" in response.data

    def test_home_contains_build_sha(self, client):
        """Home page should display the build SHA in the footer."""
        response = client.get("/")
        assert b"local" in response.data

    def test_home_contains_features_section(self, client):
        """Home page should contain the Features section."""
        response = client.get("/")
        assert b"Features" in response.data

    def test_home_content_type_is_html(self, client):
        """Home page should return HTML content."""
        response = client.get("/")
        assert "text/html" in response.content_type


class TestHealthEndpoint:
    """Tests for GET /api/health."""

    def test_health_returns_200(self, client):
        """Health endpoint should return HTTP 200."""
        response = client.get("/api/health")
        assert response.status_code == 200

    def test_health_status_is_healthy(self, client):
        """Health endpoint should report status as healthy."""
        data = client.get("/api/health").get_json()
        assert data["status"] == "healthy"

    def test_health_contains_version(self, client):
        """Health endpoint should include the version."""
        data = client.get("/api/health").get_json()
        assert "version" in data
        assert data["version"] == "0.1.0"

    def test_health_contains_environment(self, client):
        """Health endpoint should include the environment."""
        data = client.get("/api/health").get_json()
        assert "environment" in data
        assert data["environment"] == "development"

    def test_health_response_is_json(self, client):
        """Health endpoint should return JSON content type."""
        response = client.get("/api/health")
        assert "application/json" in response.content_type


class TestVersionEndpoint:
    """Tests for GET /api/version."""

    def test_version_returns_200(self, client):
        """Version endpoint should return HTTP 200."""
        response = client.get("/api/version")
        assert response.status_code == 200

    def test_version_contains_version(self, client):
        """Version endpoint should include the app version."""
        data = client.get("/api/version").get_json()
        assert data["version"] == "0.1.0"

    def test_version_contains_build_sha(self, client):
        """Version endpoint should include the build SHA."""
        data = client.get("/api/version").get_json()
        assert data["build_sha"] == "local"

    def test_version_contains_environment(self, client):
        """Version endpoint should include the environment."""
        data = client.get("/api/version").get_json()
        assert data["environment"] == "development"

    def test_version_response_is_json(self, client):
        """Version endpoint should return JSON content type."""
        response = client.get("/api/version")
        assert "application/json" in response.content_type


class TestItemsListEndpoint:
    """Tests for GET /api/items."""

    def test_items_returns_200(self, client):
        """Items endpoint should return HTTP 200."""
        response = client.get("/api/items")
        assert response.status_code == 200

    def test_items_returns_list(self, client):
        """Items endpoint should return a JSON list."""
        data = client.get("/api/items").get_json()
        assert isinstance(data, list)

    def test_items_not_empty(self, client):
        """Items list should not be empty."""
        data = client.get("/api/items").get_json()
        assert len(data) > 0

    def test_items_have_correct_keys(self, client):
        """Each item should have id, name, and price keys."""
        data = client.get("/api/items").get_json()
        for item in data:
            assert "id" in item
            assert "name" in item
            assert "price" in item


class TestSingleItemEndpoint:
    """Tests for GET /api/items/<id>."""

    def test_get_existing_item(self, client):
        """Requesting an existing item should return HTTP 200."""
        response = client.get("/api/items/1")
        assert response.status_code == 200

    def test_get_existing_item_data(self, client):
        """Requesting item 1 should return correct data."""
        data = client.get("/api/items/1").get_json()
        assert data["id"] == 1
        assert data["name"] == "Widget A"
        assert data["price"] == 9.99

    def test_get_nonexistent_item_returns_404(self, client):
        """Requesting a non-existent item should return HTTP 404."""
        response = client.get("/api/items/999")
        assert response.status_code == 404

    def test_get_nonexistent_item_error_message(self, client):
        """404 response should include an error message."""
        data = client.get("/api/items/999").get_json()
        assert "error" in data
        assert data["error"] == "Item not found"
