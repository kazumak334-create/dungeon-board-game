import os
from pathlib import Path
from google import genai
from dotenv import load_dotenv

# .envから読み込み
project_root = Path(__file__).parent.parent.parent
load_dotenv(project_root / ".env")

API_KEY = os.environ.get("GEMINI_API_KEY")
if not API_KEY:
    env_file = project_root / ".env"
    if env_file.exists():
        API_KEY = env_file.read_text(encoding='utf-8').strip().split('\n')[0].strip()

client = genai.Client(api_key=API_KEY)

print("利用可能なモデル:")
print("=" * 60)
for model in client.models.list():
    if "image" in model.name.lower() or "flash" in model.name.lower():
        print(f"- {model.name}")
        if hasattr(model, 'supported_generation_methods'):
            print(f"  Methods: {model.supported_generation_methods}")
