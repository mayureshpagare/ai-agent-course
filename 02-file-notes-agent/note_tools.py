from database import DEFAULT_CATEGORY, get_connection


def _row_to_note(row):
    """Convert a (id, content, category, created_at) row into a dictionary."""
    note_id, content, category, created_at = row
    return {
        "id": note_id,
        "content": content,
        "category": category,
        "created_at": created_at,
    }

def _clean_text(value):
    """Return a stripped string, or None if the value is missing or blank."""
    if value is None:
        return None
    text = str(value).strip()
    return text or None

def _clean_category(category):
    """Normalize a category name so 'Docker' and ' docker ' match."""
    text = _clean_text(category)
    return text.lower() if text else None

def _parse_note_id(note_id):
    """
    Turn the model's note_id argument into a positive integer.

    Returns:
        (note_id, None) when valid, or (None, error_dict) when invalid.
    """
    if isinstance(note_id, bool):
        return None, {"error": f"Invalid note ID: {note_id!r}. Note IDs are positive integers."}
    try:
        parsed = int(str(note_id).strip())
    except (TypeError, ValueError):
        return None, {"error": f"Invalid note ID: {note_id!r}. Note IDs are positive integers."}
    if parsed <= 0:
        return None, {"error": f"Invalid note ID: {parsed}. Note IDs are positive integers."}
    return parsed, None

def save_note(content: str, category: str = DEFAULT_CATEGORY) -> dict:
    """
    Save a note to the database.

    If a note with identical content already exists, nothing new is saved
    and the existing note's ID is returned instead.

    Args:
        content: The information to remember.
        category: A short topic label such as 'database', 'docker' or 'learning'.
            Defaults to 'general'.

    Returns:
        The saved note, or details of the existing duplicate.
    """
    content = _clean_text(content)
    if content is None:
        return {"error": "Cannot save an empty note."}
    category = _clean_category(category) or DEFAULT_CATEGORY

    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("SELECT id FROM notes WHERE content = ?", (content,))
    existing = cursor.fetchone()
    if existing:
        connection.close()
        return {
            "status": "duplicate",
            "id": existing[0],
            "message": f"This information is already stored as note {existing[0]}.",
        }

    cursor.execute('''
        INSERT INTO notes (content, category) VALUES (?, ?)
    ''', (content, category))
    connection.commit()
    note_id = cursor.lastrowid
    connection.close()
    return {
        "status": "saved",
        "id": note_id,
        "content": content,
        "category": category,
    }

def list_notes() -> list | dict:
    """Return all saved notes from the database.
    Returns:
        A list of saved notes with their IDs, categories and creation times.
    """
    connection = get_connection()
    cursor = connection.cursor()

    cursor.execute("""select id, content, category, created_at
        from notes
        order by id"""
    )
    rows = cursor.fetchall()
    connection.close()
    if not rows:
        return {"message": "No notes found."}
    return [_row_to_note(row) for row in rows]

def get_notes_by_category(category: str) -> list | dict:
    """
    Return all notes in a specific category.

    Args:
        category: The category to filter by, for example 'database' or 'docker'.

    Returns:
        A list of notes in that category.
    """
    category = _clean_category(category)
    if category is None:
        return {"error": "Please provide a category name."}

    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute('''
        SELECT id, content, category, created_at
        FROM notes
        WHERE category = ?
        ORDER BY id
    ''', (category,))
    rows = cursor.fetchall()
    connection.close()
    if not rows:
        return {"message": f"No notes found in category '{category}'."}
    return [_row_to_note(row) for row in rows]

def delete_note(note_id: int) -> dict:
    """
    Delete a saved note using its ID.

    Args:
        note_id: The numeric ID of the note to delete.

    Returns:
        Information about whether the note was deleted.
    """
    note_id, error = _parse_note_id(note_id)
    if error:
        return error

    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute('''
        DELETE FROM notes WHERE id = ?
    ''', (note_id,))
    connection.commit()
    deleted_count = cursor.rowcount
    connection.close()

    if deleted_count == 0:
        return {"error": f"No note found with ID {note_id}."}

    return {"status": "deleted", "id": note_id}

def delete_all_notes() -> dict:
    """
    Delete every saved note.

    This is a destructive action. The agent asks the user for confirmation
    before this tool runs.

    Returns:
        How many notes were deleted.
    """
    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute("DELETE FROM notes")
    connection.commit()
    deleted_count = cursor.rowcount
    connection.close()
    return {"status": "deleted_all", "deleted_count": deleted_count}

def search_notes(keyword: str) -> list | dict:
    """
    Search for notes containing a specific keyword.

    Args:
        keyword: The keyword to search for in the note content.

    Returns:
        A list of notes containing the keyword.
    """
    keyword = _clean_text(keyword)
    if keyword is None:
        return {"error": "Please provide a keyword to search for."}

    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute('''
        SELECT id, content, category, created_at
        FROM notes
        WHERE content LIKE ?
        ORDER BY id
    ''', (f'%{keyword}%',))
    rows = cursor.fetchall()
    connection.close()
    if not rows:
        return {"message": f"No notes found containing '{keyword}'."}
    return [_row_to_note(row) for row in rows]

def count_note():
    """
    Count the total number of saved notes in the database.

    Returns:
        The total count of saved notes.
    """
    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute('''
        SELECT COUNT(*) FROM notes
    ''')
    count = cursor.fetchone()[0]
    connection.close()
    return count

def update_note(note_id, new_content):
    """
    Update the content of a saved note using its ID.

    Args:
        note_id: The numeric ID of the note to update.
        new_content: The new content to replace the existing note content.

    Returns:
        Information about whether the note was updated.
    """
    note_id, error = _parse_note_id(note_id)
    if error:
        return error
    new_content = _clean_text(new_content)
    if new_content is None:
        return {"error": "The new note content cannot be empty."}

    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute('''
        UPDATE notes
        SET content = ?
        WHERE id = ?
    ''', (new_content, note_id))
    connection.commit()
    updated_count = cursor.rowcount
    connection.close()

    if updated_count == 0:
        return {"error": f"No note found with ID {note_id}."}

    return {"status": "updated", "id": note_id, "content": new_content}
