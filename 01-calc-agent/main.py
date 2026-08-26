from ollama import chat


response = chat(
    model="qwen3.5:9b",
    messages=[
        {
            "role": "user", 
            "content": "What is an AI agent? Answer in one sentence."
        }
    ]
)

print(response.message.content)