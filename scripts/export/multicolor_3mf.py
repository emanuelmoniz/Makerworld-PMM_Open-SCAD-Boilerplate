#!/usr/bin/env python3
# ============================================================
# <PROJECT NAME>  |  Multicolor part -> Bambu multi-part object
# ------------------------------------------------------------
# Used by scripts/export/export_3mf.sh for parts flagged `multicolor=1` in
# scripts/plates_config.sh, and for the assembly preview plate when its views
# mark their color regions with assembly_region(). Turns ONE OpenSCAD export
# into ONE Bambu object made of several parts, each assigned its own filament
# slot.
#
# INPUT: what OpenSCAD writes for a part whose BUILD:EXCLUDE block calls its
# color regions as separate top-level children, exported with
#     --enable=lazy-union -O export-3mf/material-type=color
# i.e. one <object> per region -- each a closed solid, at its authored
# coordinates -- plus an <m:colorgroup> the triangles point into.
#
# OUTPUT: a Bambu Studio project holding ONE <object> whose <components> are
# those regions, with `extruder` metadata per <part> in
# Metadata/model_settings.config. That is Bambu's own representation of a
# multi-filament object (what you get by hand with "Add part" + assigning a
# filament), so its CLI arranges it as a single unit and Bambu Studio opens
# it with the color assignment already made.
#
# WHY NOT just hand Bambu the colored 3MF? Two reasons, both tested:
#   - Its color parsing is a GUI dialog. Through the CLI (which is what this
#     pipeline uses) a colored 3MF comes back as ONE part with ONE extruder:
#     every per-triangle color is dropped.
#   - Even in the GUI, Bambu converts standard-3MF colors into Color
#     Painting, i.e. a SURFACE property that bleeds into the interior, not
#     "this volume is filament 2".
# 3MF color is a surface attribute in the first place: in a colored export
# of a body + embossed label, neither color's triangles form a closed
# volume (the union dissolved the interface between them), so the colored
# mesh cannot be split into printable solids after the fact. Keeping the
# regions apart in OpenSCAD -- which is what lazy-union does -- is the only
# way to get real per-volume filament assignment.
#
# Color is therefore carried by the FILAMENT MAP, not by the mesh: every
# color attribute is stripped on the way out (leaving them in would re-arm
# Bambu's color parser and turn a correct per-part assignment back into
# surface painting).
#
# Usage:
#   multicolor_3mf.py IN.3mf OUT.3mf --reference REF.3mf --name <part name>
#       [--map "#RRGGBB=<slot>" ...]
#
# Exits 1 -- loudly, never silently guessing a slot -- when a region mixes
# colors, when a color has no --map entry (the message lists the colors
# actually found, ready to paste into FILAMENT_MAP), or when the map asks
# for a filament REFERENCE_3MF doesn't have. A part that renders as a SINGLE
# region is not an error: parameters legitimately collapse a part to one
# color (the demo's label_style=none), so that warns and exports the part as
# an ordinary single-filament object.
#
# See: docs/workflows/multicolor.md, docs/toolchain/pipelines.md ("3MF export")
# ============================================================
import argparse
import json
import sys
import uuid
import zipfile
from xml.etree import ElementTree as ET

CORE_NS = "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"
MATERIAL_NS = "http://schemas.microsoft.com/3dmanufacturing/material/2015/02"
PROD_NS = "http://schemas.microsoft.com/3dmanufacturing/production/2015/06"
BBL_NS = "http://schemas.bambulab.com/package/2021"
RELS_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
REL_TYPE = "http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"

ET.register_namespace("", CORE_NS)
ET.register_namespace("p", PROD_NS)
ET.register_namespace("BambuStudio", BBL_NS)


def q(ns, tag):
    return f"{{{ns}}}{tag}"


def normalize_hex(value):
    """#rrggbb / #rrggbbaa / rrggbb -> "#RRGGBB". Alpha is dropped: it says
    nothing about which filament to print the region in, and OpenSCAD writes
    it differently per material-type (opaque is "00" in one, "FF" in the
    other). Bambu's own parser only accepts uppercase hex, so everything is
    compared -- and written -- uppercase."""
    text = value.strip().lstrip("#").upper()
    if len(text) == 8:
        text = text[:6]
    if len(text) != 6 or any(c not in "0123456789ABCDEF" for c in text):
        raise ValueError(f"not a hex color: {value!r}")
    return "#" + text


def serialize_xml(root):
    """Bambu Studio's own reader is not a fully spec-compliant XML parser --
    match the exact byte style of a real Bambu file (double-quoted,
    uppercase UTF-8) rather than ElementTree's default declaration. Same
    reasoning as assemble_3mf.py's serialize_xml()."""
    body = ET.tostring(root, encoding="unicode")
    return f'<?xml version="1.0" encoding="UTF-8"?>\n{body}'.encode("utf-8")


def relationships_xml(entries):
    """entries: list of (target, rel_id). Built as a plain string because
    registering the relationships namespace to the default prefix would
    evict CORE_NS from ElementTree's prefix map (see assemble_3mf.py)."""
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             f'<Relationships xmlns="{RELS_NS}">']
    for target, rel_id in entries:
        lines.append(f' <Relationship Target="{target}" Id="{rel_id}" Type="{REL_TYPE}"/>')
    lines.append("</Relationships>")
    return "\n".join(lines).encode("utf-8")


CONTENT_TYPES = (
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
    ' <Default Extension="rels" '
    'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
    ' <Default Extension="model" '
    'ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>\n'
    ' <Default Extension="png" ContentType="image/png"/>\n'
    "</Types>\n"
).encode("utf-8")


# ---- Reading OpenSCAD's colored, lazy-union export -------------------------

class Region:
    """One top-level child of the part: a closed mesh plus the one color it
    was drawn in."""

    def __init__(self, index, color, mesh_element):
        self.index = index
        self.color = color
        self.mesh = mesh_element


def read_regions(path):
    """Returns [Region, ...] in the order OpenSCAD wrote them (which is the
    order the part's BUILD:EXCLUDE block calls its regions in)."""
    with zipfile.ZipFile(path) as zf:
        root = ET.fromstring(zf.read("3D/3dmodel.model"))

    resources = root.find(q(CORE_NS, "resources"))
    if resources is None:
        raise ValueError(f"{path}: no <resources> -- not a 3MF OpenSCAD wrote?")

    # The palette every triangle's p1 indexes into. OpenSCAD writes
    # <m:colorgroup> for material-type=color; <basematerials> is its other
    # spelling (and the one Bambu ignores), accepted here so a mis-set
    # export-3mf/material-type still produces a readable error downstream
    # rather than a crash.
    palette = []
    colorgroup = resources.find(q(MATERIAL_NS, "colorgroup"))
    if colorgroup is not None:
        palette = [c.get("color", "") for c in colorgroup.findall(q(MATERIAL_NS, "color"))]
    else:
        basematerials = resources.find(q(CORE_NS, "basematerials"))
        if basematerials is not None:
            palette = [b.get("displaycolor", "")
                       for b in basematerials.findall(q(CORE_NS, "base"))]

    regions = []
    for index, obj in enumerate(resources.findall(q(CORE_NS, "object")), start=1):
        mesh = obj.find(q(CORE_NS, "mesh"))
        if mesh is None:
            continue  # a components-only object: not something OpenSCAD writes

        indices = set()
        for triangle in mesh.find(q(CORE_NS, "triangles")):
            p1 = triangle.get("p1")
            if p1 is not None:
                indices.add(int(p1))
        if not indices and obj.get("pindex") is not None:
            indices.add(int(obj.get("pindex")))     # uniform object, color on the object

        colors = sorted({normalize_hex(palette[i]) for i in indices if i < len(palette)})
        if len(colors) > 1:
            raise ValueError(
                f"region {index} is drawn in more than one color ({', '.join(colors)}).\n"
                "       Each top-level child of a multicolor part must be a single "
                "color. Usually\n"
                "       this means a color() sits INSIDE a difference()/intersection(): "
                "the faces\n"
                "       the cut creates are not covered by it and export uncolored. Wrap "
                "the whole\n"
                "       region in one color() instead. On the assembly preview plate it "
                "can also be\n"
                "       a solid outside every assembly_region(), which lands in every "
                "region\n"
                "       (docs/workflows/multicolor.md).")
        regions.append(Region(index, colors[0] if colors else None, mesh))
    return regions


# ---- Writing the Bambu multi-part object ----------------------------------

def build_object_model(object_id, mesh):
    """One /3D/Objects/object_N.model, holding one region's mesh. Every color
    attribute is dropped here: pid/p1 on the triangles, pid/pindex on the
    object (see the module header)."""
    model = ET.Element(q(CORE_NS, "model"), {
        "unit": "millimeter",
        "{http://www.w3.org/XML/1998/namespace}lang": "en-US",
        "xmlns:BambuStudio": BBL_NS,
        "requiredextensions": "p",
    })
    meta = ET.SubElement(model, q(CORE_NS, "metadata"), {"name": "BambuStudio:3mfVersion"})
    meta.text = "1"
    resources = ET.SubElement(model, q(CORE_NS, "resources"))
    obj = ET.SubElement(resources, q(CORE_NS, "object"), {
        "id": str(object_id),
        q(PROD_NS, "UUID"): str(uuid.uuid4()),
        "type": "model",
    })
    for triangle in mesh.find(q(CORE_NS, "triangles")):
        triangle.attrib.pop("pid", None)
        triangle.attrib.pop("p1", None)
        triangle.attrib.pop("p2", None)
        triangle.attrib.pop("p3", None)
    obj.append(mesh)
    ET.SubElement(model, q(CORE_NS, "build"))
    return serialize_xml(model)


def build_multipart_3mf(output_path, regions, slots, name, reference_path):
    """regions/slots are parallel: slots[i] is the filament slot region i
    prints in. Mirrors the structure assemble_3mf.py later merges: a wrapper
    <object> whose components are the regions, one <build><item>, and a
    Metadata/model_settings.config <part> per component."""
    wrapper_id = len(regions) + 1

    model = ET.Element(q(CORE_NS, "model"), {
        "unit": "millimeter",
        "{http://www.w3.org/XML/1998/namespace}lang": "en-US",
        "xmlns:BambuStudio": BBL_NS,
        "requiredextensions": "p",
    })
    for key, value in [("Application", "BambuStudio"),
                       ("BambuStudio:3mfVersion", "1"),
                       ("Title", name)]:
        meta = ET.SubElement(model, q(CORE_NS, "metadata"), {"name": key})
        meta.text = value

    resources = ET.SubElement(model, q(CORE_NS, "resources"))
    wrapper = ET.SubElement(resources, q(CORE_NS, "object"), {
        "id": str(wrapper_id),
        q(PROD_NS, "UUID"): str(uuid.uuid4()),
        "type": "model",
    })
    components = ET.SubElement(wrapper, q(CORE_NS, "components"))

    settings_root = ET.Element("config")
    settings_object = ET.SubElement(settings_root, "object", {"id": str(wrapper_id)})
    ET.SubElement(settings_object, "metadata", {"key": "name", "value": name})
    ET.SubElement(settings_object, "metadata", {"key": "extruder", "value": str(slots[0])})

    object_files = {}
    rels_entries = []
    for position, (region, slot) in enumerate(zip(regions, slots), start=1):
        filename = f"object_{position}.model"
        object_files[f"3D/Objects/{filename}"] = build_object_model(position, region.mesh)
        rels_entries.append((f"/3D/Objects/{filename}", f"rel-{position}"))

        ET.SubElement(components, q(CORE_NS, "component"), {
            q(PROD_NS, "path"): f"/3D/Objects/{filename}",
            "objectid": str(position),
            q(PROD_NS, "UUID"): str(uuid.uuid4()),
            # Identity: the region meshes already sit at the part's authored
            # coordinates, so they line up with each other exactly as drawn.
            "transform": "1 0 0 0 1 0 0 0 1 0 0 0",
        })

        # The object carries the input file's name, because that is the key
        # per-object overrides are matched on (export_3mf.sh --object-set);
        # its parts are named after the part without it, since that is what
        # shows up in Bambu Studio's object tree.
        part = ET.SubElement(settings_object, "part",
                             {"id": str(position), "subtype": "normal_part"})
        display_name = name.rsplit(".", 1)[0] if "." in name else name
        ET.SubElement(part, "metadata",
                      {"key": "name", "value": f"{display_name}_{position}"})
        ET.SubElement(part, "metadata",
                      {"key": "matrix", "value": "1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1"})
        ET.SubElement(part, "metadata", {"key": "extruder", "value": str(slot)})

    build = ET.SubElement(model, q(CORE_NS, "build"), {q(PROD_NS, "UUID"): str(uuid.uuid4())})
    ET.SubElement(build, q(CORE_NS, "item"), {
        "objectid": str(wrapper_id),
        q(PROD_NS, "UUID"): str(uuid.uuid4()),
        "transform": "1 0 0 0 1 0 0 0 1 0 0 0",
        "printable": "1",
    })

    plate = ET.SubElement(settings_root, "plate")
    for key, value in [("plater_id", "1"), ("plater_name", ""), ("locked", "false")]:
        ET.SubElement(plate, "metadata", {"key": key, "value": value})
    instance = ET.SubElement(plate, "model_instance")
    for key, value in [("object_id", str(wrapper_id)), ("instance_id", "0")]:
        ET.SubElement(instance, "metadata", {"key": key, "value": value})
    ET.SubElement(settings_root, "assemble")

    # Bambu Studio's CLI segfaults on a project with no print settings at
    # all (tested), so the reference settings ride along on this
    # intermediate file too. assemble_3mf.py grafts them again -- with the
    # export's own --set overrides applied -- onto the final project.
    with zipfile.ZipFile(reference_path) as ref_zip:
        project_settings = ref_zip.read("Metadata/project_settings.config")

    with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", CONTENT_TYPES)
        zf.writestr("_rels/.rels", relationships_xml([("/3D/3dmodel.model", "rel-0")]))
        zf.writestr("3D/3dmodel.model", serialize_xml(model))
        zf.writestr("3D/_rels/3dmodel.model.rels", relationships_xml(rels_entries))
        for path, data in object_files.items():
            zf.writestr(path, data)
        zf.writestr("Metadata/model_settings.config", serialize_xml(settings_root))
        zf.writestr("Metadata/project_settings.config", project_settings)


# ---- Entry point -----------------------------------------------------------

def reference_filament_count(reference_path):
    with zipfile.ZipFile(reference_path) as zf:
        settings = json.loads(zf.read("Metadata/project_settings.config"))
    return len(settings.get("filament_colour", []))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument("--reference", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--map", action="append", default=[],
                        metavar="#RRGGBB=SLOT", help="one FILAMENT_MAP entry")
    args = parser.parse_args()

    filament_map = {}
    for entry in args.map:
        if "=" not in entry:
            print(f"FILAMENT_MAP entry is not \"#RRGGBB=<slot>\": {entry!r}", file=sys.stderr)
            return 1
        color, slot = entry.rsplit("=", 1)
        try:
            filament_map[normalize_hex(color)] = int(slot)
        except ValueError as error:
            print(f"FILAMENT_MAP entry {entry!r}: {error}", file=sys.stderr)
            return 1

    try:
        regions = read_regions(args.input)
    except ValueError as error:
        print(f"{args.name}: {error}", file=sys.stderr)
        return 1

    if not regions:
        print(f"{args.name}: the export is empty -- OpenSCAD produced no object at all.",
              file=sys.stderr)
        return 1

    # ONE region is not a failure: a parameter can legitimately collapse a
    # multicolor part to a single color (label_style=none in the demo), and
    # PARAM_OVERRIDES in export_3mf_config.sh apply here just like anywhere
    # else. Say so and print it as a plain single-filament object, rather
    # than failing an export the author asked for. A part that is ALWAYS one
    # color simply shouldn't carry multicolor=1.
    if len(regions) == 1:
        slots = [filament_map.get(regions[0].color, 1)]
        print(f"    warning: only one color region ({regions[0].color}); exporting "
              f"{args.name} as a single-filament object on filament {slots[0]}",
              file=sys.stderr)
    else:
        unmapped = sorted({r.color for r in regions if r.color not in filament_map})
        if unmapped:
            found = ", ".join(f"{r.color or '(none)'}" for r in regions)
            print(f"{args.name}: no FILAMENT_MAP entry for "
                  f"{', '.join(str(c) for c in unmapped)}.\n"
                  f"       Regions found, in order: {found}\n"
                  "       Add them to FILAMENT_MAP in scripts/export_3mf_config.sh, e.g.\n"
                  + "".join(f'           "{c}=<slot>"\n' for c in unmapped if c),
                  file=sys.stderr)
            return 1
        slots = [filament_map[r.color] for r in regions]

    available = reference_filament_count(args.reference)
    too_high = sorted({s for s in slots if s > available})
    if too_high:
        print(f"{args.name}: FILAMENT_MAP asks for filament "
              f"{', '.join(str(s) for s in too_high)}, but REFERENCE_3MF "
              f"({args.reference}) has {available}.\n"
              "       Load that many filaments in Bambu Studio, save the project "
              "again, and\n"
              "       point REFERENCE_3MF at it -- filament slots cannot be added "
              "by this script\n"
              "       (a synthesized slot crashes Bambu Studio: tested).",
              file=sys.stderr)
        return 1

    build_multipart_3mf(args.output, regions, slots, args.name, args.reference)
    for region, slot in zip(regions, slots):
        print(f"    region {region.index}: {region.color} -> filament {slot}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
