from __future__ import annotations


def test_list_projects_empty(client) -> None:
    response = client.get("/projects")
    assert response.status_code == 200
    assert response.json() == []


def test_create_project_rejects_empty_name(client) -> None:
    response = client.post(
        "/projects",
        json={"name": "   ", "description": "A test project"},
    )
    assert response.status_code == 400
    assert "required" in response.json()["detail"].lower()


def test_create_project(client) -> None:
    response = client.post(
        "/projects",
        json={"name": "My Project", "description": "A test project"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "My Project"
    assert body["description"] == "A test project"
    assert "id" in body
    assert "created_at" in body
    assert body.get("app_ids") == []


def test_create_project_with_app_ids(client, seed_db) -> None:
    app_pk = seed_db["app_pk"]
    response = client.post(
        "/projects",
        json={"name": "With Apps", "app_ids": [app_pk]},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "With Apps"
    assert body["app_ids"] == [app_pk]


def test_get_project(client) -> None:
    create_resp = client.post("/projects", json={"name": "Get Me"})
    assert create_resp.status_code == 200
    pid = create_resp.json()["id"]

    response = client.get(f"/projects/{pid}")
    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "Get Me"
    assert "app_ids" in body


def test_get_project_404(client) -> None:
    response = client.get("/projects/99999")
    assert response.status_code == 404


def test_update_project(client) -> None:
    create_resp = client.post("/projects", json={"name": "Original"})
    assert create_resp.status_code == 200
    pid = create_resp.json()["id"]

    response = client.patch(
        f"/projects/{pid}",
        json={"name": "Updated", "description": "New desc"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "Updated"
    assert body["description"] == "New desc"


def test_update_project_404(client) -> None:
    response = client.patch("/projects/99999", json={"name": "X"})
    assert response.status_code == 404


def test_update_project_rejects_empty_name(client) -> None:
    create_resp = client.post("/projects", json={"name": "Original"})
    assert create_resp.status_code == 200
    pid = create_resp.json()["id"]
    response = client.patch(
        f"/projects/{pid}",
        json={"name": "   "},
    )
    assert response.status_code == 400
    assert "non-empty" in response.json()["detail"].lower()


def test_delete_project(client) -> None:
    create_resp = client.post("/projects", json={"name": "To Delete"})
    assert create_resp.status_code == 200
    pid = create_resp.json()["id"]

    response = client.delete(f"/projects/{pid}")
    assert response.status_code == 200
    assert response.json()["deleted"] is True

    get_resp = client.get(f"/projects/{pid}")
    assert get_resp.status_code == 404


def test_delete_project_404(client) -> None:
    response = client.delete("/projects/99999")
    assert response.status_code == 404
