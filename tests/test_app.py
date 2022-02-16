"""Test web app."""
from freezegun import freeze_time


@freeze_time("1993-02-12")
def test_startup(client):
    """Asserts that your service starts and responds."""
    r = client.get("/")
    assert r.status_code == 200
    assert r.json["message"] == "Automate all the things!"
    assert r.json["timestamp"] == 729475200
