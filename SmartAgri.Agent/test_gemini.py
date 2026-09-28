"""Quick diagnostic: verify Gemini API key and model."""
import os, sys
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent / ".env")

api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
model = os.getenv("GEMINI_MODEL", "gemini-3.5-flash-lite")

print(f"API Key: {api_key[:10]}...{api_key[-4:]}" if api_key else "❌ NO API KEY FOUND")
print(f"Model:   {model}")
print()

if not api_key:
    print("❌ Set GEMINI_API_KEY in .env")
    sys.exit(1)

from google import genai
from google.genai import types

client = genai.Client(api_key=api_key)

# Test 1: List available models
print("=" * 50)
print("TEST 1: Available models that support generateContent")
print("=" * 50)
try:
    models = client.models.list()
    flash_models = []
    for m in models:
        name = m.name if hasattr(m, 'name') else str(m)
        if 'flash' in name.lower() or 'lite' in name.lower():
            flash_models.append(name)
    for m in sorted(flash_models):
        print(f"  ✅ {m}")
    if not flash_models:
        print("  (no flash/lite models found, showing all)")
        models = client.models.list()
        for m in models:
            name = m.name if hasattr(m, 'name') else str(m)
            print(f"  - {name}")
except Exception as e:
    print(f"  ❌ Error listing models: {e}")

# Test 2: Simple generate with configured model
print()
print("=" * 50)
print(f"TEST 2: Simple generate with model '{model}'")
print("=" * 50)
try:
    response = client.models.generate_content(
        model=model,
        contents="Say hello in JSON format: {\"greeting\": \"...\"}",
        config=types.GenerateContentConfig(
            temperature=0,
            max_output_tokens=100,
            response_mime_type="application/json",
        ),
    )
    print(f"  ✅ Response: {response.text[:200]}")
except Exception as e:
    code = getattr(e, 'code', None)
    msg = getattr(e, 'message', None) or str(e)
    print(f"  ❌ Error (code={code}): {msg[:300]}")

# Test 3: Structured output with JSON schema (like CatalogAgent uses)
print()
print("=" * 50)
print(f"TEST 3: Structured output with response_json_schema")
print("=" * 50)
try:
    schema = {
        "type": "object",
        "properties": {
            "goal": {"type": "string"},
            "items": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "product_id": {"type": "integer"},
                        "quantity": {"type": "integer"},
                    },
                    "required": ["product_id", "quantity"],
                },
            },
        },
        "required": ["goal", "items"],
    }
    response = client.models.generate_content(
        model=model,
        contents='Pick 2 items from: id=1 Apple, id=2 Orange. Return JSON.',
        config=types.GenerateContentConfig(
            temperature=0,
            max_output_tokens=500,
            response_mime_type="application/json",
            response_json_schema=schema,
        ),
    )
    print(f"  ✅ Structured response: {response.text[:300]}")
except Exception as e:
    code = getattr(e, 'code', None)
    msg = getattr(e, 'message', None) or str(e)
    print(f"  ❌ Error (code={code}): {msg[:300]}")

    # Try without response_json_schema
    print()
    print("  Retrying WITHOUT response_json_schema...")
    try:
        response = client.models.generate_content(
            model=model,
            contents='Pick 2 items from: id=1 Apple, id=2 Orange. Return JSON with {"goal": "...", "items": [...]}',
            config=types.GenerateContentConfig(
                temperature=0,
                max_output_tokens=500,
                response_mime_type="application/json",
            ),
        )
        print(f"  ✅ Without schema: {response.text[:300]}")
        print(f"  ⚠️  Model does NOT support response_json_schema — that's the 400 error cause!")
    except Exception as e2:
        print(f"  ❌ Also failed: {e2}")

client.close()
print()
print("=" * 50)
print("DONE")
