"""Offline Luau -> Roblox XML sync. Python 3.10+, standard library only (CC0)."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import sys
import tempfile
import xml.etree.ElementTree as ET

ARTIFACTS = ("SaveMenuStarterPack.rbxmx", "SaveMenuDemo.rbxlx")
CLASSES = {"Script", "LocalScript", "ModuleScript"}
MAX_XML_BYTES = 32 * 1024 * 1024


class PackError(ValueError):
    """Invalid or ambiguous input; no output should be trusted."""


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def script_name(filename: str) -> str:
    for suffix in (".server.lua", ".client.lua", ".lua"):
        if filename.endswith(suffix):
            return filename[:-len(suffix)]
    raise PackError(f"Unsupported source filename: {filename}")


def safe_parts(value: str) -> tuple[str, ...]:
    if not isinstance(value, str) or not value or "\\" in value or ":" in value:
        raise PackError(f"Invalid relative path: {value!r}")
    parts = value.split("/")
    if any(p in ("", ".", "..") for p in parts) or PurePosixPath(value).is_absolute():
        raise PackError(f"Invalid relative path: {value!r}")
    return tuple(parts)


def contained(root: Path, parts: tuple[str, ...]) -> Path:
    path = root.joinpath(*parts).resolve()
    if not path.is_relative_to(root):
        raise PackError(f"Source escapes repository: {'/'.join(parts)}")
    return path


def load_catalogue(root: Path) -> list[dict]:
    rows = json.loads((root / "catalogue.json").read_text(encoding="utf-8"))
    if not isinstance(rows, list) or not rows:
        raise PackError("Catalogue must be a nonempty list")
    names, targets, result = set(), set(), []
    for row in rows:
        if not isinstance(row, dict):
            raise PackError("Catalogue entry must be an object")
        name, path, cls = row.get("name"), row.get("path"), row.get("class")
        name_parts, path_parts = safe_parts(name), safe_parts(path)
        if len(name_parts) != 1 or path_parts[-1] != name or cls not in CLASSES:
            raise PackError(f"Invalid catalogue entry: {row}")
        expected = "Script" if name.endswith(".server.lua") else "LocalScript" if name.endswith(".client.lua") else "ModuleScript"
        if cls != expected:
            raise PackError(f"Filename/class disagreement: {name}")
        target = path_parts[:-1] + (script_name(name),)
        if name in names or target in targets:
            raise PackError(f"Duplicate catalogue entry: {name}")
        names.add(name)
        targets.add(target)
        # Release folders and flat checkouts are both supported, but ambiguity fails.
        candidates = list(dict.fromkeys([contained(root, path_parts), contained(root, name_parts)]))
        existing = [p for p in candidates if p.is_file()]
        if not existing:
            raise PackError(f"Missing source: {name}")
        contents = [p.read_bytes() for p in existing]
        if any(c != contents[0] for c in contents[1:]):
            raise PackError(f"Conflicting flat and nested sources: {name}")
        text = contents[0].decode("utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")
        if any(ord(c) < 32 and c not in "\t\n" for c in text):
            raise PackError(f"XML-incompatible control character: {name}")
        result.append({"name": name, "target": target, "class": cls, "text": text})
    return result


def property_node(item: ET.Element, tag: str, name: str) -> ET.Element:
    found = item.findall(f"./Properties/{tag}[@name='{name}']")
    if len(found) != 1:
        raise PackError(f"Expected one {name} property, found {len(found)}")
    return found[0]


def parse_xml(raw: bytes) -> ET.ElementTree:
    if len(raw) > MAX_XML_BYTES:
        raise PackError("XML exceeds 32 MiB limit")
    text = raw.decode("utf-8-sig")
    if "<!DOCTYPE" in text.upper() or "<!ENTITY" in text.upper():
        raise PackError("DTD/entity declarations are not supported")
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    root = ET.fromstring(text, parser=parser)
    if root.tag != "roblox" or root.get("version") != "4":
        raise PackError("Expected Roblox XML version 4")
    return ET.ElementTree(root)


def index_scripts(tree: ET.ElementTree) -> dict[tuple[str, ...], ET.Element]:
    result = {}

    def walk(item: ET.Element, prefix: tuple[str, ...]) -> None:
        name = property_node(item, "string", "Name").text
        if not name or "/" in name:
            raise PackError("Empty or ambiguous instance name")
        path = prefix + (name,)
        if item.get("class") in CLASSES:
            # The import model has a wrapper; the place has actual services.
            normalized = path
            if normalized[:1] == ("SaveMenuStarterPack",):
                normalized = normalized[1:]
            if normalized[:2] == ("StarterPlayer", "StarterPlayerScripts"):
                normalized = normalized[1:]
            if normalized in result:
                raise PackError(f"Duplicate script path: {'/'.join(normalized)}")
            result[normalized] = item
        for child in item.findall("Item"):
            walk(child, path)

    for item in tree.getroot().findall("Item"):
        walk(item, ())
    return result


def plan(root: Path) -> tuple[dict, dict[str, bytes]]:
    rows = load_catalogue(root)
    expected = {row["target"] for row in rows}
    report = {"format": 1, "artifacts": [], "drift_count": 0}
    outputs = {}
    for filename in ARTIFACTS:
        raw = (root / filename).read_bytes()
        tree = parse_xml(raw)
        scripts = index_scripts(tree)
        if set(scripts) != expected:
            missing = sorted('/'.join(p) for p in expected - set(scripts))
            extra = sorted('/'.join(p) for p in set(scripts) - expected)
            raise PackError(f"{filename}: script layout mismatch; missing={missing}, extra={extra}")
        changed = []
        for row in rows:
            item = scripts[row["target"]]
            if item.get("class") != row["class"]:
                raise PackError(f"{filename}: wrong class for {row['name']}")
            source = property_node(item, "ProtectedString", "Source")
            if (source.text or "") != row["text"]:
                changed.append(row["name"])
                source.text = row["text"]
        # No drift means byte-for-byte copy, avoiding unnecessary formatting diffs.
        output = ET.tostring(tree.getroot(), encoding="utf-8", xml_declaration=True) if changed else raw
        parse_xml(output)  # Fail before any file is written if serialization is invalid.
        outputs[filename] = output
        report["drift_count"] += len(changed)
        report["artifacts"].append({"file": filename, "scripts": len(rows), "changed": changed,
                                    "input_sha256": digest(raw), "output_sha256": digest(output)})
    report["sources"] = {r["name"]: digest(r["text"].encode("utf-8")) for r in rows}
    return report, outputs


def build(root: Path, output: Path, report: dict, outputs: dict[str, bytes]) -> None:
    output = output.resolve()
    # Never overwrite templates or previous builds, even through symlink aliases.
    if output == root or root.is_relative_to(output) or output.exists():
        raise PackError("Output must be a new directory, separate from input files")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".studio-sync-", dir=output.parent) as staging:
        stage = Path(staging) / "result"
        stage.mkdir()
        for name, data in outputs.items():
            (stage / name).write_bytes(data)
        (stage / "sync-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        os.rename(stage, output)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("check", "build"))
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--json", action="store_true", help="Print machine-readable report")
    args = parser.parse_args(argv)
    if (args.command == "build") != (args.output_dir is not None):
        parser.error("--output-dir is required only for build")
    try:
        root = args.root.resolve()
        report, outputs = plan(root)
        if args.command == "build":
            build(root, args.output_dir, report, outputs)
        if args.json:
            print(json.dumps(report, indent=2))
        else:
            for artifact in report["artifacts"]:
                print(f"{artifact['file']}: {artifact['scripts']} scripts, {len(artifact['changed'])} changed")
                for name in artifact["changed"]:
                    print(f"  {name}")
            if args.command == "build":
                print(f"Built: {args.output_dir.resolve()}")
        return 1 if args.command == "check" and report["drift_count"] else 0
    except (PackError, OSError, UnicodeError, ET.ParseError, RecursionError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
