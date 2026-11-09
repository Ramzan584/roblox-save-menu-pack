"""Regression tests using real pack XML and temporary copies; no Roblox required."""
import contextlib
import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest
import xml.etree.ElementTree as ET

import studio_sync as sync


class SyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo"
        self.root.mkdir()
        origin = Path(__file__).resolve().parents[1]
        for name in ["catalogue.json", *sync.ARTIFACTS]:
            shutil.copyfile(origin / name, self.root / name)
        for row in json.loads((origin / "catalogue.json").read_text()):
            shutil.copyfile(origin / row["name"], self.root / row["name"])

    def edit_xml(self, edit):
        for name in sync.ARTIFACTS:
            path = self.root / name
            tree = sync.parse_xml(path.read_bytes())
            edit(tree)
            tree.write(path, encoding="utf-8", xml_declaration=True)

    def catalogue(self, edit):
        path = self.root / "catalogue.json"
        data = json.loads(path.read_text())
        edit(data)
        path.write_text(json.dumps(data), encoding="utf-8")

    def test_existing_pack_matches_and_preserves_bytes(self):
        report, outputs = sync.plan(self.root)
        self.assertEqual(report["drift_count"], 0)
        for name, data in outputs.items():
            self.assertEqual(data, (self.root / name).read_bytes())
        self.assertEqual(len(report["sources"]), 14)

    def test_round_trip_special_characters_and_no_other_xml_changes(self):
        # Includes the CDATA terminator, Unicode and XML punctuation.
        text = '-- пример <&> ]]>\nreturn "обновлено"\n'
        (self.root / "Config.lua").write_text(text, encoding="utf-8")
        before = {n: sync.parse_xml((self.root / n).read_bytes()) for n in sync.ARTIFACTS}
        report, outputs = sync.plan(self.root)
        self.assertEqual(report["drift_count"], 2)
        target = ("ReplicatedStorage", "SaveMenuPack", "Config")
        for name, raw in outputs.items():
            after = sync.parse_xml(raw)
            source = sync.property_node(sync.index_scripts(after)[target], "ProtectedString", "Source")
            self.assertEqual(source.text, text)
            old = sync.property_node(sync.index_scripts(before[name])[target], "ProtectedString", "Source")
            old.text = text
            self.assertEqual(ET.tostring(before[name].getroot()), ET.tostring(after.getroot()))
        output = Path(self.temp.name) / "build"
        sync.build(self.root, output, report, outputs)
        for name in sync.ARTIFACTS:
            shutil.copyfile(output / name, self.root / name)
        self.assertEqual(sync.plan(self.root)[0]["drift_count"], 0)

    def test_build_leaves_inputs_untouched_and_records_hashes(self):
        originals = {n: (self.root / n).read_bytes() for n in sync.ARTIFACTS}
        report, outputs = sync.plan(self.root)
        output = Path(self.temp.name) / "build"
        sync.build(self.root, output, report, outputs)
        manifest = json.loads((output / "sync-report.json").read_text())
        for entry in manifest["artifacts"]:
            self.assertEqual(entry["output_sha256"], sync.digest((output / entry["file"]).read_bytes()))
        self.assertEqual(originals, {n: (self.root / n).read_bytes() for n in sync.ARTIFACTS})
        with self.assertRaises(sync.PackError):
            sync.build(self.root, output, report, outputs)

    def test_duplicate_catalogue_rejected(self):
        self.catalogue(lambda rows: rows.append(rows[0]))
        with self.assertRaisesRegex(sync.PackError, "Duplicate"):
            sync.plan(self.root)

    def test_traversal_rejected(self):
        self.catalogue(lambda rows: rows[0].update(path="../Config.lua"))
        with self.assertRaises(sync.PackError):
            sync.plan(self.root)

    def test_class_mismatch_rejected(self):
        def edit(tree):
            next(iter(sync.index_scripts(tree).values())).set("class", "LocalScript")
        self.edit_xml(edit)
        with self.assertRaisesRegex(sync.PackError, "wrong class"):
            sync.plan(self.root)

    def test_missing_source_rejected(self):
        (self.root / "Schema.lua").unlink()
        with self.assertRaisesRegex(sync.PackError, "Missing source"):
            sync.plan(self.root)

    def test_missing_script_rejected(self):
        self.edit_xml(lambda tree: sync.property_node(next(iter(sync.index_scripts(tree).values())), "string", "Name").__setattr__("text", "WrongName"))
        with self.assertRaisesRegex(sync.PackError, "layout mismatch"):
            sync.plan(self.root)

    def test_duplicate_instance_rejected(self):
        def edit(tree):
            item = next(iter(sync.index_scripts(tree).values()))
            for parent in tree.getroot().iter("Item"):
                if item in list(parent):
                    parent.append(ET.fromstring(ET.tostring(item)))
                    break
        self.edit_xml(edit)
        with self.assertRaisesRegex(sync.PackError, "Duplicate script"):
            sync.plan(self.root)

    def test_ambiguous_source_property_rejected(self):
        def edit(tree):
            item = next(iter(sync.index_scripts(tree).values()))
            ET.SubElement(item.find("Properties"), "ProtectedString", name="Source")
        self.edit_xml(edit)
        with self.assertRaisesRegex(sync.PackError, "Expected one Source"):
            sync.plan(self.root)

    def test_flat_nested_conflict_rejected(self):
        nested = self.root / "ReplicatedStorage/SaveMenuPack/Config.lua"
        nested.parent.mkdir(parents=True)
        nested.write_text("different", encoding="utf-8")
        with self.assertRaisesRegex(sync.PackError, "Conflicting"):
            sync.plan(self.root)

    def test_nested_release_layout_supported(self):
        for row in json.loads((self.root / "catalogue.json").read_text()):
            nested = self.root / row["path"]
            nested.parent.mkdir(parents=True, exist_ok=True)
            (self.root / row["name"]).rename(nested)
        self.assertEqual(sync.plan(self.root)[0]["drift_count"], 0)

    def test_entities_and_invalid_xml_rejected(self):
        for raw in (b'<!DOCTYPE roblox [<!ENTITY x "y">]><roblox version="4"/>', b"<broken", b'<roblox version="3"/>'):
            with self.subTest(raw=raw), self.assertRaises((sync.PackError, ET.ParseError)):
                sync.parse_xml(raw)

    def test_control_characters_rejected(self):
        (self.root / "Config.lua").write_bytes(b"return '\x00'")
        with self.assertRaisesRegex(sync.PackError, "control character"):
            sync.plan(self.root)

    def test_cli_exit_codes(self):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(sync.main(["check", "--root", str(self.root), "--json"]), 0)
            (self.root / "Config.lua").write_text("return {}\n", encoding="utf-8")
            self.assertEqual(sync.main(["check", "--root", str(self.root)]), 1)
            self.assertEqual(sync.main(["build", "--root", str(self.root), "--output-dir", str(self.root)]), 2)
            (self.root / "Config.lua").unlink()
            self.assertEqual(sync.main(["check", "--root", str(self.root)]), 2)


if __name__ == "__main__":
    unittest.main()
