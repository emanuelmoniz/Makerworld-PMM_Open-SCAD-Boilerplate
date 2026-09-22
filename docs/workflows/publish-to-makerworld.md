# Workflow: publish or update on MakerWorld

> **Goal.** Get the bundle into PMM and the listing onto MakerWorld, then verify on the platform
> itself. The local lint approximates PMM. It doesn't replace testing there.

## Pre-flight

- [ ] `scripts\check.bat` passes on the release commit
- [ ] `dist/<slug>_makerworld.scad` is freshly built from that commit
- [ ] `dist/makerworld_listing.md` is updated
- [ ] Every plate fits about 235 × 235 mm (the smoke check measures it)
- [ ] Fonts and libraries pass lint rules P02/P04 against a fresh inventory

## Upload the model

1. Open MakerWorld → your model → **Parametric Model Maker** (or create a new PMM model).
2. Open the code editor (the **Code** button since PMM v1.1.0) and replace the script with the
   full contents of `dist/<slug>_makerworld.scad`.
3. Check **every customizer tab**: labels (the help-text comments), sliders, dropdowns, and color
   and font pickers all appear as expected.
4. Generate with **default** parameters, then with a few **extreme** ones (max and min sizes, every
   dropdown option, every optional feature on). Watch for:
   - timeouts (simplify the geometry, see
     [compatibility-rules.md](../pmm/compatibility-rules.md#timeouts--community))
   - "3MF cannot be generated" (a plate is too big, see
     [P11](../pmm/compatibility-rules.md#p11-plate-size-ceiling--employee))
   - substituted fonts (check text renders in the intended font)
   - the assembly view and each plate look right
5. Download the 3MF once and open it in Bambu Studio.

## Update the listing

- Paste `dist/makerworld_listing.md` into the description.
- Upload images from `renders/` and any curated `printables/` profiles.
- Multi-plate PMM models don't offer STL download. If customers need STLs, attach the default
  ones from `stl/` or publish a separate variant.

## Record what you learned

If PMM behaved differently from the docs (a font that works although the lint flags it, a new
limit), add it to the verification log in [sources.md](../pmm/sources.md) and fix the affected
doc. That keeps this reference accurate.
