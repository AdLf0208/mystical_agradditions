//! Mystical Agradditions for Horizon: the six tier-6 crops and the two mob drops.
//!
//! Upstream (see `FINDINGS.md`) is `MysticalCropBlock` from the parent Mystical Agriculture:
//! a crop on the wheat template whose `canGrow` needs the crop's own crux two blocks below,
//! whose bone meal never grows it, and whose `getDrops` returns the tier's essence and seeds.
//! `MobDropsHandler` adds the Wither's `withering_soul` and the Ender Dragon's `dragon_scale`.
//! The rules — the six-crop table, the crux gate, the tier-6 harvest counts, the two drop
//! rolls — live in [`runtime`], a plain module with no `mod_api` types, so `cargo test`
//! exercises them without the game. [`support`] is the glue: one block Part, the loot hook and
//! the mob-drop hook.
//!
//! # Where the retired container's hooks went
//!
//! The 2026-11-17 mod-API merge (#16941, launcher ≥ 0.2.70) retired `.hnmod`: the plan, the
//! injection points and the per-hook helper files are gone, and a hook is a typed method or,
//! for a moment that belongs to one block, a Part. The mapping is:
//!
//! | `.hnmod` hook (API) | here |
//! |---|---|
//! | `random_tick` (33) HEAD helper `random_tick.rs` | [`BlockPart::random_tick`](mod_api::BlockPart::random_tick) → `Flow::Cancel` skips the wheat template's tick |
//! | `is_valid_bonemeal_target` (72) HEAD helper `bonemeal_target.rs` | [`BlockPart::is_valid_bonemeal_target`](mod_api::BlockPart::is_valid_bonemeal_target) on the crops' own Part |
//! | `is_bonemeal_success` (72) HEAD helper `bonemeal_success.rs` | [`BlockPart::is_bonemeal_success`](mod_api::BlockPart::is_bonemeal_success) on the same Part |
//! | `loot_drops` (75) HEAD helper `loot_drops.rs` | [`Hooks::loot_drops`] — a global hook: the broken block is `event.context.block` |
//! | the `content_root` injection and `embedded_content.rs` | gone: one flat `.hmod` carries `assets/` and `data/` itself |
//! | `[[module]] runtime` | `pub mod runtime` |
//! | `[[module]] state` (`support.rs`) | `mod support` |
//!
//! `MobDropsHandler.onLivingDrops` is the one moment this port did not reach before 0.2.1:
//! it is [`Hooks::living_drops`], the entity's whole collected drop list, and it is where the
//! Wither's 35 % soul and the dragon's eight scales join the drops.
//!
//! The carried content is declared by this same package, so `register` resolves the six
//! crops' blocks and items, the two drop items, and attaches the Part to each crop block; a
//! missing id refuses the mod at load instead of failing silently at the first tick.
pub mod runtime;
mod support;

use mod_api::{
    self, Flow, Hooks, LivingDropsEvent, LootDropsEvent, Registrar, RegistrationContext, ServerHost,
};

/// The mod has no settings: what it keeps is the content's own ids, resolved once.
#[derive(Default)]
struct Mod;

#[mod_api::horizon_mod]
impl Hooks for Mod {
    /// Resolve the six crops' ids and attach their growth/bone-meal Part.
    fn register(&self, r: &mut dyn Registrar, _context: &RegistrationContext) {
        support::register(r);
    }

    /// A block broke: a tier-6 crop drops the jar's essence and seeds instead of the rolled
    /// content table's fallback.
    fn loot_drops(&self, host: &mut dyn ServerHost, event: &mut LootDropsEvent<'_>) {
        support::on_loot_drops(host, event);
    }

    /// A mob died: a Wither may leave a `withering_soul` and an Ender Dragon leaves
    /// `dragon_scale`, the jar's `MobDropsHandler`. The drops are added, never cancelled.
    fn living_drops(&self, host: &mut dyn ServerHost, event: &mut LivingDropsEvent<'_>) -> Flow {
        support::on_living_drops(host, event);
        Flow::Continue
    }
}
