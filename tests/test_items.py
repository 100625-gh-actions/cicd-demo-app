"""
Additional tests focused on the items API endpoints.

Covers:
- Item data structure validation
- 404 behaviour for missing items
- Item count verification
- Price value correctness
"""


class TestItemDataStructure:
    """Validate the shape and content of item objects."""

    def test_item_id_is_integer(self, client):
        """Each item's id should be an integer."""
        data = client.get("/api/items").get_json()
        for item in data:
            assert isinstance(item["id"], int)

    def test_item_name_is_string(self, client):
        """Each item's name should be a string."""
        data = client.get("/api/items").get_json()
        for item in data:
            assert isinstance(item["name"], str)

    def test_item_price_is_number(self, client):
        """Each item's price should be a numeric value (int or float)."""
        data = client.get("/api/items").get_json()
        for item in data:
            assert isinstance(item["price"], (int, float))

    def test_item_prices_are_positive(self, client):
        """All prices should be greater than zero."""
        data = client.get("/api/items").get_json()
        for item in data:
            assert item["price"] > 0

    def test_item_ids_are_unique(self, client):
        """All item ids should be unique."""
        data = client.get("/api/items").get_json()
        ids = [item["id"] for item in data]
        assert len(ids) == len(set(ids))


class TestItemNotFound:
    """Verify correct 404 handling for non-existent items."""

    def test_negative_id_returns_404(self, client):
        """A negative item id should return 404."""
        response = client.get("/api/items/0")
        assert response.status_code == 404

    def test_large_id_returns_404(self, client):
        """An extremely large item id should return 404."""
        response = client.get("/api/items/999999")
        assert response.status_code == 404

    def test_404_response_is_json(self, client):
        """404 responses should still return valid JSON."""
        response = client.get("/api/items/999")
        assert "application/json" in response.content_type
        data = response.get_json()
        assert data is not None


class TestItemCount:
    """Verify the expected number of items in the demo dataset."""

    def test_items_count_is_five(self, client):
        """The demo dataset should contain exactly 5 items."""
        data = client.get("/api/items").get_json()
        assert len(data) == 5

    def test_first_item_is_widget_a(self, client):
        """The first item in the list should be Widget A."""
        data = client.get("/api/items").get_json()
        assert data[0]["name"] == "Widget A"

    def test_last_item_is_doohickey_e(self, client):
        """The last item in the list should be Doohickey E."""
        data = client.get("/api/items").get_json()
        assert data[-1]["name"] == "Doohickey E"

    def test_widget_a_price(self, client):
        """Widget A should cost 9.99."""
        data = client.get("/api/items/1").get_json()
        assert data["price"] == 9.99

    def test_gadget_c_price(self, client):
        """Gadget C should cost 24.50."""
        data = client.get("/api/items/3").get_json()
        assert data["price"] == 24.50
