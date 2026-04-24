"""git apply --check でパッチを事前検証"""
import subprocess
import tempfile
import sys
import os


def validate_patch(patch_text: str) -> tuple:
    with tempfile.NamedTemporaryFile(mode="w", suffix=".patch", delete=False, encoding="utf-8") as f:
        f.write(patch_text)
        tmp_path = f.name

    try:
        result = subprocess.run(
            ["git", "apply", "--check", tmp_path],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            return True, "パッチ適用可能"
        else:
            return False, result.stderr.strip()
    finally:
        os.unlink(tmp_path)


if __name__ == "__main__":
    patch = sys.stdin.read()
    ok, msg = validate_patch(patch)
    print("✅ OK" if ok else "❌ NG", msg)
    sys.exit(0 if ok else 1)
