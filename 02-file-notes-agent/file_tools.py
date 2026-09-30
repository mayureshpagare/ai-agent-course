from pathlib import Path

def list_files(directory: str = '.') -> str:
    """
    List all files in the specified directory.

    Args:
        directory: The path to the directory to list files from.

    Returns:
        A formatted list of files in the directory.
    """

    path = Path(directory)
    if not path.exists():
        return f"The directory '{directory}' does not exist."

    if not path.is_dir():
        return f"The path '{directory}' is not a directory."

    items = []

    for item in path.iterdir():
        item_type = "DIR" if item.is_dir() else "FILE"  
        items.append(f"{item_type}: {item.name}")
    if not items:
        return f"No files found in the directory '{directory}'."

    return "\n".join(items)

def read_file(file_path: str) -> str:
    """
    Read the content of a specified file.

    Args:
        file_path: The path to the file to read.

    Returns:
        The content of the file or an error message if the file does not exist.
    """
    path = Path(file_path)

    if not path.exists():
        return f"The file '{file_path}' does not exist."

    if not path.is_file():
        return f"The path '{file_path}' is not a file."

    try:
        return path.read_text(encoding='utf-8')
    except Exception as e:
        return (
            "The file does not appear to be "
            "a UTF-8 text file."
        )

def get_file_info(file_path: str) -> str:
    """
    Get information about a specified file.

    Args:
        file_path: The path to the file to get information about.

    Returns:
        A formatted string containing the file's size and last modified time,
        or an error message if the file does not exist.
    """
    path = Path(file_path)

    if not path.exists():
        return f"The file '{file_path}' does not exist."

    if not path.is_file():
        return f"The path '{file_path}' is not a file."

    size = path.stat().st_size
    last_modified = path.stat().st_mtime

    return (
        f"File: {file_path}\n"
        f"Extension: {path.suffix}\n"
        f"Size: {size} bytes\n"
        f"Directory: {path.parent}\n"
        f"Last Modified: {last_modified}"
    )