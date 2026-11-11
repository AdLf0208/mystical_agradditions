// Runs at the head of `GameLevel::native_random_tick` (API 33): a tier-6 crop
// keeps the wheat template's own random tick only while its crux stands two
// blocks below it; otherwise `handled` skips the growth.
fn observe_random_tick(
    level: &mut crate::game::GameLevel<'_>,
    pos: BlockPos,
    state: BlockStateId,
    handled: &mut bool,
) {
    crate::game::mysticalagradditions_state::on_random_tick(
        level,
        [pos.x, pos.y, pos.z],
        state,
        handled,
    );
}
