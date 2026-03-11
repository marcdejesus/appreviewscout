def test_list_reviews_returns_all_rows(client, seed_db) -> None:
    response = client.get("/reviews")

    assert response.status_code == 200
    assert len(response.json()) == 2


def test_list_reviews_filters_by_app_id(client, seed_db) -> None:
    response = client.get("/reviews", params={"app_id": "com.test.app"})

    assert response.status_code == 200
    assert len(response.json()) == 2


def test_list_reviews_filters_by_feature_request_only(client, seed_db) -> None:
    response = client.get("/reviews", params={"feature_request_only": "true"})

    assert response.status_code == 200
    data = response.json()
    rows = data["reviews"]
    assert len(rows) == 1
    assert rows[0]["has_feature_request"] == 1


def test_list_reviews_filters_by_platform(client, seed_db) -> None:
    response = client.get("/reviews", params={"platform": "Google Play"})

    assert response.status_code == 200
    assert len(response.json()) == 2


def test_feature_requests_endpoint_returns_flagged_rows(client, seed_db) -> None:
    response = client.get("/feature-requests")

    assert response.status_code == 200
    assert len(response.json()) == 1


def test_feature_requests_endpoint_filters_by_app(client, seed_db) -> None:
    response = client.get("/feature-requests", params={"app_id": "com.test.app"})

    assert response.status_code == 200
    assert len(response.json()) == 1


def test_feature_requests_endpoint_returns_empty_for_wrong_app(client, seed_db) -> None:
    response = client.get("/feature-requests", params={"app_id": "com.unknown.app"})

    assert response.status_code == 200
    assert response.json() == []


def test_list_reviews_filtered_by_project_id(client, seed_db) -> None:
    app_pk = seed_db["app_pk"]
    create_resp = client.post(
        "/projects",
        json={"name": "P1", "app_ids": [app_pk]},
    )
    assert create_resp.status_code == 200
    project_id = create_resp.json()["id"]

    response = client.get("/reviews", params={"project_id": project_id})
    assert response.status_code == 200
    data = response.json()
    assert "reviews" in data
    assert "total" in data
    assert data["total"] == 2
    assert len(data["reviews"]) == 2


def test_list_reviews_with_project_id_empty_when_no_apps_in_project(
    client, seed_db
) -> None:
    create_resp = client.post("/projects", json={"name": "Empty", "app_ids": []})
    assert create_resp.status_code == 200
    project_id = create_resp.json()["id"]

    response = client.get("/reviews", params={"project_id": project_id})
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 0
    assert data["reviews"] == []


def test_feature_requests_filtered_by_project_id(client, seed_db) -> None:
    app_pk = seed_db["app_pk"]
    create_resp = client.post(
        "/projects",
        json={"name": "P1", "app_ids": [app_pk]},
    )
    assert create_resp.status_code == 200
    project_id = create_resp.json()["id"]

    response = client.get("/feature-requests", params={"project_id": project_id})
    assert response.status_code == 200
    rows = response.json()
    assert len(rows) == 1


def test_update_review_pin_404_when_review_not_found(client) -> None:
    response = client.patch(
        "/reviews/99999/pin",
        json={"pinned": True},
    )
    assert response.status_code == 404
    assert response.json()["detail"] == "Review not found"
