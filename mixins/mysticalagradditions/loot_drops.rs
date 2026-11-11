// Runs at the head of `Game::native_loot_drops` (API 75): a broken tier-6
// crop's stacks are the jar's `MysticalCropBlock.getDrops`, not the rolled
// content table's fallback (the table still covers paths the hook does not
// hear, such as `/setblock ... destroy`).
fn observe_loot_drops(
    game: &mut crate::game::Game<'_>,
    context: &crate::game::native_hooks::NativeLootDrops<'_>,
    drops: &mut Vec<horizon_client::items::ItemStack>,
) {
    crate::game::mysticalagradditions_state::on_loot_drops(game, context, drops);
}
