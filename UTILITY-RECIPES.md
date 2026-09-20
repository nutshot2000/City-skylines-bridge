# Utility recipes: identify the missing link

## The four checks

**Source → compatible network → consumer → measured service.** All four are needed. A successful build proves only that an object exists.

| Evidence | What it proves | What it does not prove |
|---|---|---|
| Native preview accepts placement | That preview passed at that moment | That anything was built |
| Operation complete + entity found | The expected object exists | That it is connected or producing |
| Nonzero connection ID | A connection entity is recorded | A usable path to a working source |
| trace_network connected | Physical graph adjacency | Correct voltage, water/sewage layer, capacity or flow |
| Capacity greater than zero | Potential local capacity | Actual production or service delivery |
| No shortages, with no demand | Nothing currently reported short | A future neighborhood will be supplied |
| Positive production + served consumer demand | Evidence of service during that observation | That every disconnected network is served |

## Electricity

1. Discover a real source: an unlocked generator, or a verified external supply route. A transformer **converts voltage; it does not generate electricity**.
2. Inspect the generator/transformer and its electricity references. These may be edges or nodes; do not substitute the building ID.
3. Inspect nearby networks and their prefab names. Keep high- and low-voltage networks distinct. A road being nearby is not proof of an electrical connection. Check that the road/asset supports the intended layer in the actual game build.
4. Establish the missing compatible connection. For external high-voltage supply, verify the feed reaches the appropriate transformer and that distribution continues to consumers. Do not add transformers by guesswork to a local source path.
5. Check generator status, production, consumer wanted/fulfilled values in raw building details, and persistent shortage data after one bounded simulation interval. Paused or demand-free cities may report zero production without proving a fault.

## Fresh water

1. Discover an unlocked source and read its prefab details. A water tower, groundwater pump and surface-water pump have different siting requirements; do not interchange them blindly.
2. Inspect native site constraints and sampled water/ground pollution before construction. Surface-water and groundwater resource suitability may require in-game UI checks beyond this helper. Geometric `sites` candidates alone cannot certify them.
3. Inspect the source's water connection references and the consumer network. Select the correct freshwater-compatible pipe. A pipe laid in open ground without attachment at either end does nothing useful.
4. Check power and any required road access for the source, then its capacity AND actual production. Check consumers' `wantedConsumption` against `fulfilledFresh` and pollution after simulation.
5. If capacity exists but delivery does not, inspect source operation, actual graph path and layer before adding capacity. Do not keep placing pumps.

## Sewage

1. Fresh water supply does not automatically prove sewage disposal. Discover an unlocked sewage outlet or treatment facility, or a separately verified export connection.
2. For an outlet, check native shoreline placement and environmental suitability; do not guess a water coordinate or assume native preview guarantees clean drinking water. Keep sewage away from water-intake pollution paths.
3. Connect the sewage-compatible network to the facility's actual connector, and verify its power/road requirements. Water and sewage pipe prefabs are not interchangeable just because they follow the same route.
4. After simulation, inspect `lastProcessedRaw`, capacity, consumer `fulfilledSewage` versus `wantedConsumption`, and persistent sewage shortages. With no demand, processing may remain zero: call the result unproven.

## Connections and elevation: easy mistakes

- `index/version` together identify the current entity. A recycled index with a new version is a different entity.
- `connection-plan` accepts existing network **nodes** only. `inspect` lists named edges and their start/end nodes, which lets you identify the appropriate layer. It does not choose the nearest node automatically.
- A building's producer/consumer reference can point to an **edge**. Use nearby edge data to discover that edge's endpoints, or the original bridge's edge-attachment workflow with an explicitly checked curvePosition. The helper does not invent edge attachment points.
- The supplied bridge resolves a node's absolute height and then adds `elevation`. Applying -10 to an already-underground node can shift the proposal down again. Node-to-node helper plans request elevation 0, but the native tool can still apply burial again. The patched DLL checks preview endpoint identity and height before applying and rejects a mismatch. Do not blindly retry or drop endpoint IDs to bypass this check.
- A free-floating pipe created from terrain points is a different operation: inspect its allowed elevation range first. Do not reuse the node-to-node rule blindly for terrain-based construction.
- If native placement rejects the route, inspect its error. Do not bypass preview, set ignore-errors, or try random depths until something appears.

## Decision when it still does not work

1. **No source?** Discover and preview one appropriate source.
2. **Source exists but is inactive?** Inspect its power, resource, road, budget and operational data.
3. **Source active but consumers short?** Inspect each disconnected component and compatible connection path.
4. **Connected path but still short?** Compare actual production/processing and demand; allow one bounded update and re-read.
5. **No demand or incomplete data?** State “not yet proven,” identify the missing observation and stop speculative construction.

Do not promise a functioning neighborhood from these helpers alone. They assist discovery, planning, waiting and interpretation; they do not solve arbitrary terrain routing or certify utility delivery.
