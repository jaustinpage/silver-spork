"""Skeleton init file."""
import sys
import time

if sys.version_info[:2] >= (3, 8):
    from importlib.metadata import PackageNotFoundError  # pragma: no cover
    from importlib.metadata import version  # pragma: no cover
else:
    from importlib_metadata import PackageNotFoundError  # pragma: no cover
    from importlib_metadata import version  # pragma: no cover

from flask import Flask

try:
    # Change here if project is renamed and does not equal the package name
    dist_name = "silver-spork"
    __version__ = version(dist_name)
except PackageNotFoundError:  # pragma: no cover
    __version__ = "unknown"
finally:
    del version, PackageNotFoundError


def create_app() -> Flask:
    """Create and configure flask app.

    :returns: Configured flask app.
    """
    app = Flask(__name__, instance_relative_config=True)

    @app.route("/")
    def root() -> str:
        return {"message": "Automate all the things!", "timestamp": int(time.time())}

    return app  # noqa: R504
