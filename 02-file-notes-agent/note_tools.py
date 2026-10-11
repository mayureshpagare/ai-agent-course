from database import get_connection

def save_note(content):
    """Save a note to the database."""
    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute('''
        INSERT INTO notes (content) VALUES (?)
    ''', (content,))
    connection.commit()
    note_id = cursor.lastrowid
    connection.close()
    return f"Note saved with ID: {note_id}"

def list_notes():
    """Return all saved notes from the database.
    Returns:
        A formatted list of saved notes.
    """
    connection = get_connection()
    cursor = connection.cursor()
    
    cursor.execute("""select id,  content, created_at
        from notes
        order by id"""
    
    )
    rows = cursor.fetchall()
    connection.close()
    if not rows:
        return "No notes found."
    notes = []
    for note_id,  content, created_at in rows:
        notes.append(
            f"{note_id}: {content} (Created at: {created_at})"
        )
    return "\n".join(notes)

def delete_note(note_id):
    """
    Delete a saved note using its ID.

    Args:
        note_id: The numeric ID of the note to delete.

    Returns:
        Information about whether the note was deleted.
    """
    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute('''
        DELETE FROM notes WHERE id = ?
    ''', (note_id,))
    connection.commit()
    deleted_count = cursor.rowcount
    
    connection.close()

    if deleted_count == 0:
        connection.close()
        return f"No note found with ID {note_id}."

    return f"Note with ID {note_id} deleted."

def search_notes(keyword):
    """
    Search for notes containing a specific keyword.

    Args:
        keyword: The keyword to search for in the note content.

    Returns:
        A formatted list of notes containing the keyword.
    """
    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute('''
        SELECT id, content, created_at
        FROM notes
        WHERE content LIKE ?
        ORDER BY id
    ''', (f'%{keyword}%',))
    rows = cursor.fetchall()
    connection.close()
    if not rows:
        return f"No notes found containing '{keyword}'."
    notes = []
    for note_id, content, created_at in rows:
        notes.append(
            f"{note_id}: {content} (Created at: {created_at})"
        )
    return "\n".join(notes)

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
        return f"No note found with ID {note_id}."

    return f"Note with ID {note_id} updated."