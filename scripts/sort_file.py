import argparse
import logging
from pathlib import Path


logger = logging.getLogger(__name__)

class FileNotSortedError(Exception):
    def __init__(self, filepath, message="File is not sorted"):
        self.filepath = filepath
        self.message = message
        super().__init__(self.message)


def safe_replace(filepath, contents):
    new_contents = filepath.with_suffix(".new")
    with new_contents.open("w") as new_file:
        new_file.writelines(contents)
    new_contents.replace(filepath)

def get_file_lines(filepath):
    with filepath.open("r") as the_file:
        contents = the_file.readlines()
    return contents

def sort_file_contents(filepath):
    contents = get_file_lines(filepath)
    contents = {c.lower() for c in contents}
    return sorted(contents)

def sort_file(filepath):
    safe_replace(filepath, sort_file_contents(filepath))

def check_file_contents(filepath):
    return get_file_lines(filepath) == sort_file_contents(filepath)

def check_file(filepath):
    if not check_file_contents(filepath):
        raise FileNotSortedError(filepath)

def parse_args():
    parser = argparse.ArgumentParser("sort_file.py")
    parser.add_argument("filepath", help="The file to sort", type=Path)
    parser.add_argument("--check", help="Check the file", action='store_true')
    return parser.parse_args()


def main():
    args = parse_args()
    if not args.filepath.is_file():
        raise FileNotFoundError()
    if args.check:
        check_file(args.filepath)
    else:
        sort_file(args.filepath)


if __name__ == "__main__":
    main()
