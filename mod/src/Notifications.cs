using System;
using System.Collections.Generic;
using System.Linq;
using Game.Notifications;
using Game.Prefabs;
using Newtonsoft.Json.Linq;
using Unity.Collections;
using Unity.Entities;
using Unity.Mathematics;

namespace CitiesIIAgentBridge
{
    public sealed partial class Mod
    {
        // The warning icons that float over buildings and roads in-game (traffic jam, no water,
        // not enough workers, abandoned, ...). Grouped by type with example locations so an agent
        // can find where the city is struggling without scanning every building.
        private JObject Notifications(JObject args)
        {
            var w = RequireCity(); var em = w.EntityManager; var ps = w.GetExistingSystemManaged<PrefabSystem>();
            string filter = (string)args["filter"] ?? "";
            int perType = Math.Max(1, Math.Min(50, (int?)args["examples"] ?? 8));
            bool useArea = args["x"] != null && args["z"] != null;
            float2 centre = useArea ? new float2(RequiredFloat(args, "x"), RequiredFloat(args, "z")) : float2.zero;
            float radius = args["radius"] == null ? 500 : RequiredFloat(args, "radius");
            var groups = new Dictionary<string, (IconPriority priority, List<JObject> rows, int count)>();
            int total = 0;
            using (var q = em.CreateEntityQuery(new EntityQueryDesc { All = new[] { ComponentType.ReadOnly<Icon>(), ComponentType.ReadOnly<PrefabRef>() }, None = new[] { ComponentType.ReadOnly<Game.Common.Deleted>(), ComponentType.ReadOnly<Game.Tools.Temp>() } }))
            using (var es = q.ToEntityArray(Allocator.Temp)) foreach (var e in es)
            {
                var icon = em.GetComponentData<Icon>(e);
                if (icon.m_ClusterLayer != IconClusterLayer.Default) continue; // skip selection markers and money pop-ups
                if (useArea && math.distance(icon.m_Location.xz, centre) > radius) continue;
                string type = ps.GetPrefabName(em.GetComponentData<PrefabRef>(e).m_Prefab) ?? "unknown";
                if (type == "Selected") continue; // the player's selection marker, not a city problem
                if (type.IndexOf(filter, StringComparison.OrdinalIgnoreCase) < 0) continue;
                total++;
                if (!groups.TryGetValue(type, out var g)) g = (icon.m_Priority, new List<JObject>(), 0);
                g.count++;
                if (g.rows.Count < perType)
                {
                    var row = new JObject { ["position"] = Vector(icon.m_Location), ["priority"] = icon.m_Priority.ToString() };
                    if (em.HasComponent<Game.Common.Owner>(e))
                    {
                        var owner = em.GetComponentData<Game.Common.Owner>(e).m_Owner;
                        // Traffic icons sit on a lane; walk up to the road edge/building that owns it.
                        for (int hop = 0; hop < 4 && em.Exists(owner) && !em.HasComponent<Game.Buildings.Building>(owner) && !em.HasComponent<Game.Net.Edge>(owner) && !em.HasComponent<Game.Net.Node>(owner) && em.HasComponent<Game.Common.Owner>(owner); hop++)
                            owner = em.GetComponentData<Game.Common.Owner>(owner).m_Owner;
                        if (em.Exists(owner))
                        {
                            var target = NativeBuild.Id(owner);
                            if (em.HasComponent<PrefabRef>(owner)) target["prefab"] = ps.GetPrefabName(em.GetComponentData<PrefabRef>(owner).m_Prefab);
                            target["kind"] = em.HasComponent<Game.Buildings.Building>(owner) ? "building" : em.HasComponent<Game.Net.Edge>(owner) ? "road" : em.HasComponent<Game.Net.Node>(owner) ? "intersection" : "other";
                            row["on"] = target;
                        }
                    }
                    g.rows.Add(row);
                }
                groups[type] = g;
            }
            var list = new JArray(groups.OrderByDescending(kv => (int)kv.Value.priority).ThenByDescending(kv => kv.Value.count)
                .Select(kv => new JObject { ["type"] = kv.Key, ["priority"] = kv.Value.priority.ToString(), ["count"] = kv.Value.count, ["examples"] = new JArray(kv.Value.rows) }));
            return new JObject { ["total"] = total, ["types"] = list,
                ["meaning"] = "Live in-game warning icons (the ones that flash over buildings/roads). type is the notification prefab name, e.g. TrafficJam or NoWater; on = the building/road it is attached to. Icons appear and clear as the simulation runs." };
        }
    }
}
