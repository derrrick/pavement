# Pavement — Build Plan

A personal Mac-native RAW editor for street photography. Solo build, single user, single Mac.
Cameras targeted: Fujifilm X-E4 (26MP X-Trans IV) and Canon R5 (45MP Bayer, CR3).

---

## 1. Goals and Non-Goals

### Goals
- Replace Lightroom + Capture One for the user's personal street photography workflow.
- Native macOS app, fast on Apple Silicon, feels like Preview not like a web tool.
- Non-destructive editing with JSON sidecars next to source RAWs.
- First-class **batch consistency editing** for sets of 4–30 photos.
- AI-driven style application: drop in reference image(s) + a constraints prompt; Claude analyzes the set and outputs structured per-image edit recipes that produce a consistent look.
- Export to JPEG/TIFF with output sharpening and resize for Instagram, web, and print.

### Non-Goals
- No Photoshop replacement: no layers, no clone stamp beyond simple dust heal, no compositing, no text, no shapes.
- No catalog database. Folders on disk are the source of truth.
- No cross-platform. Mac only.
- No commercial distribution. No license server, no analytics, no crash reporting, no App Store.
- No tethering, no DAM, no facial recognition, no print module.
- No GPL code shipped if this ever changes commercial intent. (Currently personal, so GPL is fine for ports/study.)

---

## 2. Tech Stack (Locked)

| Layer | Choice | Why |
|---|---|---|
| Language | Swift 5.10+ | Native, modern, AI-assisted dev is excellent in 2026 |
| UI | SwiftUI (with AppKit bridges where needed) | Declarative, hot-reload via Xcode previews, fine for this scale |
| GPU pipeline | Core Image + Metal (custom kernels via MetalPetal where needed) | Free RAW decode, ICC color management, ~200 filters out of the box |
| RAW decode (v1) | `CIRAWFilter` | Free, handles X-Trans IV and CR3 |
| RAW decode (v2 fallback) | LibRaw via Obj-C++ shim, optional | Only if X-Trans rendering quality forces it |
| AI | SwiftAnthropic + Claude Sonnet 4.6 (vision) | Community SDK, structured outputs, multimodal |
| Sidecars | Custom JSON (`.pavement.json`), one per source file | Simple, debuggable, versioned |
| Export | ImageIO (JPEG/HEIC), libtiff (TIFF 16-bit) — libtiff added when TIFF is needed | Native is enough for v1 |
| Build | Xcode + SwiftPM, no CocoaPods | Single-developer simplicity |
| Min macOS | 14.0 (Sonoma) | SwiftUI feature parity, Metal 3 |

### Deferred Dependencies (add only when feature requires)
- `MetalPetal` — when custom GPU shaders for grain/vignette need explicit graph control
- `OpenCV` (xcframework) — when dust-heal feature ships
- `Lensfun` — when lens correction beyond EXIF-embedded data is needed
- `LibRaw` — only if Apple's X-Trans output disappoints in real testing
- `mozjpeg` — only if Instagram export size becomes a real concern

---

## 3. Architecture Overview

### High-level data flow

```
RAW file on disk
  -> Catalog (in-memory folder watcher)
  -> Document (one per RAW, lazy)
  -> EditRecipe (in-memory + JSON sidecar)
  -> PixelPipeline (Core Image graph, GPU)
  -> Preview (1:1 or fit-to-view, debounced)
  -> Export Renderer (full-res, off main thread)
```

### Module boundaries

```
Pavement (app target)
├── PavementCore (SwiftPM module)
│   ├── Catalog/         — folder scan, RAW detection, EXIF
│   ├── Document/        — Document model, sidecar IO
│   ├── EditRecipe/      — recipe schema, codable, validation
│   ├── Pipeline/        — pixel pipeline, Core Image graph builder
│   ├── Filters/         — Pavement-specific CIFilter wrappers
│   ├── Export/          — JPEG/TIFF writer, output sharpening, resize
│   └── AI/              — Claude integration, prompt assembly, recipe parser
└── PavementUI (app target main)
    ├── Browser/         — contact sheet, multi-select, keyboard nav
    ├── Editor/          — sliders, curves, HSL, color grading wheels
    ├── BatchPanel/      — batch edit + AI prompt UI
    └── HistogramView/   — Metal-rendered scopes
```

Splitting Core from UI early means the pipeline is testable in isolation and the AI module can be exercised from a CLI tool for prompt iteration.

---

## 4. The Pixel Pipeline (Order of Operations)

Order matters in color science. Pavement uses a fixed pipeline with optional per-stage bypass:

1. **RAW decode** — `CIRAWFilter` produces linear scene-referred RGB in working color space (Display P3 working internally; Rec.2020 only if a future need arises).
2. **Lens correction** — geometric distortion, CA, vignette compensation. Auto from EXIF profile when present; manual override possible.
3. **White balance** — temperature and tint applied as channel multipliers in linear space.
4. **Highlight reconstruction** — when highlights are clipped, attempt recovery from non-clipped channels. (Apple's `CIRAWFilter` already does some of this; we expose strength.)
5. **Exposure** — single linear gain in stops.
6. **Tone controls** — contrast, highlights, shadows, whites, blacks. Applied as a parametric curve in linear-to-tonal mapped space.
7. **Tone curve** — user-drawn RGB curve and per-channel R/G/B curves.
8. **HSL** — hue/saturation/luminance per color band (red, orange, yellow, green, aqua, blue, purple, magenta).
9. **Color grading** — three-wheel shadows/midtones/highlights with blending and balance, plus optional global wheel.
10. **B&W conversion (optional)** — if engaged, replaces step 8/9 effect on saturation; channel mixer determines luminance contribution per color.
11. **Detail** — sharpening (radius + amount + masking) and noise reduction (luma + chroma).
12. **Effects** — grain, then vignette. Both output-referred, applied after tonal mapping.
13. **Crop and rotate** — cosmetic, last in viewing pipeline.
14. **Output transform** — color space convert + gamma encode for export only.
15. **Resize** — Lanczos for downscale, with output sharpening tuned to target resolution.

The pipeline runs on a `CIContext` backed by Metal. Each stage is a `CIFilter` (built-in or custom kernel via `CIKernel`). Cropping is non-destructive and stored as normalized coordinates so resizing the source never invalidates the recipe.

---

## 5. Edit Recipe Schema (the core data model)

This is what gets persisted as a JSON sidecar, what the AI returns, and what the pipeline consumes. Every field has a **type, range, default, and units** so Claude can be constrained to valid values via JSON schema.

```jsonc
{
  "schemaVersion": 1,
  "source": {
    "path": "DSCF1234.RAF",
    "fingerprint": "sha256:abcd1234...",
    "camera": "Fujifilm X-E4",
    "lens": "XF 23mm F2 R WR",
    "iso": 800,
    "captureTime": "2026-04-15T18:42:11Z"
  },
  "createdAt": "2026-04-25T12:00:00Z",
  "modifiedAt": "2026-04-25T12:00:00Z",
  "operations": {
    "crop": {
      "enabled": true,
      "x": 0.0, "y": 0.0, "w": 1.0, "h": 1.0,   // normalized to source
      "rotation": 0.0,                             // degrees, -45 to 45
      "aspect": "free"                             // free | 1:1 | 3:2 | 4:5 | 16:9
    },
    "lensCorrection": {
      "enabled": true,
      "auto": true,
      "distortion": 1.0,                           // 0..1 strength multiplier
      "ca": 1.0,
      "vignette": 1.0
    },
    "whiteBalance": {
      "mode": "custom",                            // asShot | auto | custom
      "temp": 5500,                                // Kelvin, 2000..50000
      "tint": 0                                    // -150..150
    },
    "exposure": { "ev": 0.0 },                     // -5..5 stops
    "tone": {
      "contrast":   0,                              // -100..100
      "highlights": 0,
      "shadows":    0,
      "whites":     0,
      "blacks":     0,
      "highlightRecovery": 0                        // 0..100
    },
    "toneCurve": {
      "rgb": [[0,0],[1,1]],                        // 2..16 control points, x,y in 0..1
      "r":   [[0,0],[1,1]],
      "g":   [[0,0],[1,1]],
      "b":   [[0,0],[1,1]]
    },
    "hsl": {
      "red":     {"h": 0, "s": 0, "l": 0},          // each -100..100
      "orange":  {"h": 0, "s": 0, "l": 0},
      "yellow":  {"h": 0, "s": 0, "l": 0},
      "green":   {"h": 0, "s": 0, "l": 0},
      "aqua":    {"h": 0, "s": 0, "l": 0},
      "blue":    {"h": 0, "s": 0, "l": 0},
      "purple":  {"h": 0, "s": 0, "l": 0},
      "magenta": {"h": 0, "s": 0, "l": 0}
    },
    "colorGrading": {
      "shadows":    {"hue": 0, "sat": 0, "lum": 0}, // hue 0..360, sat/lum -100..100
      "midtones":   {"hue": 0, "sat": 0, "lum": 0},
      "highlights": {"hue": 0, "sat": 0, "lum": 0},
      "global":     {"hue": 0, "sat": 0, "lum": 0},
      "blending":   50,                             // 0..100
      "balance":    0                               // -100..100
    },
    "bw": {
      "enabled": false,
      "mix": { "red": 0, "orange": 0, "yellow": 0, "green": 0, "aqua": 0, "blue": 0, "purple": 0, "magenta": 0 }
    },
    "detail": {
      "sharpAmount":  30,                           // 0..150
      "sharpRadius":  1.0,                          // 0.5..3.0
      "sharpMasking": 0,                            // 0..100
      "noiseLuma":    0,
      "noiseColor":   25
    },
    "grain": {
      "amount":     0,                              // 0..100
      "size":       25,                             // 0..100
      "roughness":  50                              // 0..100
    },
    "vignette": {
      "amount":    0,                               // -100..100
      "midpoint":  50,                              // 0..100
      "feather":   50,
      "roundness": 0                                // -100..100
    }
  },
  "ai": {
    "lastPrompt": "chiaroscuro, deep shadows, warm midtones, slight grain",
    "lastReferenceFingerprints": ["sha256:..."],
    "lastModel": "claude-sonnet-4-6",
    "lastInvokedAt": "2026-04-25T12:01:00Z",
    "rationale": "..."                              // Claude's free-text explanation
  }
}
```

Schema is versioned. Migrations are explicit Swift functions per `(fromVersion, toVersion)`. Any unknown keys are preserved on round-trip so future schema additions don't lose data on older builds.

---

## 6. AI Integration Design

### Workflow
1. User selects N photos (4–30) in the browser.
2. User optionally drags 1–3 reference images into the AI panel.
3. User writes a short constraints prompt: *"chiaroscuro, deep shadows, warm midtones, slight grain, no crushed blacks below 5/255."* Saved presets dropdown for the user's recurring styles.
4. Pavement assembles a multimodal Claude request:
   - System prompt: a long, fixed prompt that defines the JSON schema, rules, and the user's aesthetic vocabulary.
   - User content: each source photo as a downsampled JPEG (1024px long edge, 80% quality), each reference as same, plus the prompt and the set context ("these N photos are a series, edit them as one body of work").
   - Tool/structured-output: enforce the EditRecipe JSON schema so Claude returns one recipe per source photo.
5. Claude returns an array of recipes plus a free-text rationale.
6. Pavement validates the JSON against the schema, clamps any out-of-range values, attaches recipes to the documents, and renders previews.
7. User reviews. Tweaks one image. Hits "propagate intent." Pavement sends a second-pass request: *"the user adjusted these specific values on this image; rebalance the others to maintain consistency under the original style."*

### Prompt scaffolding strategy
The system prompt is a separate file, version-controlled, treated as code. It contains:
- Schema reminder (subset of the JSON spec, with units and ranges).
- Editing guidelines ("use exposure for brightness, not curves; never crush blacks below 3/255 unless prompt specifies; warm tints go to highlights via color grading, not white balance shift").
- Style vocabulary glossary ("chiaroscuro = +contrast 30-50, -shadows 30-50, -blacks 10-20, vignette amount -15 to -30").
- Examples (few-shot): two or three (image, prompt, expected recipe) triples to anchor outputs.

This is the actual product. The Swift code is pipe and plumbing. The system prompt is where the personality of the editor lives. Iterate on it like code.

### Cost and latency
- Sonnet 4.6 with 4 input images + 3 references + ~3k token system prompt: roughly $0.04–0.08 per request.
- Latency: 5–15s for a batch of 4 with vision. Acceptable for batch editing; not used in interactive sliders.
- Caching: reuse system prompt via prompt caching to cut cost ~80% on repeated invocations.

### Failure modes
- Claude returns malformed JSON → schema validator clamps, logs, retries once.
- Claude proposes edits that look bad → user manually overrides, no rollback needed because edits are non-destructive.
- API down → app stays fully functional for manual editing.

---

## 7. Camera-Specific Notes

### Fujifilm X-E4
- X-Trans IV CFA. Not Bayer. Apple's `CIRAWFilter` handles it but quality on fine foliage/asphalt detail can be soft or "wormy."
- Plan: ship v1 with Apple's decode. Add a Settings toggle in v2 for "alternate demosaic" that routes through LibRaw with Markesteijn 3-pass.
- Film simulations: X-E4 RAFs have an embedded film sim selection. Apple sometimes applies it; we want to *ignore* it and start from neutral so AI/manual edits aren't double-cooking. Verify experimentally; force `kCIInputDisableGamutMapKey` and check.
- DR400/DR200 expansion: handled in the RAW pipeline by Apple; don't fight it.

### Canon R5
- CR3 format, 45MP, file size 50–60MB. No special demosaicing needed.
- Dual-pixel data: Apple ignores it; we don't need it.
- Lens correction profiles often embedded in CR3 metadata; honor them by default in step 2 of the pipeline.
- The R5 has a strong, accurate color science out of camera; expect minimal need for white balance correction.

### Performance budget
- X-E4 file (52MB RAF, 6240x4160): full-pipeline 1:1 render < 200ms on M1/M2.
- R5 file (50MB CR3, 8192x5464): full-pipeline 1:1 render < 350ms on M1/M2.
- Slider drag interaction must hit 60fps on a fit-to-view preview: cache the post-RAW-decode CIImage and only re-evaluate downstream filters.

---

## 8. File System Layout

```
~/Pictures/Street/
└── 2026-04-Tokyo/
    ├── DSCF1234.RAF
    ├── DSCF1234.RAF.pavement.json    ← edit recipe sidecar
    ├── DSCF1235.RAF
    ├── DSCF1235.RAF.pavement.json
    ├── _exports/                      ← Pavement-managed exports (auto-created)
    │   ├── instagram/
    │   │   ├── DSCF1234.jpg
    │   │   └── DSCF1235.jpg
    │   └── print/
    │       └── DSCF1234.tif
    └── _pavement/                     ← per-folder caches and AI history
        ├── thumbnails/                ← 512px JPEGs for browser
        ├── ai_history.jsonl           ← every Claude call + response
        └── presets/                   ← saved style prompts
```

User preferences: `~/Library/Application Support/Pavement/preferences.json`.
API keys: macOS Keychain only, never in plaintext on disk.

---

## 9. Phased Build Plan

Each phase is "shippable for personal use" — at the end of every phase, you can edit photos with what's been built.

### Phase 0 — Project setup (1 weekend)
- New Xcode project, SwiftPM modular structure, `PavementCore` and `PavementUI` targets.
- SwiftAnthropic added but not wired.
- CI'd: build runs cleanly, app launches to empty window.

### Phase 1 — Browser (1–2 weekends)
- Folder picker and recursive scan.
- RAW file detection (RAF, CR3, plus DNG/JPG bonus).
- Thumbnail grid (LazyVGrid in SwiftUI).
- Background thumbnail generator using `CIRAWFilter` at 512px.
- Multi-select with shift-click and cmd-click; keyboard navigation.
- 1:1 preview pane with pan/zoom.
- **Outcome:** browse your photos in your own app. No edits yet.

### Phase 2 — Edit pipeline core (3–4 weekends)
- `EditRecipe` Swift model + JSON Codable + sidecar IO.
- Pixel pipeline: white balance, exposure, contrast, highlights, shadows, whites, blacks.
- HSL panel.
- Tone curve (RGB only, per-channel later).
- Live preview with debounced re-render on slider drag.
- Histogram (Metal-rendered).
- **Outcome:** real non-destructive editing. You could stop here and have a usable tool.

### Phase 3 — Crop, rotate, output (1–2 weekends)
- Crop tool with aspect ratios, rotation handle.
- Lens correction toggle (auto from EXIF only — no Lensfun yet).
- JPEG export with quality, resize, and output sharpening.
- TIFF 16-bit export (via `ImageIO`, no libtiff yet).
- Export presets: Instagram (1080×1350, sRGB, 90% JPEG), Web (2048px long, sRGB, 80% JPEG), Print (full size, AdobeRGB or P3, 16-bit TIFF).
- **Outcome:** end-to-end workflow. RAW in, finished export out.

### Phase 4 — Batch editing (1–2 weekends)
- Multi-select edit mode: edits apply to all selected documents.
- Sync settings: copy recipe from one photo to N others (with optional per-section toggles).
- Visual indicator on browser thumbnails for "edited" state.
- **Outcome:** batch consistency, manual mode.

### Phase 5 — AI batch consistency (3–4 weekends)
- AI panel UI: prompt textbox, reference image drop zone, presets dropdown.
- System prompt file + scaffolding.
- Claude integration via SwiftAnthropic with structured outputs (JSON schema).
- Validator + clamper for returned recipes.
- "Apply to selection" and "Propagate intent" buttons.
- AI history log written to `_pavement/ai_history.jsonl`.
- **Outcome:** the actual hero feature. You drop 8 photos + a reference and get a consistent edited series in 15 seconds.

### Phase 6 — Polish (ongoing)
- Color grading wheels.
- Per-channel tone curves.
- Grain (port darktable's `grain.c` or implement Newson stochastic model).
- Vignette.
- Dust spot heal (OpenCV `inpaint()`).
- B&W channel mixer.
- Lens correction with Lensfun database (optional).
- Alternate X-Trans demosaic via LibRaw (optional).
- Quick Look preview generator (so Finder shows your edits).

**Total build time estimate:** 12–16 weekends to feature-complete v1. First usable cut at end of Phase 3 — call it 6–8 weekends.

---

## 10. Risks and Hard Parts

These will bite. Calling them out now:

1. **X-Trans demosaicing quality.** Already discussed. Have a fallback plan: keep the pipeline's first stage swappable.

2. **Live preview latency under heavy filter chains.** Solution: cache post-decode CIImage, render preview at fit-to-view size during interaction, only render 1:1 on idle.

3. **Color management drift between Pavement, Photos, and Instagram.** macOS handles this transparently *if* you tag exports correctly. Always embed sRGB or P3 ICC profile in JPEG output. Test the export on a phone immediately on day one.

4. **Tone curve UI.** Drawing curves with smooth Catmull-Rom or Hermite interpolation, hit-testing control points, adding/removing/dragging — all has to feel right or the tool feels cheap. Budget a full weekend.

5. **AI cost runaway during prompt iteration.** Set a daily spend cap in code. Log every call. Use prompt caching aggressively.

6. **AI returning recipes that look technically valid but produce ugly results.** The system prompt is where this is solved. Plan for 3–5 iterations of the system prompt with golden test images.

7. **Sidecar file conflicts.** If you edit on two machines or move files around, sidecars can desync from sources. Source fingerprint (sha256 of first/last 1MB) detects mismatches.

8. **Crop + rotation interacting with lens correction.** Lens correction must run before crop, always. Locked into pipeline order.

9. **EXIF preservation on export.** Don't lose IPTC, GPS, copyright, lens info. Use `ImageIO` properties dictionaries, not custom writers.

10. **The temptation to keep adding features.** This list is already too long. The discipline is to ship Phases 1–5 *first* and only return to Phase 6 after using the tool for a real shoot.

---

## 11. Decisions Locked

| Decision | Choice |
|---|---|
| Catalog or folders | **Folders.** No DB. |
| Sidecar format | **Custom JSON.** Not XMP, not pp3. |
| RAW decoder v1 | **`CIRAWFilter`.** LibRaw deferred. |
| UI framework | **SwiftUI** with AppKit bridges where needed. |
| Min macOS | **14 (Sonoma).** |
| AI provider | **Claude Sonnet 4.6** via SwiftAnthropic. |
| Output transforms | **sRGB** for web, **Display P3** for print/archive, **16-bit TIFF** option. |
| Color working space | **Display P3** internally. |
| Layers | **No.** |
| Dust heal | **Yes, in Phase 6.** OpenCV inpaint. |
| Lens correction | **EXIF auto in v1, Lensfun later.** |
| Schema versioning | **Yes, day 1.** Migrations as explicit Swift fns. |

---

## 12. Immediate Next Steps

1. Create the Xcode project with the modular structure above.
2. Stub out `EditRecipe.swift` with the full Codable model and unit tests for round-trip JSON serialization.
3. Build a CLI tool (`pavement-cli`) that loads a RAW, applies a hard-coded recipe, and writes a JPEG. Validates the pipeline end-to-end before any UI work.
4. Confirm both X-E4 and R5 RAWs render through `CIRAWFilter` with reasonable quality on real test files.
5. Write the first draft of the AI system prompt and exercise it against 5 of your real street photos with 3 different style prompts.

When those five steps are done you'll know whether this plan survives contact with reality.
