"""Setup flask fixture."""
import pytest

import silver_spork


@pytest.fixture(scope="session")
def app():
    return silver_spork.create_app()
