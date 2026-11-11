// Runs at the head of `GameLevel::native_is_valid_bonemeal_target` (API 72):
// a tier-6 crop is a target only while it can grow and is young, as upstream's
// `MysticalCropBlock.isValidBonemealTarget`.
fn observe_bonemeal_target(
    level: &crate::game::GameLevel<'_>,
    pos: BlockPos,
    state: BlockStateId,
    valid: &mut Option<bool>,
) {
    crate::game::mysticalagradditions_state::on_bonemeal_target(
        level,
        [pos.x, pos.y, pos.z],
        state,
        valid,
    );
}
