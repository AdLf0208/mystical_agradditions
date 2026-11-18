#!/usr/bin/env python3
"""Craft the carried tier-6 recipes in a real crafting table.

Called by tools/e2e.sh with the open game's control socket. The harness's
crafting grid is slots 100-108 row-major, result 200 (`ctl screen`). Cases:

  1. shaped `nether_star_seeds` (MEM/ESE/MEM: 4 nether star, 4 nether-star
     essence, 1 wheat seed) -> `mysticalagradditions:nether_star_seeds` x1;
  2. its control: a stick in the centre -> empty result;
  3. shaped `nether_star_crux` (ESE/WDW/ESE: 4 insanium essence, 1 nether
     star, 2 withering soul, 1 diamond block) -> the crux;
  4. its control: dirt instead of the diamond block -> empty result;
  5. shaped `dragon_egg_crux` (ECE/CDC/ECE: 4 insanium essence, 4 dragon
     scale, 1 diamond block) -> the crux;
  6. shapeless `insanium_farmland` (insanium essence + farmland) -> farmland;
  7. its control: dirt instead of farmland -> empty result.

Exits 1 on the first mismatch.
"""
import json
import subprocess
import sys


def main():
    sock, ctl, x, y, z = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]

    def run(*args):
        out = subprocess.run([ctl, "--socket", sock, *args], text=True,
                             capture_output=True)
        try:
            return json.loads(out.stdout)
        except json.JSONDecodeError:
            raise SystemExit(f"ctl {' '.join(args)}: {out.stdout}{out.stderr}")

    def wait(ticks=4):
        run("wait", str(ticks))

    def slots():
        screen = run("screen")
        if "slots" not in screen:
            raise SystemExit(f"no menu is open: {screen}")
        return screen["slots"]

    def find(item):
        for slot in slots():
            if slot.get("item") == item:
                return slot["slot"]
        raise SystemExit(f"missing ingredient {item} in the inventory")

    def setup(items):
        try:
            run("close")
        except SystemExit:
            pass
        wait(5)
        run("setblock", x, y, z, "minecraft:air")
        run("setblock", x, y, z, "minecraft:crafting_table")
        wait(2)
        run("command", f"tp @s {float(x) - 0.5} {y} {float(z) + 0.5}")
        wait(3)
        run("command", "clear @s")
        for item, count in items:
            run("give", item, str(count))
        wait(3)
        run("interact", x, y, z)
        wait(5)

    def result():
        stack = [s for s in slots() if s["slot"] == 200]
        if not stack or not stack[0].get("item"):
            return None
        return stack[0]

    def place(item, targets):
        slot = find(item)
        run("click-slot", str(slot))
        wait(1)
        for target in targets:
            run("click-slot", str(target), "right")
            wait(1)
        run("click-slot", str(slot))
        wait(2)

    failures = []

    def check(label, items, placements, want_item, want_count, take=False):
        setup(items)
        for item, targets in placements:
            place(item, targets)
        got = result()
        print(f"{label} ->", json.dumps(got))
        if not got or got.get("item") != want_item or got.get("count") != want_count:
            failures.append(f"{label}: expected {want_count} {want_item}, got {got}")
            return
        if take:
            run("click-slot", "200")
            wait(5)
            run("click-slot", "9")
            wait(3)
            made = run("inventory")["counts"].get(want_item, 0)
            if made < want_count:
                failures.append(
                    f"{label}: the crafted stack reached the inventory as {made}")

    def empty_control(label, items, placements):
        setup(items)
        for item, targets in placements:
            place(item, targets)
        got = result()
        print(f"{label} ->", json.dumps(got))
        if got is not None:
            failures.append(f"{label}: control crafted {got['item']}")

    MOD = "mysticalagradditions"
    corners = ["100", "102", "106", "108"]
    edges = ["101", "103", "105", "107"]

    check(
        "4 nether star + 4 essence + 1 wheat seed -> nether_star_seeds",
        [("minecraft:nether_star", 4), (f"{MOD}:nether_star_essence", 4),
         ("minecraft:wheat_seeds", 1)],
        [
            ("minecraft:nether_star", corners),
            (f"{MOD}:nether_star_essence", edges),
            ("minecraft:wheat_seeds", ["104"]),
        ],
        f"{MOD}:nether_star_seeds",
        1,
        take=True,
    )
    empty_control(
        "4 nether star + 4 essence + 1 stick -> nothing",
        [("minecraft:nether_star", 4), (f"{MOD}:nether_star_essence", 4),
         ("minecraft:stick", 1)],
        [
            ("minecraft:nether_star", corners),
            (f"{MOD}:nether_star_essence", edges),
            ("minecraft:stick", ["104"]),
        ],
    )
    check(
        "4 insanium essence + 2 nether star + 2 withering soul + diamond block -> nether_star_crux",
        [(f"{MOD}:insanium_essence", 4), ("minecraft:nether_star", 2),
         (f"{MOD}:withering_soul", 2), ("minecraft:diamond_block", 1)],
        [
            (f"{MOD}:insanium_essence", ["100", "102", "106", "108"]),
            ("minecraft:nether_star", ["101", "107"]),
            (f"{MOD}:withering_soul", ["103", "105"]),
            ("minecraft:diamond_block", ["104"]),
        ],
        f"{MOD}:nether_star_crux",
        1,
        take=True,
    )
    empty_control(
        "the same crux with dirt instead of the diamond block -> nothing",
        [(f"{MOD}:insanium_essence", 4), ("minecraft:nether_star", 2),
         (f"{MOD}:withering_soul", 2), ("minecraft:dirt", 1)],
        [
            (f"{MOD}:insanium_essence", ["100", "102", "106", "108"]),
            ("minecraft:nether_star", ["101", "107"]),
            (f"{MOD}:withering_soul", ["103", "105"]),
            ("minecraft:dirt", ["104"]),
        ],
    )
    check(
        "4 insanium essence + 4 dragon scale + diamond block -> dragon_egg_crux",
        [(f"{MOD}:insanium_essence", 4), (f"{MOD}:dragon_scale", 4),
         ("minecraft:diamond_block", 1)],
        [
            (f"{MOD}:insanium_essence", corners),
            (f"{MOD}:dragon_scale", edges),
            ("minecraft:diamond_block", ["104"]),
        ],
        f"{MOD}:dragon_egg_crux",
        1,
        take=True,
    )
    check(
        "1 insanium essence + 1 farmland -> insanium_farmland",
        [(f"{MOD}:insanium_essence", 1), ("minecraft:farmland", 1)],
        [
            (f"{MOD}:insanium_essence", ["100"]),
            ("minecraft:farmland", ["101"]),
        ],
        f"{MOD}:insanium_farmland",
        1,
        take=True,
    )
    empty_control(
        "1 insanium essence + 1 dirt -> nothing",
        [(f"{MOD}:insanium_essence", 1), ("minecraft:dirt", 1)],
        [
            (f"{MOD}:insanium_essence", ["100"]),
            ("minecraft:dirt", ["101"]),
        ],
    )

    run("close")
    wait(3)
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        raise SystemExit(1)
    print("recipe PASS: nether_star_seeds, nether_star_crux, dragon_egg_crux "
          "and insanium_farmland craft; wrong-ingredient controls stay empty")


if __name__ == "__main__":
    main()
