# Utilities: connect one missing link, then prove it

Use this workflow instead of designing a whole pipe/cable grid in one batch. Every segment needs a named purpose: **connect this source-side node to this consumer-side node**. If either endpoint is unknown, discover it before building.

## First choose the actual problem

Run `coach.ps1 building -Index <affected-building-index> -Version <version>` and read its demand, fulfillment and unknown fields. No demand means supply is unproven, not necessarily broken. Use `coach.ps1 doctor` for the overall picture. Fix one service chain at a time:

| Service | Chain to establish | Common wrong assumption |
|---|---|---|
| Electricity | Working generator/import → appropriate voltage network/conversion → consumer | A transformer generates power; every cable/road uses the same voltage |
| Freshwater | Suitable, operating source → compatible water network → consumer | A pump exists, therefore water is reaching homes |
| Sewage | Consumer network → compatible disposal/treatment/export connection | Freshwater delivery proves sewage disposal |

Check a source's power, access, resource and operational requirements. Do not add more capacity when the existing source is disconnected or inactive.

## Discover endpoints, not just coordinates

Use `coach.ps1 inspect -Index <entity-index> -Version <version>`. Inspect the building's utility references and the nearby named edges. A building ID, prefab ID and network node ID are different things. A reference to an edge must be resolved to its nodes or an explicitly inspected edge-attachment point. Never select a connector merely because it is closest.

The helper includes owned subnetworks when the installed bridge supports `include_own` (0.4.8-coach.1). Older DLLs may omit these; missing connectors are incomplete evidence, not permission to build terrain-only pipes. Read NETWORK-SAFETY.md.

Two lines touching or crossing on screen do not establish a junction. Match index AND version, utility family and elevation. Water-family components alone do not prove sewage compatibility; electricity-family components alone do not prove matching voltage.

## Check before building

Substitute live connector IDs; angle-bracket values below are placeholders:

```powershell
pwsh -File .\coach.ps1 connection-check -FromIndex <source-node> -FromVersion <version> -ToIndex <consumer-node> -ToVersion <version>
```

- `physical_path_found_supply_unverified`: do not build a duplicate connection. Investigate source operation, layer, capacity and measured fulfillment.
- `disconnected_stop`: a link is missing. Inspect the endpoints and propose only that link within the owner's authorized scope.
- `connection_unknown_stop`: stop and report the missing evidence. Do not guess IDs, drop endpoint attachments or try random depths.

The check makes at most three bridge reads; it never builds, demolishes or simulates. Reads may pause the game under the bridge's normal analysis policy. It verifies the physical graph, not service flow through that graph.

## Build once, verify once

Use `connection-plan` with the discovered nodes, exact network prefab name, positive MaxCost and Reserve. Then `apply` once. Existing-node plans use elevation 0; native burial/attachment checks remain authoritative. If these reject, stop rather than turning the proposal into an unattached terrain segment.

`apply` now checks for a pre-existing path again immediately before building and automatically runs `connection-check` after a completed network operation. Its result is `review_needed`: read `connectionVerification`, preserve `operation.createdRoads` and the checkpoint. Native completion means built, not supplied. Raw build commands bypass this helper workflow.

If an operation was still pending, poll that same operation to completion, then run `connection-check` on the original endpoint pair. Do not resubmit the build.

If there is no path after building, stop extending the network. Inspect those specific created entities and endpoints. Never automatically delete dead ends: some are intentional terminals or connections outside a local query radius. Older preview receipts may contain real committed construction. Cleanup needs verified identities and authorization.

If the path exists, run `settle` once and re-read the affected building. Report wanted and fulfilled service, not just total capacity. Zero demand or missing readings means **supply unproven**. Do not keep simulating or laying additional networks until something changes.

## Reply promptly

After at most six helper calls or 45 seconds, say: what exists; whether the endpoint path was found; whether delivery was measured; and the one unresolved issue. Two identical failures mean stop and explain. Never leave the owner waiting while trying an entire grid of speculative pipes.

## Connector discovery (requires DLL 0.4.9-coach.1)
Run coach.ps1 connectors -Index <source-building> -Version <version>, then repeat for the affected consumer. Candidate attachment fields provide actual node IDs and absolute heights. The bounded search follows native subnets and the building's road reference; it does not choose the closest unrelated pipe. Compare incident-edge voltage and fresh/sewage capacity, then use connection-check. An empty or truncated result means incomplete discovery. Do not substitute guessed terrain coordinates.
The new DLL preserves explicit node positions after input snapping and supplies native burial metadata to the game. Existing-node plans still require elevation 0. Incompatible burial ranges and any lost native attachment still fail before apply. Runtime validation status is recorded in VALIDATION.md.

LIVE TEST LIMITATION (0.4.9): connector discovery passed on a standalone water pipe, but attaching an extension to its buried node still failed the pre-apply attachment guard. Do not claim that underground attachment is fixed; do not bypass the guard or switch to unattached coordinates. Building-to-building discovery and supply flow remain untested.
