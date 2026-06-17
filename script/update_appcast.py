#!/usr/bin/env python3
import argparse
import datetime as dt
import email.utils
import pathlib
import xml.dom.minidom
import xml.etree.ElementTree as ET

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE_NS)


def sparkle(name: str) -> str:
    return f"{{{SPARKLE_NS}}}{name}"


def add_text(parent: ET.Element, tag: str, text: str) -> ET.Element:
    child = ET.SubElement(parent, tag)
    child.text = text
    return child


def default_pub_date() -> str:
    now = dt.datetime.now(dt.timezone.utc)
    return email.utils.format_datetime(now, usegmt=True)


def load_or_create_appcast(path: pathlib.Path) -> tuple[ET.ElementTree, ET.Element]:
    if path.exists() and path.read_text(encoding="utf-8").strip():
        tree = ET.parse(path)
        root = tree.getroot()
    else:
        root = ET.Element("rss", {"version": "2.0"})
        tree = ET.ElementTree(root)

    if root.tag != "rss":
        raise ValueError(f"Expected rss root in {path}")

    root.set("version", root.get("version", "2.0"))
    channel = root.find("channel")
    if channel is None:
        channel = ET.SubElement(root, "channel")

    ensure_channel_metadata(channel)
    return tree, channel


def ensure_channel_metadata(channel: ET.Element) -> None:
    defaults = [
        ("title", "Reader 更新"),
        ("link", "https://github.com/can4hou6joeng4/ReaderMacApp/releases"),
        ("description", "Reader macOS app updates"),
        ("language", "zh-CN"),
    ]

    insert_at = 0
    for tag, value in defaults:
        existing = channel.find(tag)
        if existing is None:
            element = ET.Element(tag)
            element.text = value
            channel.insert(insert_at, element)
            insert_at += 1


def remove_duplicate_items(channel: ET.Element, version: str, short_version: str) -> None:
    for item in list(channel.findall("item")):
        item_version = item.findtext(sparkle("version"))
        item_short_version = item.findtext(sparkle("shortVersionString"))
        if item_version == version or item_short_version == short_version:
            channel.remove(item)


def build_item(args: argparse.Namespace) -> ET.Element:
    item = ET.Element("item")
    add_text(item, "title", args.title or f"Reader {args.short_version}")
    add_text(item, sparkle("version"), args.version)
    add_text(item, sparkle("shortVersionString"), args.short_version)
    add_text(item, sparkle("minimumSystemVersion"), args.minimum_system_version)
    add_text(item, "pubDate", args.pub_date or default_pub_date())
    add_text(item, "link", args.release_notes_url)
    add_text(item, sparkle("releaseNotesLink"), args.release_notes_url)
    ET.SubElement(
        item,
        "enclosure",
        {
            "url": args.dmg_url,
            sparkle("edSignature"): args.ed_signature,
            "length": args.length,
            "type": "application/octet-stream",
        },
    )
    return item


def insert_latest_item(channel: ET.Element, item: ET.Element) -> None:
    children = list(channel)
    first_item_index = next((index for index, child in enumerate(children) if child.tag == "item"), None)
    if first_item_index is None:
        channel.append(item)
    else:
        channel.insert(first_item_index, item)


def write_pretty_xml(tree: ET.ElementTree, path: pathlib.Path) -> None:
    raw_xml = ET.tostring(tree.getroot(), encoding="utf-8")
    pretty = xml.dom.minidom.parseString(raw_xml).toprettyxml(indent="  ", encoding="utf-8")
    lines = [line for line in pretty.decode("utf-8").splitlines() if line.strip()]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Add or replace one Sparkle appcast item.")
    parser.add_argument("--appcast", default="appcast.xml", type=pathlib.Path)
    parser.add_argument("--version", required=True, help="CFBundleVersion / sparkle:version")
    parser.add_argument("--short-version", required=True, help="CFBundleShortVersionString")
    parser.add_argument("--dmg-url", required=True)
    parser.add_argument("--ed-signature", required=True)
    parser.add_argument("--length", required=True)
    parser.add_argument("--release-notes-url", required=True)
    parser.add_argument("--minimum-system-version", default="13.0")
    parser.add_argument("--pub-date")
    parser.add_argument("--title")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    tree, channel = load_or_create_appcast(args.appcast)
    remove_duplicate_items(channel, args.version, args.short_version)
    insert_latest_item(channel, build_item(args))
    write_pretty_xml(tree, args.appcast)


if __name__ == "__main__":
    main()
