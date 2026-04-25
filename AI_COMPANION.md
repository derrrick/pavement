# Pavement AI Companion — Design Doc

A natural-language editor that translates "warm Tokyo night vibe with slight grain" into a validated `EditRecipe`. Single-user personal app on macOS; Anthropic Claude Sonnet 4.6 via the Anthropic API. Phase 5 of the build plan.

---

## 1. Goals & Non-goals

### Goals
- Ask in plain English ("crush the blacks, lift shadows warm, cinematic teal/orange") and get a recipe that produces that look.
- Drop in 1–3 reference JPEGs as visual anchors alongside the prompt — the AI reads them as aesthetic targets.
- Round-trip: AI proposes recipe → user previews on the live canvas → accepts / tweaks / undoes.
- Operates exclusively on the current image (or batch). Never silently rewrites another file.

### Non-goals
- No multi-turn conversational memory beyond the current edit session. Each prompt is a fresh request seeded with the image + (optional) the current recipe state.
- No AI auto-tagging, face detection, subject recognition. We're not an organizing tool.
- No on-device model. Apple's MLX will get there but Sonnet's quality and the lack of latency-critical path makes the API the right call now.
- No background "ambient" AI suggestions. The user explicitly invokes it.

---

## 2. UX

### Where it lives
A new collapsible **AI Companion** section at the top of the editor side panel (above Presets). Always visible. Three controls:

```
┌──────────────────────────────────────┐
│  ▼  AI Companion  •                  │
├──────────────────────────────────────┤
│  ┌────────────────────────────────┐  │
│  │ moody Tokyo night, neon reds,  │  │
│  │ slight grain, deep shadows     │  │
│  └────────────────────────────────┘  │
│                                       │
│  [+ Reference] [drop zone — 0/3]    │
│                                       │
│  Intensity ─────●────  85%           │
│                                       │
│  ┌──────────────┐  ┌──────────────┐ │
│  │   Generate   │  │     Undo     │ │
│  └──────────────┘  └──────────────┘ │
│                                       │
│  Last: "moody Tokyo night..."        │
│  Cost: $0.012  Latency: 2.4s         │
└──────────────────────────────────────┘
```

- **Prompt textbox**: multi-line, persists across sessions (most-recent-prompts dropdown).
- **Reference drop zone**: drag/drop up to 3 JPEGs. Shown as horizontal thumbnail row. Each can be removed with an X.
- **Intensity slider** (0–100%): scales the AI-proposed deltas before applying. Default 85% — most responses tend to overcook; this gives the user a fader.
- **Generate** button: kicks off the API call. Disabled while in flight.
- **Undo** button: reverts to the recipe state before the last AI apply. Single-step undo specific to AI; the broader recipe history is its own concern.
- **Status line**: cost + latency of the last call (transparent to the user; helps with mental model).

### Interaction flow
1. User types a prompt and (optionally) drops references.
2. Hits Generate. Spinner replaces the button label.
3. Sonnet returns a recipe. We validate, clamp, scale by intensity.
4. The canvas updates with the new recipe applied.
5. The previous recipe is captured into a single-slot AI undo buffer.
6. User can:
   - Accept implicitly (do nothing)
   - Click Undo
   - Tweak any panel slider — the AI-proposed values are now the baseline, and manual adjustments take it from there
   - Refine the prompt and Generate again (fresh request, not multi-turn)

### Discoverability
- Tooltip on the prompt field shows 4 example prompts the user can click to populate.
- After 5 successful generations, surface a one-time tip: "Press ⌘⏎ to generate."

---

## 3. The system prompt

The single biggest determinant of output quality. Treated as code: lives in a versioned file, has unit tests against golden inputs, evolves over time.

**Length**: ~2.5–3K tokens. **Caching**: on every request via Anthropic's prompt caching (5min TTL is fine — typical sessions burst).

### Section layout

```
[1] Role (3 sentences)
    "You are Pavement's editing co-pilot. Given a user's prompt and
    optional reference image(s), output exactly one EditRecipe JSON
    that produces the requested look on a photo. You think in terms
    of light, contrast, color cast, and grain."

[2] Schema reference (~800 tokens)
    Compressed version of EditRecipe schema with field names, ranges,
    units, and one-line semantics per field. Auto-generated from
    Operations.swift to stay in sync.

[3] Photographic vocabulary glossary (~600 tokens)
    Maps subjective terms to parameter combinations:
      "moody"        → -contrast, -10..-25 saturation, lifted shadows w/ blue tint
      "filmic"       → +grain, slight S-curve, mild warm shadow tint
      "punchy"       → +contrast, +vibrance, slight whites lift
      "teal-orange"  → colorGrading shadows.hue ~200, highlights.hue ~30
      "airy"         → -contrast, lifted blacks, slight blue tint, +exposure
      "crushed"      → blacks ≤ -30, contrast +20..+40
      "ethereal"     → -contrast, lifted shadows + highlights, low saturation
      "high-key"     → +exposure, +shadows, -contrast, +whites
      "low-key"      → -exposure, -shadows, +contrast, -blacks
      ... (~30 entries)

[4] Hard rules (~200 tokens)
    - Always emit valid JSON conforming to the schema.
    - Numeric ranges are HARD limits. -100..100, etc.
    - Avoid contradictions: don't set bw.enabled=true alongside saturation > 0.
    - Default to subtle. The user has an intensity slider that scales
      everything; over-cooking forces them to dial back.
    - Don't touch crop or lensCorrection unless the user explicitly says.
    - When references are present, treat them as aesthetic targets, not
      literal scene matches.

[5] Worked examples (~1000 tokens)
    6–10 (prompt, [optional reference traits], expected_recipe) triples
    covering: portraits, landscapes, B&W, night/neon, faded film,
    high-key fashion, moody street, golden hour. Each example is a
    completed and reasonable EditRecipe, not just a sketch.
```

The vocabulary glossary and examples are where the personality of the editor lives. We iterate on them like prompt engineering — a/b test against a fixed set of golden test images and ratings. Every change to the vocab is a small commit.

---

## 4. API integration

### Output mode: structured tool call
Use `tool_choice: { "type": "tool", "name": "emit_recipe" }` with the EditRecipe JSON schema as the tool's `input_schema`. This:

- Guarantees Anthropic returns structured output that conforms to the schema.
- Cleanly separates the AI's prose explanation from the recipe payload.
- Is what SwiftAnthropic exposes natively.

We never act on free-text completions; only on the tool call's input dict.

### Reference image handling
Pass images as `image` content blocks alongside the user's prompt. Apply two preprocessing steps before sending:

1. **Downsample to 1024px long edge** — Anthropic accepts up to 8000×8000 but we don't gain anything above 1024 for "vibe matching" and cost scales with pixel count.
2. **Inject Stage-1 Match Look statistics as a sidecar text block**. The model uses our pre-computed Lab moments to anchor its proposal: "the reference has L mean 42, chroma 28, shadow centroid (a=−12, b=−18)." Reduces hallucination.

### Flow
```
Swift                              Anthropic API
─────                              ─────────────

Compose:
  - Cached system prompt (~3K)
  - User prompt text                 ──▶
  - Optional N×image content blocks
  - Optional ref-stats text block
  - Current recipe as JSON context

Stream off (non-streaming).         ◀──  Tool call with EditRecipe input

Validate (Codable + Clamping).
Scale by intensity slider.
Apply to PavementDocument.recipe.
```

### Cost expectations
With prompt caching active (cache write once, then 90% discount on hits):

- **Cached read** (system prompt): ~0.3¢
- **User input** (prompt + small image + stats): ~0.5¢
- **Output** (recipe JSON): ~0.4¢
- **Total per call**: ~1.0–1.5¢

Without caching: ~3–5×, so the cache is worth getting right. Budget: a 30-edit session with AI on every 3rd photo runs ~10–15¢. Annual usage at "typical hobby" volumes is well under $100.

### Streaming
Non-streaming. The recipe is small (~1KB) and only useful when complete and validated; partial JSON would render half-applied edits and flicker the canvas. Show a spinner; total latency 2–4s feels fine for a creative action.

### Daily spend cap
A simple counter in `~/Library/Application Support/Pavement/`. Default cap: $5/day. When exceeded, the Generate button shows "Daily cap reached" with a setting to bump it. Prevents prompt-iteration runaway during system prompt tuning.

---

## 5. Validation & failure modes

The model's output is decoded into `Operations` via the existing custom Codable, then run through `Clamping.clampInPlace` (already in PavementCore). After that it's safe to apply.

| Failure | Handling |
| --- | --- |
| Out-of-range numbers | Clamp silently; log the original value. |
| Contradictory adjustments (bw + saturation>0) | Allow — photographers do this on purpose. |
| Unknown / hallucinated fields | The AnyCodingKey + JSONValue path on EditRecipe preserves them as `unknownKeys`. Log a warning. |
| Schema decode failure | Retry once with the validation error text appended to the user prompt. After second failure: surface "Couldn't parse AI response — try a different prompt." |
| Touched crop / lensCorrection | Strip those fields back to current values before applying. |
| Empty / nonsensical recipe | If `Operations() == decoded`, show "AI declined — try a more specific prompt." |
| Network error / API down | The app stays fully functional for manual editing. The Generate button shows "AI unavailable." |
| Cost cap hit | Block with friendly message + setting link. |

The "intensity" slider is the user's safety net. Most overcooked recipes look fine at 60–80%.

---

## 6. Privacy & key storage

- API key lives in macOS Keychain only. Never in plaintext on disk.
- First-run flow: a Settings sheet prompts the user to paste an Anthropic key. If they skip, the AI panel shows "Set API key in Settings to enable." Manual editing is unaffected.
- Outbound traffic: only to `api.anthropic.com`. We don't telemetry, don't analytics, don't crash-report — same posture as the rest of the app.
- AI history: every prompt + cost + recipe written to `<photo-folder>/_pavement/ai_history.jsonl` for the user's reference. Never uploaded.

---

## 7. Implementation phases

The companion is Phase 5 of the build plan; once landed it's the hero feature.

### 5.1 — Schema + plumbing (1 weekend)
- Add `SwiftAnthropic` (or a slim hand-written client — only one endpoint needed) as a Package.swift dependency.
- Wire Keychain key storage + Settings sheet.
- Define the `emit_recipe` tool schema exported as JSON.
- Stub `AICompanion.generate(prompt:references:current:) async throws -> Operations`.
- Unit test the tool-schema generator against the actual `Operations` Codable shape (round-trips a sample dict).

### 5.2 — System prompt v1 (1 weekend)
- Write the system prompt sections (role, schema, vocabulary, examples).
- Build a CLI command `pavement-cli ai-prompt-test <prompt>` that runs against 5 fixed test images and dumps the resulting recipes — no UI needed yet.
- Iterate vocabulary + examples until 5/5 of the test prompts produce sensible recipes.

### 5.3 — UI integration (1 weekend)
- AICompanionPanel SwiftUI view (prompt textbox, reference drop zone, intensity, generate).
- Single-step AI undo buffer in PavementDocument.
- Cost + latency display.
- Daily-cap enforcement.

### 5.4 — Polish (ongoing)
- "Refine selection": after applying, user can tweak any slider; clicking Generate again sends the new state as `current_recipe` so the AI builds on the user's adjustments.
- Reference cycling: keyboard shortcut to A/B between reference and result.
- Save AI-generated recipes as user presets (under "User" category in PresetsPanel).
- Multimodal review: AI evaluates its own output (second pass) to flag obvious overcook ("this looks heavily B&W; was that intended?").

---

## 8. Open questions

1. **Should the AI see the current recipe?** Pro: context-aware refinements. Con: may be overly conservative (won't propose dramatic changes). **Lean: yes, include current recipe as JSON in the user message, with a note that the AI can either build on or reset it depending on the prompt.**

2. **Per-image or per-batch?** A "moody Tokyo" prompt across 8 batched photos should produce slightly different recipes per photo (each scene's stats inform its match). Either send 8 parallel requests or one batched request that returns 8 recipes. Anthropic's batch API doesn't support tool use as of writing. **Lean: 8 parallel requests, gated by daily cap, with a single combined progress bar.**

3. **Allow the AI to explain its choices?** Sonnet would happily emit a `rationale` string alongside the recipe (already a field in the schema's `ai` block). Worth surfacing in the panel as a collapsible "AI's reasoning" toggle. **Yes, free signal, near-zero token cost.**

4. **What about videos / live previews?** Out of scope for v1 — we're a photo editor. But the recipe schema is video-friendly already; future LUMA-style work could ride on top.

5. **Local fallback?** When MLX or similar gets a vision-capable model that's good enough, swap in a local pipeline behind the same API surface. The companion code shouldn't care about the provider. **Design the AICompanion module behind a `protocol Generator` so swapping is one-line.**

---

## 9. What I'd build first (if I had a weekend)

1. The tool-schema generator (4 hours): Operations.swift introspection + JSON output.
2. The system prompt v1 (8 hours): role + schema + 30 vocab entries + 6 examples.
3. The CLI test harness (4 hours): one Swift file, runs 5 fixed prompts against the API, prints the recipes side-by-side.
4. Manual evaluation: do the recipes look right when applied? Iterate prompt for 2–3 hours.

That gets us to "the AI works in principle" before any UI is written. UI is straightforward once the model behaves.
