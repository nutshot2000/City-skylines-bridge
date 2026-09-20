using System;
using System.Collections.Generic;
using Game.Common;
using Game.Net;
using Newtonsoft.Json.Linq;
using Unity.Collections;
using Unity.Entities;

namespace CitiesIIAgentBridge
{
    public sealed partial class Mod
    {
        // Whole-world discovery; independent of camera radius. Road graph only.
        private JObject OutsideConnections(JObject args)
        {
            var w = RequireCity(); var em = w.EntityManager;
            if (args["index"] == null || args["version"] == null) throw new ArgumentException("road_node_index_and_version_required_from_get_network_not_building_or_prefab");
            var start = new Entity { Index = RequiredInt(args, "index"), Version = RequiredInt(args, "version") };
            if (!em.Exists(start) || !em.HasComponent<Node>(start)) throw new ArgumentException("start_must_be_current_road_node");
            var outside = new HashSet<Entity>();
            using (var q = em.CreateEntityQuery(ComponentType.ReadOnly<Node>(), ComponentType.ReadOnly<Game.Net.OutsideConnection>()))
            using (var nodes = q.ToEntityArray(Allocator.Temp)) foreach (var node in nodes)
                if (!em.HasComponent<Deleted>(node) && !em.HasComponent<Game.Tools.Temp>(node)) outside.Add(node);
            var queue = new Queue<Entity>(); var seen = new HashSet<Entity>(); var previous = new Dictionary<Entity, Entity>();
            queue.Enqueue(start); seen.Add(start); bool limited = false;
            while (queue.Count > 0 && !limited)
            {
                var node = queue.Dequeue();
                if (!em.HasBuffer<ConnectedEdge>(node)) continue;
                foreach (var link in em.GetBuffer<ConnectedEdge>(node, true))
                {
                    var e = link.m_Edge;
                    if (!em.Exists(e) || !em.HasComponent<Road>(e) || !em.HasComponent<Edge>(e) || em.HasComponent<Deleted>(e) || em.HasComponent<Game.Tools.Temp>(e)) continue;
                    var edge = em.GetComponentData<Edge>(e); var next = edge.m_Start == node ? edge.m_End : edge.m_Start;
                    if (seen.Contains(next)) continue;
                    if (seen.Count >= 100000) { limited = true; break; }
                    seen.Add(next); previous[next] = node; queue.Enqueue(next);
                }
            }
            var rows = new JArray(); int connected = 0;
            foreach (var node in outside)
            {
                bool road = false;
                if (em.HasBuffer<ConnectedEdge>(node)) foreach (var link in em.GetBuffer<ConnectedEdge>(node, true))
                    if (em.Exists(link.m_Edge) && em.HasComponent<Road>(link.m_Edge) && !em.HasComponent<Deleted>(link.m_Edge) && !em.HasComponent<Game.Tools.Temp>(link.m_Edge)) road = true;
                if (!road) continue;
                bool reachable = seen.Contains(node); if (reachable) connected++;
                var row = NativeBuild.Id(node); row["position"] = Vector(em.GetComponentData<Node>(node).m_Position);
                row["physicallyConnected"] = reachable; rows.Add(row);
            }
            return new JObject { ["start"] = NativeBuild.Id(start), ["outsideRoadNodes"] = rows, ["connectedCount"] = connected, ["visitedRoadNodes"] = seen.Count,
                ["truncated"] = limited, ["status"] = connected > 0 ? "physical_path_found" : limited || rows.Count == 0 ? "unknown" : "no_physical_path",
                ["meaning"] = "Whole-map undirected road adjacency from the supplied node. Does not prove lane direction, vehicle routing, unlocked access, or that residents can move in." };
        }
    }
}
