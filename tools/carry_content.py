#!/usr/bin/env python3
"""Carry the tier-6 crop/crux/farmland slice of Mystical Agradditions 8.0.15.

The jar is the ATM10 one (SHA-1 `be6e652d…000c`, SHA-256 `8876b360…f01e`,
`license="MIT"`), kept in `ports/_shared/carry-work/mysticalagradditions/`
together with `SOURCE.md`. Asset bytes are copied verbatim; the few data files
26.3 spells differently (item definitions, recipes, loot, tags) are written
from the jar's own values, and the block/item declarations name vanilla
templates. The shared crop-stage and infused-farmland models come from the
parent Mystical Agriculture jar (MIT) because the add-on's blockstates name
them in the parent's namespace, which our `.hmod` may not own.

Run: python3 tools/carry_content.py [--jar PATH] [--parent-jar PATH] [--check]
  --check  compare the files on disk with what the carry would write, exit 1
           on a difference (no writes).
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_JAR = (
    ROOT.parent / "_shared/carry-work/mysticalagradditions"
    / "MysticalAgradditions-1.21.1-8.0.15.jar"
)
DEFAULT_PARENT_JAR = (
    ROOT.parent / "_shared/carry-work/mysticalagriculture"
    / "MysticalAgriculture-1.21.1-8.0.29.jar"
)
JAR_SHA1 = "be6e652de107065342aa3f98945cc5b0b3fa000c"
JAR_SHA256 = "8876b360dedf006cd3bff26719fccc4b148d626fb8be1e7f5e427107826fb01e"
PARENT_JAR_SHA1 = "4a774506f65899683aa40b92fec972ddcc4fdc4f"
MOD = "mysticalagradditions"
MAX_AGE = 7

# `ModCrops`' six tier-6 crops, in registration order.
CROPS = [
    "nether_star",
    "dragon_egg",
    "gaia_spirit",
    "awakened_draconium",
    "neutronium",
    "nitro_crystal",
]

TITLES = {
    "nether_star": "Nether Star",
    "dragon_egg": "Dragon Egg",
    "gaia_spirit": "Gaia Spirit",
    "awakened_draconium": "Awakened Draconium",
    "neutronium": "Neutronium",
    "nitro_crystal": "Nitro Crystal",
}

# Item models the add-on jar ships in our own namespace, copied verbatim.
OWN_ITEM_MODELS = [
    "insanium_essence",
    "dragon_scale",
    "withering_soul",
    *(f"{crop}_crux" for crop in CROPS),
]

# `ModBlocks`: `BaseBlock(SoundType.STONE, 5.0F, 10.0F)` and the jar's
# `mineable/pickaxe` + `needs_stone_tool` tags.
CRUX_BLOCK = {
    "template": "minecraft:stone",
    "properties": {
        "hardness": 5.0,
        "explosion_resistance": 10.0,
        "sounds": "minecraft:stone",
        "requires_tool": True,
    },
    "item": True,
}

CROP_BLOCK = {
    "template": "minecraft:wheat",
    "item": False,
    "properties": {"hardness": 0.0},
    # MysticalCropBlock.SHAPE: a 4-pixel-high box for every age, no collision.
    "shapes": {"default": [[0.0, 0.0, 0.0, 1.0, 0.25, 1.0]]},
    "collision_shapes": {"default": []},
}

# `InfusedFarmlandBlock extends FarmBlock` with `Properties.ofFullCopy(FARMLAND)`.
FARMLAND_BLOCK = {"template": "minecraft:farmland", "item": True}

ITEM_DECLS = {
    **{
        f"{crop}_seeds": {
            "template": "minecraft:stick",
            "place_block": f"{MOD}:{crop}_crop",
        }
        for crop in CROPS
    },
    **{f"{crop}_essence": {"template": "minecraft:iron_nugget"} for crop in CROPS},
    "insanium_essence": {"template": "minecraft:iron_nugget"},
    "dragon_scale": {"template": "minecraft:iron_nugget"},
    "withering_soul": {"template": "minecraft:iron_nugget"},
}

# The two families whose seed material exists here (vanilla nether star, and
# the add-on's own dragon scale, a carried recipe item). The other four name
# botania/avaritia/draconicevolution/powah and are gaps.
SEED_MATERIALS = {
    "nether_star": "minecraft:nether_star",
    "dragon_egg": f"{MOD}:dragon_scale",
}

# The two crux recipes whose materials exist here; the other four are gaps.
CRUX_RECIPES = {
    "nether_star_crux": {
        "pattern": ["ESE", "WDW", "ESE"],
        "key": {
            "E": f"{MOD}:insanium_essence",
            "S": "minecraft:nether_star",
            "W": f"{MOD}:withering_soul",
            "D": "#c:storage_blocks/diamond",
        },
    },
    "dragon_egg_crux": {
        "pattern": ["ECE", "CDC", "ECE"],
        "key": {
            "E": f"{MOD}:insanium_essence",
            "C": f"{MOD}:dragon_scale",
            "D": "#c:storage_blocks/diamond",
        },
    },
}

MANIFEST = f"""\
# Port-owned content mod for the Mystical Agradditions 1.21.1-8.0.15 slice: the
# six tier-6 crops (crop, seeds, essence), their six cruxes, insanium essence
# and insanium farmland. Textures/models are the upstream mod's own MIT assets
# from the exact ATM10 jar (see ../SOURCE.md); the shared crop-stage models are
# the parent Mystical Agriculture's (also MIT). Local-only until publishing is
# approved (see ../LICENSE and ../notes.md).
id = "{MOD}"
name = "Mystical Agradditions"
version = "0.1.0"
description = "Slice 1: the six tier-6 crops, their cruxes and insanium farmland"
authors = ["BlakeBr0"]
api = "0.2"
side = "both"
capabilities = ["registries"]
"""


def _json(value: object) -> bytes:
    return (json.dumps(value, indent=2) + "\n").encode()


def _rewrite_namespace(text: str) -> str:
    """Point a parent-namespace path into our own; the files are byte-equal otherwise."""
    return text.replace("mysticalagriculture:", f"{MOD}:")


def _loot_crop(name: str) -> dict:
    """`MysticalCropBlock.getDrops` for tier 6 (no secondary roll)."""
    block = f"{MOD}:{name}_crop"
    ripe = {
        "type": "minecraft:match_block",
        "blocks": block,
        "state": {"age": str(MAX_AGE)},
    }
    return {
        "type": "minecraft:block",
        "random_sequence": f"{MOD}:blocks/{name}_crop",
        "pools": [
            {
                "rolls": 1,
                "entries": [
                    {
                        "type": "minecraft:alternatives",
                        "children": [
                            {
                                "type": "minecraft:item",
                                "condition": ripe,
                                "name": f"{MOD}:{name}_essence",
                            },
                            {"type": "minecraft:item", "name": f"{MOD}:{name}_seeds"},
                        ],
                    }
                ],
            },
            {
                "rolls": 1,
                "condition": {
                    "type": "minecraft:match_block",
                    "blocks": block,
                    "state": {"age": str(MAX_AGE)},
                },
                "entries": [
                    {"type": "minecraft:item", "name": f"{MOD}:{name}_seeds"}
                ],
            },
        ],
    }


def _loot_crux(name: str) -> dict:
    return {
        "type": "minecraft:block",
        "pools": [
            {
                "rolls": 1,
                "condition": {"type": "minecraft:survives_explosion"},
                "entries": [{"type": "minecraft:item", "name": f"{MOD}:{name}"}],
            }
        ],
    }


def _loot_farmland() -> dict:
    """`InfusedFarmlandBlock.getDrops`: silk keeps it, else dirt + 25% essence."""
    return {
        "type": "minecraft:block",
        "random_sequence": f"{MOD}:blocks/insanium_farmland",
        "pools": [
            {
                "rolls": 1,
                "entries": [
                    {
                        "type": "minecraft:alternatives",
                        "children": [
                            {
                                "type": "minecraft:item",
                                "condition": "minecraft:tool/can_silk_touch",
                                "name": f"{MOD}:insanium_farmland",
                            },
                            {"type": "minecraft:item", "name": "minecraft:dirt"},
                        ],
                    }
                ],
            },
            {
                "rolls": 1,
                "condition": {
                    "type": "minecraft:inverted",
                    "term": "minecraft:tool/can_silk_touch",
                },
                "entries": [
                    {
                        "type": "minecraft:item",
                        "condition": {"type": "minecraft:random_chance", "chance": 0.25},
                        "name": f"{MOD}:insanium_essence",
                    }
                ],
            },
        ],
    }


def _seed_recipe(crop: str, material: str) -> dict:
    """The jar's `MEM/ESE/MEM` seed recipe, with the custom seed component
    replaced by vanilla wheat seeds (the base seed the parent port uses)."""
    return {
        "type": "minecraft:crafting_shaped",
        "group": f"{MOD}:seeds",
        "pattern": ["MEM", "ESE", "MEM"],
        "key": {
            "M": material,
            "E": f"{MOD}:{crop}_essence",
            "S": "minecraft:wheat_seeds",
        },
        "result": {"id": f"{MOD}:{crop}_seeds", "count": 1},
    }


def _crux_recipe(name: str, spec: dict) -> dict:
    return {
        "type": "minecraft:crafting_shaped",
        "group": f"{MOD}:cruxes",
        "pattern": spec["pattern"],
        "key": spec["key"],
        "result": {"id": f"{MOD}:{name}", "count": 1},
    }


def _tag(values: list[str]) -> bytes:
    return _json({"replace": False, "values": values})


def generated() -> dict[str, bytes]:
    """Every file the carry writes beyond the verbatim jar bytes."""
    files: dict[str, bytes] = {}
    files["content/horizon-mod.toml"] = MANIFEST.encode()

    # 26.3 item definitions (1.21.4 moved `models/item` to `items/`).
    item_models = [
        *[f"{crop}_seeds" for crop in CROPS],
        *[f"{crop}_essence" for crop in CROPS],
        *[f"{crop}_crux" for crop in CROPS],
        "insanium_essence",
        "insanium_farmland",
        "dragon_scale",
        "withering_soul",
    ]
    for item in item_models:
        files[f"content/assets/{MOD}/items/{item}.json"] = _json(
            {"model": {"type": "minecraft:model", "model": f"{MOD}:item/{item}"}}
        )

    lang = {
        f"itemGroup.{MOD}": "Mystical Agradditions",
        f"block.{MOD}.insanium_farmland": "Insanium Farmland",
        f"item.{MOD}.insanium_essence": "Insanium Essence",
        f"item.{MOD}.dragon_scale": "Dragon Scale",
        f"item.{MOD}.withering_soul": "Withering Soul",
        f"cropTier.{MOD}.6": "6",
    }
    for crop in CROPS:
        title = TITLES[crop]
        lang[f"block.{MOD}.{crop}_crop"] = f"{title} Crop"
        lang[f"block.{MOD}.{crop}_crux"] = f"{title} Crux"
        lang[f"item.{MOD}.{crop}_seeds"] = f"{title} Seeds"
        lang[f"item.{MOD}.{crop}_essence"] = f"{title} Essence"
        lang[f"crop.{MOD}.{crop}"] = title
    files[f"content/assets/{MOD}/lang/en_us.json"] = _json(lang)

    for crop in CROPS:
        files[f"content/data/{MOD}/horizon/block/{crop}_crop.json"] = _json(CROP_BLOCK)
        files[f"content/data/{MOD}/horizon/block/{crop}_crux.json"] = _json(CRUX_BLOCK)
        files[f"content/data/{MOD}/loot_table/blocks/{crop}_crop.json"] = _json(
            _loot_crop(crop)
        )
        files[f"content/data/{MOD}/loot_table/blocks/{crop}_crux.json"] = _json(
            _loot_crux(f"{crop}_crux")
        )
    files[f"content/data/{MOD}/horizon/block/insanium_farmland.json"] = _json(
        FARMLAND_BLOCK
    )
    files[f"content/data/{MOD}/loot_table/blocks/insanium_farmland.json"] = _json(
        _loot_farmland()
    )

    for item, decl in ITEM_DECLS.items():
        files[f"content/data/{MOD}/horizon/item/{item}.json"] = _json(decl)

    for crop, material in SEED_MATERIALS.items():
        files[f"content/data/{MOD}/recipe/{crop}_seeds.json"] = _json(
            _seed_recipe(crop, material)
        )
    for name, spec in CRUX_RECIPES.items():
        files[f"content/data/{MOD}/recipe/{name}.json"] = _json(_crux_recipe(name, spec))
    files[f"content/data/{MOD}/recipe/insanium_farmland.json"] = _json(
        {
            "type": "minecraft:crafting_shapeless",
            "group": "mysticalagriculture:farmland",
            "ingredients": [f"{MOD}:insanium_essence", "minecraft:farmland"],
            "result": {"id": f"{MOD}:insanium_farmland", "count": 1},
        }
    )

    cruxes = [f"{MOD}:{crop}_crux" for crop in CROPS]
    files["content/data/c/tags/item/storage_blocks/diamond.json"] = _tag(
        ["minecraft:diamond_block"]
    )
    files["content/data/minecraft/tags/block/supports_crops.json"] = _tag(
        [f"{MOD}:insanium_farmland"]
    )
    files["content/data/minecraft/tags/block/grows_crops.json"] = _tag(
        [f"{MOD}:insanium_farmland"]
    )
    files["content/data/minecraft/tags/block/mineable/shovel.json"] = _tag(
        [f"{MOD}:insanium_farmland"]
    )
    files["content/data/minecraft/tags/block/mineable/pickaxe.json"] = _tag(cruxes)
    files["content/data/minecraft/tags/block/needs_stone_tool.json"] = _tag(cruxes)
    return files


def verbatim(addon: zipfile.ZipFile, parent: zipfile.ZipFile) -> dict[str, bytes]:
    """Jar bytes copied as they are, plus the namespace-rewritten models."""
    files: dict[str, bytes] = {}

    def copy(jar: zipfile.ZipFile, source: str, target: str | None = None) -> None:
        files[f"content/{target or source}"] = jar.read(source)

    def rewrite(jar: zipfile.ZipFile, source: str, target: str) -> None:
        text = jar.read(source).decode()
        files[f"content/{target}"] = _rewrite_namespace(text).encode()

    for crop in CROPS:
        copy(
            addon,
            f"assets/{MOD}/textures/block/{crop}_crux.png",
            f"assets/{MOD}/textures/block/{crop}_crux.png",
        )
        copy(
            addon,
            f"assets/{MOD}/textures/block/flower/{crop}_flower.png",
        )
        crop_animation = f"assets/{MOD}/textures/block/flower/{crop}_flower.png.mcmeta"
        if crop_animation in addon.namelist():
            copy(addon, crop_animation)
        copy(
            addon,
            f"assets/{MOD}/textures/item/essence/{crop}_essence.png",
        )
        essence_animation = (
            f"assets/{MOD}/textures/item/essence/{crop}_essence.png.mcmeta"
        )
        if essence_animation in addon.namelist():
            copy(addon, essence_animation)
        copy(addon, f"assets/{MOD}/textures/item/seeds/{crop}_seeds.png")
        seeds_animation = f"assets/{MOD}/textures/item/seeds/{crop}_seeds.png.mcmeta"
        if seeds_animation in addon.namelist():
            copy(addon, seeds_animation)

        # Crux model/blockstate serve the block item as they are.
        copy(addon, f"assets/{MOD}/blockstates/{crop}_crux.json")
        copy(addon, f"assets/{MOD}/models/block/{crop}_crux.json")
        copy(addon, f"assets/{MOD}/models/item/{crop}_crux.json")

        # Crop blockstate + age-7 model, re-pointed from the parent's namespace.
        rewrite(
            addon,
            f"assets/mysticalagriculture/blockstates/{crop}_crop.json",
            f"assets/{MOD}/blockstates/{crop}_crop.json",
        )
        rewrite(
            addon,
            f"assets/mysticalagriculture/models/block/{crop}_crop.json",
            f"assets/{MOD}/models/block/{crop}_crop.json",
        )
        # Seed/essence item models live in the parent's namespace in the jar.
        rewrite(
            addon,
            f"assets/mysticalagriculture/models/item/{crop}_seeds.json",
            f"assets/{MOD}/models/item/{crop}_seeds.json",
        )
        rewrite(
            addon,
            f"assets/mysticalagriculture/models/item/{crop}_essence.json",
            f"assets/{MOD}/models/item/{crop}_essence.json",
        )

    for item in OWN_ITEM_MODELS:
        copy(addon, f"assets/{MOD}/models/item/{item}.json")

    copy(addon, f"assets/{MOD}/textures/item/insanium_essence.png")
    copy(addon, f"assets/{MOD}/textures/item/dragon_scale.png")
    copy(addon, f"assets/{MOD}/textures/item/withering_soul.png")
    rewrite(
        addon,
        f"assets/{MOD}/models/item/insanium_farmland.json",
        f"assets/{MOD}/models/item/insanium_farmland.json",
    )
    rewrite(
        addon,
        f"assets/{MOD}/blockstates/insanium_farmland.json",
        f"assets/{MOD}/blockstates/insanium_farmland.json",
    )

    # The parent's shared stage models/textures and the infused-farmland models
    # the add-on's blockstates name (MIT, parent jar).
    for age in range(8):
        rewrite(
            parent,
            f"assets/mysticalagriculture/models/block/mystical_resource_crop_{age}.json",
            f"assets/{MOD}/models/block/mystical_resource_crop_{age}.json",
        )
        copy(
            parent,
            f"assets/mysticalagriculture/textures/block/mystical_resource_crop_{age}.png",
            f"assets/{MOD}/textures/block/mystical_resource_crop_{age}.png",
        )
    rewrite(
        parent,
        "assets/mysticalagriculture/models/block/infused_farmland.json",
        f"assets/{MOD}/models/block/infused_farmland.json",
    )
    rewrite(
        parent,
        "assets/mysticalagriculture/models/block/infused_farmland_moist.json",
        f"assets/{MOD}/models/block/infused_farmland_moist.json",
    )
    return files


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--jar", type=Path, default=DEFAULT_JAR)
    parser.add_argument("--parent-jar", type=Path, default=DEFAULT_PARENT_JAR)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    data = args.jar.read_bytes()
    digest = hashlib.sha1(data).hexdigest()
    if digest != JAR_SHA1:
        print(f"{args.jar}: SHA-1 {digest} is not the ATM10 file {JAR_SHA1}", file=sys.stderr)
        return 1
    if hashlib.sha256(data).hexdigest() != JAR_SHA256:
        print(f"{args.jar}: SHA-256 differs from the recorded ATM10 file", file=sys.stderr)
        return 1
    parent_digest = hashlib.sha1(args.parent_jar.read_bytes()).hexdigest()
    if parent_digest != PARENT_JAR_SHA1:
        print(
            f"{args.parent_jar}: SHA-1 {parent_digest} is not the parent 8.0.29 file "
            f"{PARENT_JAR_SHA1} (the shared crop-stage/farmland models come from it)",
            file=sys.stderr,
        )
        return 1

    wanted = generated()
    with zipfile.ZipFile(args.jar) as addon, zipfile.ZipFile(args.parent_jar) as parent:
        wanted.update(verbatim(addon, parent))

    changed = 0
    for name, content in sorted(wanted.items()):
        path = ROOT / name
        current = path.read_bytes() if path.exists() else None
        if current == content:
            continue
        changed += 1
        print(("would write " if args.check else "write ") + name)
        if not args.check:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)

    print(
        f"{len(wanted)} files, {changed} {'pending' if args.check else 'written'}"
        f" (addon sha1 {digest})"
    )
    return 1 if args.check and changed else 0


if __name__ == "__main__":
    raise SystemExit(main())
