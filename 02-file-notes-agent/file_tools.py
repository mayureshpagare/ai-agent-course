from datetime import datetime
from pathlib import Path

# Resource limits. Tools must never let the model pull an unbounded amount of
# data into memory or into the conversation.
DEFAULT_MAX_CHARACTERS = 10_000
HARD_MAX_CHARACTERS = 50_000
MAX_FIND_RESULTS = 100
SKIPPED_DIRECTORIES = {".git", ".venv", "venv", "__pycache__", "node_modules"}

def list_files(directory: str = '.') -> list | dict:
    """
    List all files in the specified directory.

    Args:
        directory: The path to the directory to list files from.

    Returns:
        A list of the files and folders in the directory.
    """

    path = Path(directory)
    if not path.exists():
        return {"error": f"The directory '{directory}' does not exist."}

    if not path.is_dir():
        return {"error": f"The path '{directory}' is not a directory."}

    items = []

    for item in path.iterdir():
        item_type = "directory" if item.is_dir() else "file"
        items.append({"name": item.name, "type": item_type})
    if not items:
        return {"message": f"No files found in the directory '{directory}'."}

    return items

def find_files(directory: str, filename: str) -> dict:
    """
    Search a directory and all its subdirectories for files with a given name.

    Args:
        directory: The directory to start searching from, for example '.'.
        filename: The file name to look for, for example 'docker-compose.yml'.
            Wildcards such as '*.yml' are allowed.

    Returns:
        The paths of the matching files.
    """
    filename = (filename or "").strip()
    if not filename:
        return {"error": "Please provide a file name to search for."}
    if "/" in filename or "\\" in filename or ".." in filename:
        return {"error": "The file name must not contain a path. Pass the folder as 'directory'."}

    path = Path(directory)
    if not path.exists():
        return {"error": f"The directory '{directory}' does not exist."}
    if not path.is_dir():
        return {"error": f"The path '{directory}' is not a directory."}

    matches = []
    truncated = False
    for match in path.rglob(filename):
        if not match.is_file():
            continue
        if SKIPPED_DIRECTORIES.intersection(match.relative_to(path).parts):
            continue
        if len(matches) == MAX_FIND_RESULTS:
            truncated = True
            break
        matches.append(str(match))

    if not matches:
        return {"message": f"No files named '{filename}' found under '{directory}'."}

    result = {"count": len(matches), "files": matches}
    if truncated:
        result["note"] = f"Only the first {MAX_FIND_RESULTS} matches are shown."
    return result

def read_file(file_path: str, max_characters: int = DEFAULT_MAX_CHARACTERS) -> dict:
    """
    Read the content of a text file, up to a maximum number of characters.

    Large files are not loaded completely; only the beginning is returned.

    Args:
        file_path: The path to the file to read.
        max_characters: The maximum number of characters to return (default 10000).

    Returns:
        The file content, and whether it was cut off because of the limit.
    """
    path = Path(file_path)

    if not path.exists():
        return {"error": f"The file '{file_path}' does not exist."}

    if not path.is_file():
        return {"error": f"The path '{file_path}' is not a file."}

    try:
        max_characters = int(max_characters)
    except (TypeError, ValueError):
        return {"error": f"max_characters must be a number, got {max_characters!r}."}
    if max_characters <= 0:
        return {"error": "max_characters must be greater than zero."}
    # The model chooses this argument, so cap it in code.
    max_characters = min(max_characters, HARD_MAX_CHARACTERS)

    try:
        with path.open(encoding="utf-8") as file:
            # Read one extra character to find out whether there is more.
            content = file.read(max_characters + 1)
    except UnicodeDecodeError:
        return {"error": "The file does not appear to be a UTF-8 text file."}
    except OSError as error:
        return {"error": f"Could not read '{file_path}': {error}"}

    truncated = len(content) > max_characters
    result = {
        "file": file_path,
        "content": content[:max_characters],
        "truncated": truncated,
    }
    if truncated:
        result["note"] = (
            f"Only the first {max_characters} characters are shown. "
            f"The file is {path.stat().st_size} bytes in total."
        )
    return result

def get_file_info(file_path: str) -> dict:
    """
    Get information about a specified file.

    Args:
        file_path: The path to the file to get information about.

    Returns:
        The file's extension, size, folder and last modified time,
        or an error message if the file does not exist.
    """
    path = Path(file_path)

    if not path.exists():
        return {"error": f"The file '{file_path}' does not exist."}

    if not path.is_file():
        return {"error": f"The path '{file_path}' is not a file."}

    stat = path.stat()

    return {
        "file": file_path,
        "extension": path.suffix,
        "size_bytes": stat.st_size,
        "directory": str(path.parent),
        "last_modified": datetime.fromtimestamp(stat.st_mtime).isoformat(timespec="seconds"),
    }
