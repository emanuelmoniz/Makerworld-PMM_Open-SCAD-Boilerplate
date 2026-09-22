# renders/: preview images

Output of `scripts\render.bat` (configured in `scripts/render_config.sh`):
`parts/<part>_<PERSPECTIVE>_<RATIO>.png` and `assembly/<file>_<PERSPECTIVE>_<RATIO>.png`.

Tracked, because these are listing images. Regenerate them when the geometry they show changes,
and delete stale ones. Renders are manual: agents only render when asked.
