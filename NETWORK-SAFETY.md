# Network previews and collision recovery (0.4.8-coach.1)

`build_road`, `build_network`, `upgrade_network` and `batch_execute` DO NOT support `previewOnly:true`. This version rejects it before execution, including unsupported previews in later batch steps. Do not remove the flag and retry unless real construction is authorized.

Older versions silently ignored this flag on these commands. A completed operation containing `createdRoads` is evidence of actual construction, even if the request said previewOnly. Those entities are not safe to flush as temporary previews. `cancel_tool` and `cancel_batch` do not roll back committed construction. There is no clear-previews command that removes committed networks.

## Recovery: at most three reads, then report

1. Keep the original operation receipt. Inspect one cited entity using `inspect_entity` with its current index AND version. IDs from a previous save/reload may be stale.
2. Query `get_network_edges` with the affected x/z, a small radius and `include_own:true` (alias `includeOwned:true`). Match the receipt IDs and prefab names. Use `get_network` with the same option to inspect node adjacency.
3. Report whether it is a live network, its name and endpoints, and what remains uncertain. Stop. Do not build around it or demolish it automatically. Ask the owner to approve removal of specific verified unintended segments; preserve legitimate connections.

`Owner` identifies a subnetwork belonging to another entity, such as a road or building. It does NOT mean player ownership. Standalone player-built utilities are included by default; this option also includes owned subnetworks. Temporary and deleted entities are always excluded. Nearby geometry is not proof of a working junction or utility supply.

## Placement failures

`placementErrors` now includes prefabName, temporary/deleted status, owner and geometry where available. Temporary entries include originalDetails for their original live entity. These are native error-marked entities, not guaranteed collision pairs. Curve control points/endpoints locate a segment, not the exact collision. `overlapCellsAvailable:false` means the bridge does not expose exact overlap cells; do not invent coordinates or causes from `reasonAvailable:false`.

## Preview limits

Building and zoning previews remain supported. Network commits use the native preview checks (placement errors, allow-apply, attachment geometry and budget) before applying, then verify the resulting entities and node attachment. A failure after apply may leave actual construction: inspect createdRoads and never blindly retry. There is currently no supported standalone network dry run or hypothetical multi-step network validation. Even a supported building/zoning preview cannot reserve the world state for a later commit.
