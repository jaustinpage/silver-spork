"""
Starting point for console script.

To run this script uncomment the following lines in the
``[options.entry_points]`` section in ``setup.cfg``::

    console_scripts =
         fibonacci = silver_spork.skeleton:run

Then run ``pip install .`` (or ``pip install -e .`` for editable mode)
which will install the command ``fibonacci`` inside your current environment.

Besides console scripts, the header (i.e. until ``_logger``...) of this file can
also be used as template for Python modules.

Note:
    This skeleton file can be safely removed if not needed!

References:
    - https://setuptools.readthedocs.io/en/latest/userguide/entry_point.html
    - https://pip.pypa.io/en/stable/reference/pip_install
"""

import argparse
import logging
import sys
from typing import List

from silver_spork import __version__

__author__ = "Austin Page"
__copyright__ = "Austin Page"
__license__ = "MIT"

_logger = logging.getLogger(__name__)


# ---- Python API ----
# The functions defined in this section can be imported by users in their
# Python scripts/interactive interpreter, e.g. via
# `from silver_spork.skeleton import fib`,
# when using this Python module as a library.


def fib(index: int) -> int:
    """Fibonacci example function.

    :param index: index of fib desired
    :returns: n-th Fibonacci number
    :raises ValueError: if index is out of range (negative or zero)
    """
    if 0 >= index:
        raise ValueError("index out of range")
    a, b = 1, 1
    for _ in range(index - 1):
        a, b = b, a + b
    return a


# ---- CLI ----
# The functions defined in this section are wrappers around the main Python
# API allowing them to be called directly from the terminal as a CLI
# executable/script.


def parse_args(args: List[str]) -> argparse.Namespace:
    """Parse command line parameters.

    :param args: command line parameters as list of strings
    :returns: command line parameters namespace
    """
    parser = argparse.ArgumentParser(description="Just a Fibonacci demonstration")
    parser.add_argument(
        "--version",
        action="version",
        version="silver-spork {ver}".format(ver=__version__),
    )
    parser.add_argument(dest="n", help="n-th Fibonacci number", type=int, metavar="INT")
    parser.add_argument(
        "-v",
        "--verbose",
        dest="loglevel",
        help="set loglevel to INFO",
        action="store_const",
        const=logging.INFO,
    )
    parser.add_argument(
        "-vv",
        "--very-verbose",
        dest="loglevel",
        help="set loglevel to DEBUG",
        action="store_const",
        const=logging.DEBUG,
    )
    return parser.parse_args(args)


def setup_logging(loglevel: int) -> None:
    """Set log file config.

    :param loglevel: minimum loglevel for emitting messages
    """
    logformat = "[%(asctime)s] %(levelname)s:%(name)s:%(message)s"
    logging.basicConfig(
        level=loglevel, stream=sys.stdout, format=logformat, datefmt="%Y-%m-%d %H:%M:%S"
    )


def main(args: List[str]) -> None:
    """Wrap Main.

    allows :func:`fib` to be called with string arguments in a CLI fashion

    Instead of returning the value from :func:`fib`, it prints the result to the
    ``stdout`` in a nicely formatted message.

    :param args: command line parameters as list of strings
    """
    args = parse_args(args)
    setup_logging(args.loglevel)
    _logger.debug("Starting crazy calculations...")
    print(  # noqa: T001
        "The {0}-th Fibonacci number is {1}".format(args.n, fib(args.n))
    )
    _logger.info("Script ends here")


def run() -> None:
    """Call main.

    Calls :func:`main` passing the CLI arguments extracted from :obj:`sys.argv`

    This function can be used as entry point to create console scripts with setuptools.
    """
    main(sys.argv[1:])  # pragma: no cover


if __name__ == "__main__":
    # ^  This is a guard statement that will prevent the following code from
    #    being executed in the case someone imports this file instead of
    #    executing it as a script.
    #    https://docs.python.org/3/library/__main__.html

    # After installing your project with pip, users can also run your Python
    # modules as scripts via the ``-m`` flag, as defined in PEP 338::
    #
    #     python -m silver_spork.skeleton 42
    #
    run()
