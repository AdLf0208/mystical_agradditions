// Runs at the head of `GameLevel::native_is_bonemeal_success` (API 72): the
// jar refuses bone meal on every tier-6 crop.
fn observe_bonemeal_success(
    level: &crate::game::GameLevel<'_>,
    state: BlockStateId,
    success: &mut bool,
) {
    crate::game::mysticalagradditions_state::on_bonemeal_success(level, state, success);
}
