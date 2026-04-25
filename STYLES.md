# Pavement Styles

User-created and imported color/tone presets. Stored at
`~/Library/Application Support/Pavement/styles.json` and surfaced in the
toolbar's `🪄 Style` menu.

## Creating a Style

1. Edit a photo to taste.
2. Toolbar → `🪄 Style` → **Save Current as Style…**.
3. In the sheet:
   - Name + (optional) description.
   - Pick a category (User, B&W, Film, Cinematic, Color, Street).
   - Toggle **Exclude from style** for sections you don't want this
     style to overwrite when applied to other images. By default
     **Crop**, **Lens Correction**, and **White Balance** are excluded —
     they're per-image.
4. Hit **Save**. The style appears in the menu.

When you apply a saved style, every non-excluded operation block is
replaced and the modifiedAt timestamp bumps. Crop and lens correction
survive unless you explicitly include them in the style.

## Importing Lightroom presets (`.xmp`)

Toolbar → `🪄 Style` → **Import Lightroom XMP…**

Pavement parses Adobe Camera RAW fields off the `<rdf:Description>`
attributes and maps them to the closest recipe operation:

| Lightroom field | Pavement field | Notes |
|---|---|---|
| `Exposure2012` | `exposure.ev` | `+1.0` → +1.0 EV |
| `Contrast2012` / `Highlights2012` / `Shadows2012` / `Whites2012` / `Blacks2012` | `tone.*` | -100..100 |
| `Vibrance` / `Saturation` | `color.vibrance` / `color.saturation` | -100..100 |
| `Temperature` / `Tint` | `whiteBalance.temp` / `whiteBalance.tint` | mode auto-flipped to `custom` |
| `HueAdjustment{Band}` / `SaturationAdjustment{Band}` / `LuminanceAdjustment{Band}` | `hsl.<band>.{h,s,l}` | 8 bands: Red, Orange, Yellow, Green, Aqua, Blue, Purple, Magenta |
| `SplitToningShadowHue` / `SplitToningShadowSaturation` | `colorGrading.shadows.hue` / `.sat` | older split toning |
| `ColorGrade{Shadow,Midtone,Highlight,Global}{Hue,Sat}` | `colorGrading.*` | newer color grading; overrides split toning when present |
| `Sharpness` / `SharpenRadius` / `SharpenDetail` | `detail.sharpAmount` / `.sharpRadius` / `.sharpMasking` | |
| `LuminanceSmoothing` / `ColorNoiseReduction` | `detail.noiseLuma` / `.noiseColor` | |
| `GrainAmount` / `GrainSize` / `GrainFrequency` | `grain.amount` / `.size` / `.roughness` | |
| `PostCropVignette*` | `vignette.*` | |
| `ConvertToGrayscale` | `bw.enabled` | |
| `ToneCurvePV2012` (`<rdf:Seq>` of `<rdf:li>x, y</rdf:li>`) | `toneCurve.rgb` | values normalized from 0–255 to 0–1 |

Imported styles land in the `Lightroom` category. Per-channel curves
(R/G/B), mask data, and spot/healing edits are not currently mapped —
they're either pipeline stages we haven't built or tool features
outside our scope.

## Importing 3D LUTs (`.cube`)

Toolbar → `🪄 Style` → **Import .cube LUT…**

Adobe-standard format: `LUT_3D_SIZE N` header followed by N³ rows of
`r g b` floats. Optional `DOMAIN_MIN` / `DOMAIN_MAX` declarations are
honored (rare in shipped LUTs but supported). Comments (`#`) skipped.

Imported LUTs become styles in the `LUT` category. The cube data rides
on the style's `lut` property and applies as the **final** color step
after all parametric adjustments — same order Lightroom and Capture One
use, so a LUT can ride on top of a Color Balance grade without surprise.

LUT sidecar size: a 33³ cube embeds at ~770KB base64 in the
`<photo>.pavement.json` file. Most photos won't use a LUT; those that
do trade some sidecar bloat for portability (the look travels with the
photo).

## Capture One `.costyle`

Not currently supported. Capture One's style format is undocumented and
varies by version. If a community spec emerges we can map known fields
the same way we do Lightroom XMP. Workaround: open the `.costyle`
contents and translate by hand into a saved style.

## File format

Styles are persisted as a single JSON array. Schema (per-style):

```jsonc
{
  "id": "UUID",
  "name": "Tokyo Noir",
  "category": "User",
  "description": "...",
  "operations": { /* same shape as EditRecipe.operations */ },
  "exclusions": ["crop", "lensCorrection", "whiteBalance"],
  "createdAt": "2026-04-25T12:00:00Z",
  "lut": {                 // optional
    "dimension": 33,
    "data": "<base64-encoded RGBA float bytes>",
    "name": "Tungsten Halo"
  }
}
```

Editing the file by hand is supported — the next launch will pick up
your changes. Atomic writes use `styles.json.tmp` + rename.

## What's not (yet) supported

These are Capture One features the user surfaced; we treated them as
deferred so the foundation stays solid first.

| Feature | Status | Why deferred |
|---|---|---|
| Layers in styles (per-effect opacity) | Deferred | Pavement has no layer system yet. Adding one cleanly is a multi-week project (mask compositing, blend modes, per-layer pipeline). |
| AI subject / background masks | Deferred | Needs a Vision/CoreML segmentation model integrated into the pipeline; standalone effort. |
| People masks (hair / eyes / lips) | Deferred | Same as above plus face landmarks; bigger model surface. |
| Smart Adjustments (face-detected auto WB / exposure) | Deferred | Vision-based face detection is doable on macOS, but tying it cleanly to per-photo Auto would be its own feature. |
| `.costyle` import | Deferred | Closed format; would need community-driven reverse engineering. |
| Style stacking (multiple styles on different layers) | Deferred | Depends on the layer system. |

The AI Companion (see `AI_COMPANION.md`) covers some of the same
ground from a different angle: ask in natural language for a look,
get a recipe back. Smart Adjustments-style behavior could ship as part
of that pipeline.
