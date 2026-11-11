// Game-side glue for the tier-6 crops (Mystical Agradditions 8.0.15): the
// crux gate `MysticalCropBlock.canGrow` applies before the wheat template's
// random tick, its bone-meal answers, and its `getDrops` stacks. The pure rules
// live in `runtime.rs`; this module is injected into `crate::game` as
// `mysticalagradditions_state` and is not part of the standalone library.

use crate::game::mysticalagradditions::{self as rules, Crop};
use horizon_client::game::native_hooks::NativeLootDrops;
use horizon_client::items::ItemStack;
use horizon_world::registry::BlockStateId;

/// The crop whose block is `state`, or `None` for any other block.
fn crop_of(level: &crate::game::GameLevel<'_>, state: BlockStateId) -> Option<Crop> {
    let state = level.registry.state(state)?;
    Crop::by_block(&state.name)
}

/// The crop's `age` property, as the wheat template spells it.
fn age_of(level: &crate::game::GameLevel<'_>, state: BlockStateId) -> Option<u8> {
    level
        .registry
        .state(state)?
        .properties
        .get("age")?
        .parse()
        .ok()
}

/// The block at `pos` as a registry name; an unloaded column or an unknown
/// state is the empty string, which no crop's crux matches.
fn block_name(level: &crate::game::GameLevel<'_>, [x, y, z]: [i32; 3]) -> String {
    if !level.world.loaded(x, z) {
        return String::new();
    }
    level
        .registry
        .state(level.world.block(x, y, z))
        .map(|state| state.name.to_string())
        .unwrap_or_default()
}

/// `MysticalCropBlock.canGrow` for the crop at `pos`: the crux two blocks
/// below, plus the tier's farmland when the parent config asks for it.
fn may_grow(level: &crate::game::GameLevel<'_>, crop: Crop, [x, y, z]: [i32; 3]) -> bool {
    let below_two = block_name(level, [x, y - 2, z]);
    let below = block_name(level, [x, y - 1, z]);
    rules::can_grow(
        crop,
        &below_two,
        &below,
        rules::REQUIRES_EFFECTIVE_FARMLAND,
    )
}

/// `native_random_tick` (API 33): the crop advances through the wheat
/// template's own random tick only while `canGrow` holds. `handled` skips that
/// tick, so a crop over stone or a mismatched crux holds its stage.
pub(super) fn on_random_tick(
    level: &mut crate::game::GameLevel<'_>,
    pos: [i32; 3],
    state: BlockStateId,
    handled: &mut bool,
) {
    let Some(crop) = crop_of(level, state) else {
        return;
    };
    if !may_grow(level, crop, pos) {
        *handled = true;
    }
}

/// `MysticalCropBlock.isValidBonemealTarget`: `canGrow && super` (a young
/// crop). Without the crux the meal is not even a target, so it is not spent.
pub(super) fn on_bonemeal_target(
    level: &crate::game::GameLevel<'_>,
    pos: [i32; 3],
    state: BlockStateId,
    valid: &mut Option<bool>,
) {
    let Some(crop) = crop_of(level, state) else {
        return;
    };
    let age = age_of(level, state).unwrap_or(rules::MAX_AGE);
    *valid = Some(!rules::is_ripe(age) && may_grow(level, crop, pos));
}

/// `MysticalCropBlock.isBonemealSuccess` is always false: a meal spent on a
/// tier-6 crop never advances it.
pub(super) fn on_bonemeal_success(
    level: &crate::game::GameLevel<'_>,
    state: BlockStateId,
    success: &mut bool,
) {
    if crop_of(level, state).is_some() {
        *success = false;
    }
}

/// A broken tier-6 crop's stacks come from the jar's `getDrops`
/// (`MysticalCropBlock.getDrops`), not from the rolled table: the table is the
/// content-only fallback, and the native hook is what makes the farmland-under
/// rules exact. Tier 6's counts are deterministic (see `rules::harvest`).
pub(super) fn on_loot_drops(
    game: &mut crate::game::Game<'_>,
    context: &NativeLootDrops<'_>,
    drops: &mut Vec<ItemStack>,
) {
    let Some((_, state_id)) = context.block else {
        return;
    };
    let Some(state) = game.pack.assets.registry.state(state_id) else {
        return;
    };
    let Some(crop) = Crop::by_block(&state.name) else {
        return;
    };
    let Some(age) = state.properties.get("age").and_then(|age| age.parse().ok()) else {
        return;
    };
    let harvest = rules::harvest(age);

    drops.clear();
    if harvest.essence > 0 {
        drops.push(ItemStack::new(crop.essence, harvest.essence));
    }
    if harvest.seeds > 0 {
        drops.push(ItemStack::new(crop.seeds, harvest.seeds));
    }
}
