using System;
using System.Collections.Generic;
using System.Linq;
using Game.Prefabs;
using Game.Tools;
using Newtonsoft.Json.Linq;
using Unity.Collections;
using Unity.Entities;
using Unity.Mathematics;

namespace CitiesIIAgentBridge
{
    public sealed partial class Mod
    {
        private int GrowableCount(World w, Entity zone)
        {
            int count = 0;
            using (var q = w.EntityManager.CreateEntityQuery(ComponentType.ReadOnly<SpawnableBuildingData>()))
            using (var data = q.ToComponentDataArray<SpawnableBuildingData>(Allocator.Temp))
                foreach (var item in data) if (item.m_ZonePrefab == zone) count++;
            return count;
        }
        private JObject ZoneCatalog()
        {
            var w = RequireCity(); var ps = w.GetExistingSystemManaged<PrefabSystem>();
            var counts = new Dictionary<Entity, int>();
            using (var q = w.EntityManager.CreateEntityQuery(ComponentType.ReadOnly<SpawnableBuildingData>()))
            using (var data = q.ToComponentDataArray<SpawnableBuildingData>(Allocator.Temp))
                foreach (var item in data) { counts.TryGetValue(item.m_ZonePrefab, out var n); counts[item.m_ZonePrefab] = n + 1; }
            var rows = new JArray();
            using (var q = w.EntityManager.CreateEntityQuery(ComponentType.ReadOnly<ZoneData>()))
            using (var entities = q.ToEntityArray(Allocator.Temp)) foreach (var e in entities)
            {
                if (!ps.TryGetPrefab<ZonePrefab>(e, out var p) || p == null) continue;
                counts.TryGetValue(e, out var count); bool locked = IsPrefabLocked(w.EntityManager, e);
                rows.Add(new JObject { ["index"] = e.Index, ["version"] = e.Version, ["name"] = p.name,
                    ["matchingGrowables"] = count, ["locked"] = locked, ["usable"] = count > 0 && !locked });
            }
            return new JObject { ["zones"] = rows, ["nextAction"] = "Choose usable=true and the desired theme. Matching assets do not guarantee demand, access or growth. Never guess zone IDs." };
        }
        private JObject NearbyInfrastructure(JObject args)
        {
            var w = RequireCity(); var em = w.EntityManager; var ps = w.GetExistingSystemManaged<PrefabSystem>();
            var center = new float2(RequiredFloat(args, "x"), RequiredFloat(args, "z"));
            var rows = new List<JObject>();
            using (var q = em.CreateEntityQuery(new EntityQueryDesc { All = new[] { ComponentType.ReadOnly<Game.Net.Edge>(), ComponentType.ReadOnly<Game.Net.Curve>(), ComponentType.ReadOnly<PrefabRef>() }, None = new[] { ComponentType.ReadOnly<Temp>(), ComponentType.ReadOnly<Game.Common.Deleted>() } }))
            using (var entities = q.ToEntityArray(Allocator.Temp)) foreach (var e in entities)
            {
                if (!ps.TryGetPrefab<NetPrefab>(em.GetComponentData<PrefabRef>(e).m_Prefab, out var p) || p == null) continue;
                bool road = em.HasComponent<Game.Net.Road>(e);
                bool power = p.name.IndexOf("Voltage", StringComparison.OrdinalIgnoreCase) >= 0 || p.name.IndexOf("Power Line", StringComparison.OrdinalIgnoreCase) >= 0;
                if (!road && !power) continue;
                var edge = em.GetComponentData<Game.Net.Edge>(e); var curve = em.GetComponentData<Game.Net.Curve>(e).m_Bezier;
                float distance = math.min(math.distance(center, curve.a.xz), math.distance(center, curve.d.xz));
                var row = NativeBuild.Id(e); row["prefab"] = p.name; row["kind"] = road ? "road" : "power_name_candidate";
                row["nearestEndpointDistance"] = distance; row["startNode"] = NativeBuild.Id(edge.m_Start); row["endNode"] = NativeBuild.Id(edge.m_End);
                row["startPosition"] = Vector(curve.a); row["endPosition"] = Vector(curve.d); rows.Add(row);
            }
            return new JObject { ["roads"] = new JArray(rows.Where(r => (string)r["kind"] == "road").OrderBy(r => (float)r["nearestEndpointDistance"]).Take(12)),
                ["powerCandidates"] = new JArray(rows.Where(r => (string)r["kind"] != "road").OrderBy(r => (float)r["nearestEndpointDistance"]).Take(12)),
                ["meaning"] = "Whole-map candidates ranked by endpoint distance, not camera radius. Includes your own networks. Power classification uses names only. Inspect tile ownership, native connectors and source connectivity before construction; proximity proves none of these." };
        }
        private JObject ToolStatus()
        {
            var t = RequireCity().GetExistingSystemManaged<ToolSystem>();
            return new JObject { ["activeTool"] = t.activeTool?.GetType().Name,
                ["operationId"] = ConstructionAccess.Active, ["batchRunning"] = (string)batch?["status"] == "running",
                ["simulationRunning"] = SimulationRunning, ["readyForConstruction"] = t.activeTool is DefaultToolSystem && ConstructionAccess.Active == null && !SimulationRunning && (string)batch?["status"] != "running" };
        }
        private JObject CancelTool()
        {
            RequireControl();
            if (SimulationRunning || (string)batch?["status"] == "running") throw new InvalidOperationException("cancel_simulation_step_or_cancel_batch_first");
            var w = RequireCity(); var t = w.GetExistingSystemManaged<ToolSystem>();
            string id = ConstructionAccess.Active;
            if (id != null && !(t.activeTool is BridgeRoadTool) && !(t.activeTool is BridgeZoneTool) && !(t.activeTool is BridgeObjectTool) && !(t.activeTool is BridgeBulldozeTool))
                throw new InvalidOperationException("non_tool_operation_running_poll_original_id");
            t.activeTool = w.GetExistingSystemManaged<DefaultToolSystem>();
            return new JObject { ["cancelRequested"] = true, ["operationId"] = id,
                ["nextAction"] = "Poll the original operation if present and inspect the affected area. Cancellation does not undo anything already applied." };
        }
        private JObject SimulationStatus(JObject args)
        {
            var result = ConstructionAccess.Status((string)args["id"]);
            if ((string)result["kind"] != "simulation_step" || (string)result["citySession"] != citySession)
                throw new ArgumentException("simulation_step_not_found_in_this_city");
            return result;
        }
    }
}
