#!/usr/bin/env python3
# ============================================================
# <PROJECT NAME>  |  Multi-plate 3MF assembler (Bambu side)
# ------------------------------------------------------------
# Used by scripts/export/export_3mf.sh. Bambu Studio's CLI can arrange parts onto
# ONE plate (--arrange=1 --export-3mf=...) but has no way to build several
# plates into one project in a single call -- passing several .3mf files as
# input crashes it outright (tested), and there's no documented "add plate"
# flag. So scripts/export/export_3mf.sh calls Bambu Studio CLI once PER PLATE (each
# one arranged -- or not, per PLATE_<N>_ARRANGE -- within the real printer's
# bed shape), and this script does the multi-plate merge by hand: for each
# single-plate export, it
#   1. renumbers every object/part id (each single-plate export restarts
#      counting from 1, so merging as-is would collide) and copies its mesh
#      data across -- one mesh per component, so a multicolor part
#      (multicolor_3mf.py: one object, one part per color region, each with
#      its own filament) survives the merge with its parts intact,
#   2. writes one Metadata/model_settings.config with one <plate> block per
#      plate, and grafts a REFERENCE .3mf's Metadata/project_settings.config
#      (printer/filament/process settings) onto the result wholesale.
#
# NOT done here: recomputing or centering any object's position -- whatever
# X/Y Bambu Studio's own --arrange (or, with PLATE_<N>_ARRANGE=false, plain
# STL import) placed each part at, within its own plate, is kept completely
# as-is. The ONE thing this script does add is a per-plate rigid shift (see
# grid_cell()) so different plates don't all land in the same world-space
# region -- plain <plate>/<model_instance> metadata turned out not to be
# enough on its own for Bambu Studio to actually keep plates visually and
# functionally separate (tried that: every object showed up piled onto
# plate 1 regardless of its metadata). That shift is a constant offset per
# plate, not a recomputed position -- it doesn't touch the arrangement
# Bambu Studio already worked out within each plate, just slides the whole
# plate as a rigid group. Two earlier, more ambitious attempts at this
# (an invented grid pitch combined with a bounding-box recentering pass)
# caused real bugs (parts landing outside their plate) because there's no
# official spec for Bambu's own placement conventions to check that kind of
# logic against -- the current grid pitch is instead copied directly from
# the coordinate pattern in a real, currently-used multi-plate project
# (see grid_cell()'s own comment), and centering has been dropped entirely.
#
# That settings graft is its own separate copy rather than something Bambu
# Studio's CLI does for us: the CLI accepts individual "--<setting>=<value>"
# overrides and even a "--printer-settings-id=<name>" flag, but the latter
# only stores that label -- it doesn't pull in the preset's actual nozzle
# size/bed shape/etc (those live in a system-profile inheritance chain the
# CLI doesn't resolve), and there's no working "--load"/"--load_settings"
# equivalent for a *full* preset (both tested, both fail). Copying the
# already-fully-resolved settings blob from a project saved once via the
# Bambu Studio GUI sidesteps that entirely.
#
# This is by nature more intricate than a straight file copy -- it's
# reconstructing part of Bambu Studio's own project-file writer from the
# schema of files it produces, not from a documented spec. Sanity-check the
# very first multi-plate file this produces by actually opening it in Bambu
# Studio before relying on it.
#
# Usage:
#   assemble_3mf.py OUTPUT.3mf --reference REF.3mf \
#       --bed-width W --bed-depth D \
#       --plate "Plate name" plate1.3mf [--plate "Plate name 2" plate2.3mf ...] \
#       [--set KEY=VALUE ...] \
#       [--object-set PLATE_NUMBER FILENAME KEY=VALUE ...]
#
# --bed-width/--bed-depth are used only to space plates apart in world-space
# (see grid_cell()) -- they don't affect anything within a single plate.
#
# --set overrides a print setting globally (on top of REFERENCE_3MF's own
# settings); --object-set overrides one setting on one specific part (e.g.
# "3 shelf.stl enable_support=1" -- plate 3's shelf.stl only), matching how
# a real Bambu Studio project already lets one object override the plate's
# settings via sibling <metadata> entries in Metadata/model_settings.config.
# Both reject any key that isn't already a real key in REFERENCE_3MF's own
# project_settings.config, rather than silently injecting an unknown one.
# ============================================================
import argparse
import json
import sys
import uuid
import zipfile
from xml.etree import ElementTree as ET

CORE_NS = "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"
PROD_NS = "http://schemas.microsoft.com/3dmanufacturing/production/2015/06"
BBL_NS = "http://schemas.bambulab.com/package/2021"
RELS_NS = "http://schemas.openxmlformats.org/package/2006/relationships"

ET.register_namespace("", CORE_NS)
ET.register_namespace("p", PROD_NS)
ET.register_namespace("BambuStudio", BBL_NS)
# Note: RELS_NS is deliberately NOT registered here. ElementTree's
# register_namespace keys its internal map by prefix as well as URI --
# registering a second namespace to the same "" (default) prefix silently
# evicts the first one (CORE_NS here), so every .model file would come out
# with an auto-generated "ns0:" prefix instead of the default namespace
# Bambu Studio itself writes. The .rels files are trivial enough to build
# as plain strings instead (see relationships_xml() below), sidestepping
# the whole default-prefix collision.


def q(ns, tag):
    return f"{{{ns}}}{tag}"


def new_uuid():
    return str(uuid.uuid4())


def serialize_xml(root):
    """ET.tostring(..., xml_declaration=True) writes `<?xml version='1.0'
    encoding='utf-8'?>` -- single-quoted, lowercase encoding name. Every
    real Bambu Studio file instead writes `<?xml version="1.0"
    encoding="UTF-8"?>` (double-quoted, uppercase). Both are equally valid
    XML, but Bambu Studio's own config reader may not be a fully spec-
    compliant XML parser -- match its exact byte style rather than risk it."""
    body = ET.tostring(root, encoding="unicode")
    return f'<?xml version="1.0" encoding="UTF-8"?>\n{body}'.encode("utf-8")


def relationships_xml(entries):
    """entries: list of (target, rel_id). Built as a plain string -- see the
    module-level comment on why this avoids ElementTree here."""
    rel_type = "http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             f'<Relationships xmlns="{RELS_NS}">']
    for target, rel_id in entries:
        lines.append(f' <Relationship Target="{target}" Id="{rel_id}" Type="{rel_type}"/>')
    lines.append("</Relationships>")
    return "\n".join(lines).encode("utf-8")


def parse_transform(s):
    return [float(v) for v in s.split()]


def format_transform(values):
    return " ".join(repr(v) if not float(v).is_integer() else str(int(v)) for v in values)


def get_settings_name(settings_obj):
    for meta in settings_obj.findall("metadata"):
        if meta.get("key") == "name":
            return meta.get("value")
    return None


def apply_project_settings_overrides(raw_json_bytes, overrides):
    """overrides: {key: value_string}. Bambu's project_settings.config mixes
    plain scalar keys ("layer_height": "0.2") with per-extruder list keys
    ("nozzle_temperature": ["220"], occasionally 2+ entries for a multi-
    extruder machine) -- a scalar override replicates across every element
    of an existing list rather than replacing the list's shape. Rejects any
    key not already present in the reference file: a typo'd key would
    otherwise get silently added as a new top-level key, which is exactly
    the kind of thing that made Bambu Studio reject an earlier version of
    this project's own generated file as "not from Bambu Lab" (see the
    module comment) -- fail loudly instead of risking another silent-reject
    class of bug."""
    data = json.loads(raw_json_bytes)
    for key, value in overrides.items():
        if key not in data:
            raise ValueError(f"Unknown print-setting override key: {key!r} (not found in REFERENCE_3MF's project_settings.config)")
        existing = data[key]
        if isinstance(existing, list):
            data[key] = [value for _ in existing] if existing else [value]
        else:
            data[key] = value
    text = json.dumps(data, indent=4, sort_keys=True)
    return (text.replace("\n", "\r\n") + "\r\n").encode("utf-8")


class SinglePlate:
    """Parses one Bambu Studio single-plate .3mf export into a plain
    in-memory representation: one entry per printed OBJECT, each with its
    build-item transform (object-local -> world) and one component per mesh
    the object is built from -- with that component's own transform (mesh ->
    object-local) -- all kept exactly as Bambu Studio itself wrote them
    (nothing here ever touches either transform) -- plus the matching
    Metadata/model_settings.config <object> block (kept verbatim except for
    the ids, which the caller renumbers).

    An object usually has ONE component, but a multicolor part (see
    multicolor_3mf.py) is one object with one component per color region,
    each carrying its own `extruder` in the settings block. Bambu Studio's
    CLI keeps that grouping through arrange and orient, so by here it is
    just an object that happens to have several components."""

    def __init__(self, path):
        with zipfile.ZipFile(path) as zf:
            model_xml = zf.read("3D/3dmodel.model")
            settings_xml = zf.read("Metadata/model_settings.config")
            mesh_cache = {}

            def get_mesh_file(path_in_zip):
                if path_in_zip not in mesh_cache:
                    mesh_cache[path_in_zip] = zf.read(path_in_zip.lstrip("/"))
                return mesh_cache[path_in_zip]

            model_root = ET.fromstring(model_xml)
            settings_root = ET.fromstring(settings_xml)

            self.application = "BambuStudio"
            for meta in model_root.findall(q(CORE_NS, "metadata")):
                if meta.get("name") == "Application" and meta.text:
                    self.application = meta.text
                    break

            objects_by_id = {}
            for obj in model_root.findall(f"{q(CORE_NS, 'resources')}/{q(CORE_NS, 'object')}"):
                objects_by_id[obj.get("id")] = obj

            settings_objects_by_id = {}
            for obj in settings_root.findall("object"):
                settings_objects_by_id[obj.get("id")] = obj

            self.objects = []
            for item in model_root.findall(f"{q(CORE_NS, 'build')}/{q(CORE_NS, 'item')}"):
                wrapper_id = item.get("objectid")
                item_transform = item.get("transform", "1 0 0 0 1 0 0 0 1 0 0 0")

                wrapper_obj = objects_by_id[wrapper_id]
                components = []
                for component in wrapper_obj.findall(
                        f"{q(CORE_NS, 'components')}/{q(CORE_NS, 'component')}"):
                    components.append({
                        "mesh_xml": get_mesh_file(component.get(q(PROD_NS, "path"))),
                        "mesh_objectid": component.get("objectid"),
                        "comp_transform": component.get(
                            "transform", "1 0 0 0 1 0 0 0 1 0 0 0"),
                    })

                self.objects.append({
                    "components": components,
                    "item_transform": item_transform,
                    "settings_object": settings_objects_by_id[wrapper_id],
                })

    def shift_xy(self, dx, dy):
        """Adds a constant (dx, dy) to every object's build-item translation
        -- a pure additive offset, not a recomputed position: whatever X/Y
        Bambu Studio's own --arrange/--orient (or plain STL import) already
        decided is preserved exactly, just slid over as a rigid group (which
        for a multicolor object moves all of its parts together, since they
        share the one item transform). Used to separate plates in the shared
        world-coordinate space -- see grid_cell()'s comment for why that's
        needed at all."""
        for obj in self.objects:
            t = parse_transform(obj["item_transform"])
            t[9] += dx
            t[10] += dy
            obj["item_transform"] = format_transform(t)


GAP_MM = 50.0


def grid_cell(index, count, bed_width, bed_depth):
    """Bambu Studio's multi-plate view apparently doesn't rely solely on the
    explicit <plate>/<model_instance> metadata to keep plates visually and
    functionally separate -- confirmed by trying exactly that (every plate
    sharing the same (0,0)-(bed) coordinate range): every object showed up
    on plate 1, all on top of each other, regardless of which plate its own
    metadata said it belonged to. So plates need distinct, non-overlapping
    regions of world-space after all. This lays them out in a grid, pitch =
    bed size + 50mm gap, matching the exact coordinate pattern found in a
    real hand-saved multi-plate project (a real hand-saved multi-plate project:
    plate 1 and 2 share a row, offset ~306mm in X on a 256mm bed; plate 3
    sits a further ~306mm down in Y, in the same column as plate 1) -- not
    from an official spec, since Bambu's multi-plate `.3mf` layout isn't
    documented, but confirmed against real, working, currently-used data
    rather than guessed from scratch."""
    cols = 1  # ceil(sqrt(count)), computed without importing math for one call site
    while cols * cols < count:
        cols += 1
    col = index % cols
    row = index // cols
    return col * (bed_width + GAP_MM), -row * (bed_depth + GAP_MM)


def build_merged_3mf(output_path, plates_with_names, reference_path, application,
                      object_overrides=None, project_setting_overrides=None):
    object_overrides = object_overrides or {}
    model_root = ET.Element(q(CORE_NS, "model"), {
        "unit": "millimeter",
        "{http://www.w3.org/XML/1998/namespace}lang": "en-US",
        # Bambu Studio decides whether to trust the whole project (plates,
        # settings) or fall back to "not from Bambu Lab, load geometry data
        # only" partly by checking for this declaration on the model root --
        # nothing in the body actually uses the BambuStudio: prefix, so
        # ElementTree would never emit it on its own (it only emits
        # namespace declarations for prefixes actually used somewhere in the
        # tree); set it as a literal attribute instead so it's always present,
        # matching every real Bambu Studio export regardless of use.
        "xmlns:BambuStudio": BBL_NS,
        "requiredextensions": "p",
    })
    for name, value in [
        ("Application", application),
        ("BambuStudio:3mfVersion", "1"),
        ("Copyright", ""), ("CreationDate", ""), ("Description", ""),
        ("Designer", ""), ("DesignerCover", ""), ("DesignerUserId", ""),
        ("License", ""), ("ModificationDate", ""), ("Origin", ""),
        ("ProfileCover", ""), ("ProfileDescription", ""), ("ProfileTitle", ""),
        ("Title", ""),
    ]:
        meta = ET.SubElement(model_root, q(CORE_NS, "metadata"), {"name": name})
        meta.text = value

    resources = ET.SubElement(model_root, q(CORE_NS, "resources"))
    build = ET.SubElement(model_root, q(CORE_NS, "build"), {q(PROD_NS, "UUID"): new_uuid()})

    settings_root = ET.Element("config")
    mesh_files = {}  # filename -> xml bytes (with renumbered object id)
    rels_entries = []

    next_id = 0          # 3MF resource ids, unique across the whole project
    mesh_counter = 0     # one /3D/Objects/object_N.model per component
    plate_blocks = []

    for plate_index, (plate_name, plate) in enumerate(plates_with_names):
        model_instances = []
        for printed_object in plate.objects:
            wrapper_obj = ET.SubElement(resources, q(CORE_NS, "object"), {
                "id": "",    # filled in below: the wrapper is numbered last
                q(PROD_NS, "UUID"): new_uuid(),
                "type": "model",
            })
            components = ET.SubElement(wrapper_obj, q(CORE_NS, "components"))

            # One mesh file per component. A single-color part has exactly
            # one; a multicolor part has one per color region, and its
            # <part> blocks are matched to them BY POSITION -- which is how
            # Bambu Studio itself writes them (part id == component
            # objectid, in file order).
            settings_obj = printed_object["settings_object"]
            part_elems = settings_obj.findall("part")
            for position, component in enumerate(printed_object["components"]):
                next_id += 1
                mesh_counter += 1
                mesh_id = str(next_id)
                mesh_filename = f"object_{mesh_counter}.model"

                # Rewrite the mesh file's own <object id="..."> to mesh_id.
                mesh_root = ET.fromstring(component["mesh_xml"])
                for obj in mesh_root.findall(
                        f"{q(CORE_NS, 'resources')}/{q(CORE_NS, 'object')}"):
                    if obj.get("id") == component["mesh_objectid"]:
                        obj.set("id", mesh_id)
                        obj.set(q(PROD_NS, "UUID"), new_uuid())
                mesh_files[mesh_filename] = serialize_xml(mesh_root)
                rels_entries.append((f"/3D/Objects/{mesh_filename}", f"rel-{mesh_counter}"))

                ET.SubElement(components, q(CORE_NS, "component"), {
                    q(PROD_NS, "path"): f"/3D/Objects/{mesh_filename}",
                    "objectid": mesh_id,
                    q(PROD_NS, "UUID"): new_uuid(),
                    "transform": component["comp_transform"],
                })

                if position < len(part_elems):
                    part_elems[position].set("id", mesh_id)

            next_id += 1
            wrapper_id = str(next_id)
            wrapper_obj.set("id", wrapper_id)

            ET.SubElement(build, q(CORE_NS, "item"), {
                "objectid": wrapper_id,
                q(PROD_NS, "UUID"): new_uuid(),
                "transform": printed_object["item_transform"],
                "printable": "1",
            })

            settings_obj.set("id", wrapper_id)

            # Per-object print-setting overrides (e.g. enable_support for
            # just this part) are plain sibling <metadata key=.. value=../>
            # entries next to name/extruder -- this is how a real hand-
            # arranged Bambu Studio project already represents them (see
            # a real hand-saved project's own model_settings.config
            # for objects with enable_support set only on the parts that
            # actually need it).
            part_filename = get_settings_name(settings_obj)
            for key, value in object_overrides.get((plate_index + 1, part_filename), {}).items():
                ET.SubElement(settings_obj, "metadata", {"key": key, "value": value})

            settings_root.append(settings_obj)

            model_instances.append(wrapper_id)

        plate_blocks.append((plate_index + 1, plate_name, model_instances))

    plate_elem_parent = settings_root
    for plater_id, plate_name, object_ids in plate_blocks:
        plate_elem = ET.SubElement(plate_elem_parent, "plate")
        for key, value in [
            ("plater_id", str(plater_id)),
            ("plater_name", plate_name),
            ("locked", "false"),
            ("filament_map_mode", "Auto For Flush"),
        ]:
            ET.SubElement(plate_elem, "metadata", {"key": key, "value": value})
        for object_id in object_ids:
            instance = ET.SubElement(plate_elem, "model_instance")
            for key, value in [
                ("object_id", object_id),
                ("instance_id", "0"),
                ("identify_id", str(100 + int(object_id))),
            ]:
                ET.SubElement(instance, "metadata", {"key": key, "value": value})

    ET.SubElement(settings_root, "assemble")

    with zipfile.ZipFile(reference_path) as ref_zip:
        project_settings = ref_zip.read("Metadata/project_settings.config")
    if project_setting_overrides:
        project_settings = apply_project_settings_overrides(project_settings, project_setting_overrides)

    client_version = application.split("-", 1)[1] if "-" in application else "01.00.00.00"
    slice_info = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        "<config>\n"
        " <header>\n"
        f'  <header_item key="X-BBL-Client-Type" value="slicer"/>\n'
        f'  <header_item key="X-BBL-Client-Version" value="{client_version}"/>\n'
        " </header>\n"
        "</config>"
    ).encode("utf-8")

    content_types = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
        ' <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
        ' <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>\n'
        ' <Default Extension="png" ContentType="image/png"/>\n'
        ' <Default Extension="gcode" ContentType="text/x.gcode"/>\n'
        '</Types>'
    ).encode("utf-8")

    root_rels = relationships_xml([("/3D/3dmodel.model", "rel-1")])
    model_rels = relationships_xml(rels_entries)

    with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as out_zip:
        out_zip.writestr("[Content_Types].xml", content_types)
        out_zip.writestr("_rels/.rels", root_rels)
        out_zip.writestr("3D/3dmodel.model", serialize_xml(model_root))
        out_zip.writestr("3D/_rels/3dmodel.model.rels", model_rels)
        for filename, data in mesh_files.items():
            out_zip.writestr(f"3D/Objects/{filename}", data)
        out_zip.writestr("Metadata/model_settings.config", serialize_xml(settings_root))
        out_zip.writestr("Metadata/project_settings.config", project_settings)
        out_zip.writestr("Metadata/slice_info.config", slice_info)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output")
    parser.add_argument("--reference", required=True)
    parser.add_argument("--bed-width", type=float, required=True,
                         help="Used only to space plates apart in world-space -- see grid_cell()'s comment.")
    parser.add_argument("--bed-depth", type=float, required=True)
    parser.add_argument("--plate", nargs=2, action="append", metavar=("NAME", "FILE"), required=True)
    parser.add_argument("--set", dest="set_", action="append", default=[], metavar="KEY=VALUE",
                         help="Global print-setting override, applied on top of REFERENCE_3MF's settings.")
    parser.add_argument("--object-set", nargs=3, action="append", default=[],
                         metavar=("PLATE_NUMBER", "FILENAME", "KEY=VALUE"),
                         help="Per-object print-setting override for one part on one plate (1-based plate number).")
    args = parser.parse_args()

    with zipfile.ZipFile(args.reference) as ref_zip:
        known_keys = set(json.loads(ref_zip.read("Metadata/project_settings.config")).keys())

    def split_kv(kv, source):
        if "=" not in kv:
            raise SystemExit(f"{source}: expected KEY=VALUE, got {kv!r}")
        key, value = kv.split("=", 1)
        if key not in known_keys:
            raise SystemExit(f"{source}: unknown print-setting key {key!r} (not found in {args.reference}'s project_settings.config)")
        return key, value

    project_setting_overrides = {}
    for kv in args.set_:
        key, value = split_kv(kv, "--set")
        project_setting_overrides[key] = value

    object_overrides = {}
    for plate_number, filename, kv in args.object_set:
        key, value = split_kv(kv, "--object-set")
        object_overrides.setdefault((int(plate_number), filename), {})[key] = value

    plates_with_names = []
    for index, (name, path) in enumerate(args.plate):
        plate = SinglePlate(path)
        plate.shift_xy(*grid_cell(index, len(args.plate), args.bed_width, args.bed_depth))
        plates_with_names.append((name, plate))

    application = plates_with_names[0][1].application
    build_merged_3mf(args.output, plates_with_names, args.reference, application,
                      object_overrides=object_overrides,
                      project_setting_overrides=project_setting_overrides)
    print(f"Assembled {len(plates_with_names)} plate(s) -> {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
