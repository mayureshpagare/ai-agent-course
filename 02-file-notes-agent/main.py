from agent import run_agent
from config import MODEL, SYSTEM_PROMPT
from database import initialize_database
from ollama_setup import ensure_ollama

def main():
    ensure_ollama(MODEL)
    initialize_database()  # Ensure the database is initialized before starting the agent 
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
    ]

    print(
        "================================="
    )

    print(
        "      FILE & NOTES AI AGENT"
    )

    print(
        "================================="
    )

    print(
        "Type 'exit' or 'quit' to stop."
    )

    while True:
        user_input = input("You: ")

        if user_input.lower() in ["exit", "quit"]:
            print("Exiting the agent. Goodbye!")
            break
        messages.append({"role": "user", "content": user_input})

        answer = run_agent(messages)
        print(f"Agent: {answer}")

if __name__ == "__main__":
    main()

