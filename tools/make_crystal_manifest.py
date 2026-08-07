#!/usr/bin/env python3
"""Build the non-ROM metadata foundation for Pokemon Crystal v1.0.

The output contains enum names, map dimensions/relationships, and selected
RGBDS symbol addresses. It contains no ROM bytes, graphics, dialogue, or audio.
"""

from __future__ import annotations

import argparse
import json
import os
import re


CANONICAL_CRYSTAL_SHA1 = "f4cd194bdee0d04ca4eac29e09b8e4e9d818c133"

CORE_SYMBOLS = (
    "BaseData",
    "Cries",
    "EvosAttacksPointers",
    "ItemAttributes",
    "ItemNames",
    "JohtoGrassWildMons",
    "JohtoWaterWildMons",
    "KantoGrassWildMons",
    "KantoWaterWildMons",
    "MapGroupPointers",
    "MoveNames",
    "Moves",
    "Music",
    "PokedexDataPointerTable",
    "PokemonNames",
    "PokemonPalettes",
    "PokemonPicPointers",
    "SFX",
    "Tilesets",
    "TrainerClassNames",
    "TrainerGroups",
    "TrainerPicPointers",
    "TypeMatchups",
    "TypeNames",
)


def asm_lines(path):
    with open(path, encoding="utf-8") as source:
        for raw in source:
            line = raw.split(";", 1)[0].strip()
            if line:
                yield line


def integer(token):
    token = token.strip()
    if token.startswith("$"):
        return int(token[1:], 16)
    return int(token, 10)


def constants(path, stop_at=None):
    value = 0
    result = []
    for line in asm_lines(path):
        if stop_at and re.match(rf"DEF\s+{re.escape(stop_at)}\b", line):
            break
        match = re.match(r"const_def(?:\s+([^\s]+))?$", line)
        if match:
            value = integer(match.group(1)) if match.group(1) else 0
            continue
        match = re.match(r"const_next\s+([^\s]+)$", line)
        if match:
            value = integer(match.group(1))
            continue
        match = re.match(r"const_skip(?:\s+([^\s]+))?$", line)
        if match:
            value += integer(match.group(1)) if match.group(1) else 1
            continue
        match = re.match(r"const\s+([A-Z][A-Z0-9_]*)", line)
        if match:
            result.append({"id": match.group(1), "value": value})
            value += 1
    return result


def trainer_classes(path):
    result = []
    current = None
    member_id = 1
    for line in asm_lines(path):
        if re.match(r"DEF\s+NUM_TRAINER_CLASSES\b", line):
            break
        match = re.match(r"trainerclass\s+([A-Z][A-Z0-9_]*)", line)
        if match:
            current = {
                "id": match.group(1),
                "value": len(result),
                "trainers": [],
            }
            result.append(current)
            member_id = 1
            continue
        match = re.match(r"const\s+([A-Z][A-Z0-9_]*)", line)
        if match and current:
            current["trainers"].append({"id": match.group(1), "value": member_id})
            member_id += 1
    return result


def map_constants(path):
    groups = []
    maps = []
    group_id = 0
    map_id = 0
    group_name = None
    for line in asm_lines(path):
        match = re.match(r"newgroup\s+([A-Z][A-Z0-9_]*)", line)
        if match:
            group_id += 1
            map_id = 0
            group_name = match.group(1)
            groups.append({"id": group_name, "value": group_id})
            continue
        match = re.match(
            r"map_const\s+([A-Z][A-Z0-9_]*),\s*(\d+),\s*(\d+)", line)
        if match:
            if not group_name:
                raise ValueError("map_const appeared before newgroup")
            map_id += 1
            maps.append({
                "id": match.group(1),
                "group": group_name,
                "groupId": group_id,
                "mapId": map_id,
                "width": int(match.group(2)),
                "height": int(match.group(3)),
            })
    return groups, maps


def map_headers(path):
    result = []
    for line in asm_lines(path):
        if not line.startswith("map "):
            continue
        fields = [part.strip() for part in line[4:].split(",")]
        if len(fields) != 8:
            raise ValueError(f"unexpected map header: {line}")
        result.append({
            "label": fields[0],
            "tileset": fields[1],
            "environment": fields[2],
            "landmark": fields[3],
            "music": fields[4],
            "phoneDisabled": fields[5],
            "palette": fields[6],
            "fishingGroup": fields[7],
        })
    return result


def symbol_table(path):
    result = {}
    with open(path, encoding="utf-8") as source:
        for raw in source:
            match = re.match(
                r"^([0-9a-fA-F]{2}):([0-9a-fA-F]{4})\s+(\S+)", raw)
            if match:
                result[match.group(3)] = [
                    int(match.group(1), 16), int(match.group(2), 16)]
    return result


def generate(pokecrystal, symbols_path):
    const_dir = os.path.join(pokecrystal, "constants")
    groups, maps = map_constants(os.path.join(const_dir, "map_constants.asm"))
    headers = map_headers(os.path.join(pokecrystal, "data/maps/maps.asm"))
    if len(maps) != len(headers):
        raise ValueError(
            f"map constants/header count mismatch: {len(maps)} != {len(headers)}")

    symbols = symbol_table(symbols_path)
    selected = {}
    missing = []
    for name in CORE_SYMBOLS:
        location = symbols.get(name)
        if location is None:
            missing.append(name)
        else:
            selected[name] = location

    for spec, header in zip(maps, headers):
        spec.update(header)
        for suffix in ("_MapAttributes", "_Blocks", "_MapScripts", "_MapEvents"):
            name = header["label"] + suffix
            location = symbols.get(name)
            if location is None:
                missing.append(name)
            else:
                selected[name] = location

    if missing:
        shown = ", ".join(missing[:20])
        extra = " ..." if len(missing) > 20 else ""
        raise ValueError(f"symbol file is missing: {shown}{extra}")

    return {
        "format": 3,
        "generation": 2,
        "game": "crystal",
        "romRevision": "v1.0",
        "romSha1": CANONICAL_CRYSTAL_SHA1,
        "romBytes": 2 * 1024 * 1024,
        "source": "pret/pokecrystal",
        "constants": {
            "species": constants(os.path.join(const_dir, "pokemon_constants.asm"),
                                 "NUM_POKEMON"),
            "moves": constants(os.path.join(const_dir, "move_constants.asm"),
                               "NUM_ATTACKS"),
            "items": constants(os.path.join(const_dir, "item_constants.asm"),
                               "NUM_ITEMS"),
            "types": constants(os.path.join(const_dir, "type_constants.asm")),
            "tilesets": constants(os.path.join(const_dir, "tileset_constants.asm"),
                                  "NUM_TILESETS"),
            "trainerClasses": trainer_classes(
                os.path.join(const_dir, "trainer_constants.asm")),
            "mapGroups": groups,
        },
        "maps": maps,
        "symbols": selected,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pokecrystal", required=True)
    parser.add_argument("--symbols", required=True)
    parser.add_argument(
        "--out", default=os.path.join(
            os.path.dirname(__file__), "gen2", "rom_manifest_crystal.json"))
    args = parser.parse_args()

    pokecrystal = os.path.abspath(args.pokecrystal)
    if not os.path.isfile(os.path.join(pokecrystal, "main.asm")):
        raise SystemExit(f"{pokecrystal} is not a pokecrystal checkout")
    data = generate(pokecrystal, os.path.abspath(args.symbols))
    out = os.path.abspath(args.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8", newline="\n") as target:
        json.dump(data, target, ensure_ascii=False, indent=2, sort_keys=True)
        target.write("\n")
    print(f"wrote {out}")
    print(f"maps: {len(data['maps'])}")
    print(f"symbols: {len(data['symbols'])}")


if __name__ == "__main__":
    main()
