from database import initialize_database
from note_tools import save_note,list_notes,delete_note,search_notes

initialize_database()

# print(delete_note(1))
# print(search_notes("test"))
print(list_notes())
# print(save_note("This is a test note."))