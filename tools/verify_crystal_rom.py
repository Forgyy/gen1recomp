#!/usr/bin/env python3
"""Verify Crystal v1.0 against the checked-in Gen 2 metadata manifest."""

from __future__ import annotations

import argparse
import hashlib
import json


BANK_SIZE = 0x4000


def offset(bank, address):
    if bank == 0:
        if not 0 <= address < BANK_SIZE:
            raise ValueError(f"invalid ROM0 address {bank:02x}:{address:04x}")
        return address
    if not BANK_SIZE <= address < BANK_SIZE * 2:
        raise ValueError(f"invalid ROMX address {bank:02x}:{address:04x}")
    return bank * BANK_SIZE + address - BANK_SIZE


def byte(rom, bank, address):
    return rom[offset(bank, address)]


def word(rom, bank, address):
    position = offset(bank, address)
    return rom[position] | rom[position + 1] << 8


def verify(rom, manifest):
    expected_size = manifest["romBytes"]
    if len(rom) != expected_size:
        raise ValueError(f"ROM is {len(rom)} bytes; expected {expected_size}")
    actual_hash = hashlib.sha1(rom).hexdigest()
    if actual_hash != manifest["romSha1"]:
        raise ValueError(
            f"ROM SHA-1 is {actual_hash}; expected {manifest['romSha1']}")

    symbols = manifest["symbols"]
    group_bank, group_address = symbols["MapGroupPointers"]
    for spec in manifest["maps"]:
        label = spec["label"]
        attributes = symbols[label + "_MapAttributes"]
        blocks = symbols[label + "_Blocks"]
        scripts = symbols[label + "_MapScripts"]
        events = symbols[label + "_MapEvents"]

        group_pointer = word(
            rom, group_bank, group_address + (spec["groupId"] - 1) * 2)
        header = group_pointer + (spec["mapId"] - 1) * 9
        if (byte(rom, group_bank, header) != attributes[0]
                or word(rom, group_bank, header + 3) != attributes[1]):
            raise ValueError(f"{spec['id']}: map header attributes mismatch")

        bank, address = attributes
        if byte(rom, bank, address + 1) != spec["height"] \
                or byte(rom, bank, address + 2) != spec["width"]:
            raise ValueError(f"{spec['id']}: map dimensions mismatch")
        if byte(rom, bank, address + 3) != blocks[0] \
                or word(rom, bank, address + 4) != blocks[1]:
            raise ValueError(f"{spec['id']}: block pointer mismatch")
        if byte(rom, bank, address + 6) != scripts[0] \
                or word(rom, bank, address + 7) != scripts[1]:
            raise ValueError(f"{spec['id']}: script pointer mismatch")
        if scripts[0] != events[0] or word(rom, bank, address + 9) != events[1]:
            raise ValueError(f"{spec['id']}: event pointer mismatch")

    return actual_hash, len(manifest["maps"]), len(symbols)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", required=True)
    parser.add_argument(
        "--manifest", default="tools/gen2/rom_manifest_crystal.json")
    args = parser.parse_args()

    with open(args.rom, "rb") as source:
        rom = source.read()
    with open(args.manifest, encoding="utf-8") as source:
        manifest = json.load(source)
    actual_hash, map_count, symbol_count = verify(rom, manifest)
    print(f"verified Crystal v1.0: {actual_hash}")
    print(f"map pointer chains: {map_count}")
    print(f"manifest symbols: {symbol_count}")


if __name__ == "__main__":
    main()
