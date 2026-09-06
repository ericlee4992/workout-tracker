#!/usr/bin/env python3
"""Scanner accuracy — the LLM-as-plate-reader experiment.

Sends every photo in the corpus to Claude (Sonnet by the user's choice, for
cost) and asks for a structured transcription of the name plate: the brand and
the model name as printed, top of plate first, ignoring instructions, warnings,
serials and ratings. Writes corpus/llm-readings.json, which the harness reads
under TEST_RUNNER_SCANNER_LLM=1 and runs through the app's OWN matcher, so the
result lands next to the Vision baseline on identical photos.

Key: Config/anthropic.key (gitignored) or ANTHROPIC_API_KEY. The key is read by
this script only; nothing else in the repo touches it.
"""
import base64, io, json, os, sys, time
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
CORPUS = REPO / ".scratch/scanner-accuracy/corpus"
OUT = CORPUS / "llm-readings.json"
MODEL = os.environ.get("SCANNER_LLM_MODEL", "claude-sonnet-5")

def api_key():
    if os.environ.get("ANTHROPIC_API_KEY"):
        return os.environ["ANTHROPIC_API_KEY"]
    key_file = REPO / "Config/anthropic.key"
    if key_file.exists():
        return key_file.read_text().strip()
    sys.exit("No key: put one in Config/anthropic.key (gitignored) or export ANTHROPIC_API_KEY.")

def jpeg_b64(path, max_side=1568):
    from PIL import Image
    im = Image.open(path).convert("RGB")
    im.thumbnail((max_side, max_side))
    buf = io.BytesIO(); im.save(buf, "JPEG", quality=88)
    return base64.standard_b64encode(buf.getvalue()).decode()

SCHEMA = {
    "type": "object",
    "properties": {
        "brand": {"type": ["string", "null"], "description": "Manufacturer as printed, or as recognised from its logo; null if none is visible."},
        "brand_from_logo_only": {"type": "boolean", "description": "True when the brand is visible only as a logo, not as printed text."},
        "model": {"type": ["string", "null"], "description": "The machine's model/name as printed on the plate; null if none."},
        "lines": {"type": "array", "items": {"type": "string"}, "description": "The plate's identifying text, top of plate first: brand line, model line, model code if printed. No instructions, warnings, serial numbers, URLs or load ratings."},
        "confidence": {"type": "string", "enum": ["high", "medium", "low"]},
    },
    "required": ["brand", "brand_from_logo_only", "model", "lines", "confidence"],
    "additionalProperties": False,
}

PROMPT = (
    "This is a photo of a gym strength machine's name plate or badge. Transcribe only what "
    "identifies the machine: the manufacturer (brand) and the model or machine name, exactly as "
    "printed. If the brand appears only as a logo you recognise, give the brand name and set "
    "brand_from_logo_only. Ignore usage instructions, warnings, serial numbers, part numbers, "
    "URLs, phone numbers and load ratings. If there is no plate or nothing identifying, return "
    "nulls and an empty list. Do not guess a model that is not printed."
)

def main():
    import anthropic
    # Accept-Encoding: identity — anaconda's brotli 1.0.9 lacks the output_buffer_limit kwarg the
    # SDK's bundled httpx2 passes, so a brotli-compressed response dies with
    # "process() takes no keyword arguments" inside APIConnectionError. Responses are tiny.
    client = anthropic.Anthropic(api_key=api_key(), default_headers={"Accept-Encoding": "identity"})
    manifest = json.loads((CORPUS / "manifest.json").read_text())
    readings = json.loads(OUT.read_text()) if OUT.exists() else {}
    total_in = total_out = 0
    for entry in manifest:
        name = entry["file"]
        if name in readings and not os.environ.get("SCANNER_LLM_REDO"):
            continue
        path = CORPUS / name
        if not path.exists():
            continue
        response = client.messages.create(
            model=MODEL, max_tokens=1024,
            output_config={"effort": "low", "format": {"type": "json_schema", "schema": SCHEMA}},
            messages=[{"role": "user", "content": [
                {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": jpeg_b64(path)}},
                {"type": "text", "text": PROMPT},
            ]}],
        )
        if response.stop_reason == "refusal":
            readings[name] = {"error": "refusal"}; continue
        text = next(b.text for b in response.content if b.type == "text")
        readings[name] = json.loads(text)
        readings[name]["model_id"] = MODEL
        total_in += response.usage.input_tokens; total_out += response.usage.output_tokens
        print(f"{name}: {readings[name].get('brand')} | {readings[name].get('model')} | {readings[name].get('confidence')}")
        OUT.write_text(json.dumps(readings, indent=1, ensure_ascii=False))
        time.sleep(0.3)
    OUT.write_text(json.dumps(readings, indent=1, ensure_ascii=False))
    print(f"done: {len(readings)} readings; tokens in {total_in} out {total_out} -> {OUT}")

if __name__ == "__main__":
    main()
