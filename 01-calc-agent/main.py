from agent import run_agent
from config import MODEL, SYSTEM_PROMPT
from ollama_setup import ensure_ollama


def main():
    ensure_ollama(MODEL)
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]

    print("=================================")
    print("        CALCULATOR AGENT")
    print("=================================")
    print("Type 'exit' or 'quit' to stop.")

    while True:
        user_input = input("\nYou: ").strip()
        if user_input.lower() in ["exit", "quit"]:
            print("Agent: Goodbye!")
            break
        if not user_input:
            continue

        messages.append({"role": "user", "content": user_input})
        print(f"\nAgent: {run_agent(messages)}")


if __name__ == "__main__":
    main()
