using System.Collections.Generic;
using System.Linq;
using Game.City;
using Game.Prefabs;
using Game.Simulation;
using Newtonsoft.Json.Linq;
using Unity.Collections;
using Unity.Entities;

namespace CitiesIIAgentBridge
{
    public sealed partial class Mod
    {
        // Compact XP progress, safe to include in non-pausing status polls.
        private JObject MilestoneSummary(World w)
        {
            var ms = w.GetExistingSystemManaged<MilestoneSystem>(); var city = w.GetExistingSystemManaged<CitySystem>(); var em = w.EntityManager;
            int? achieved = city != null && em.Exists(city.City) && em.HasComponent<MilestoneLevel>(city.City) ? em.GetComponentData<MilestoneLevel>(city.City).m_AchievedMilestone : (int?)null;
            if (ms == null) return new JObject { ["achievedMilestone"] = achieved };
            return new JObject { ["achievedMilestone"] = achieved, ["nextMilestone"] = ms.nextMilestone, ["currentXP"] = ms.currentXP, ["nextMilestoneXP"] = ms.requiredXP, ["progress"] = ms.progress };
        }

        // Milestones, their rewards and what each one unlocks directly (zones, services, assets).
        private JObject Milestones()
        {
            var w = RequireCity(); var em = w.EntityManager; var ps = w.GetExistingSystemManaged<PrefabSystem>();
            var milestones = new Dictionary<Entity, int>();
            using (var q = em.CreateEntityQuery(ComponentType.ReadOnly<MilestoneData>(), ComponentType.ReadOnly<PrefabData>()))
            using (var es = q.ToEntityArray(Allocator.Temp))
                foreach (var e in es) milestones[e] = em.GetComponentData<MilestoneData>(e).m_Index;
            var unlocks = new Dictionary<int, JArray>();
            using (var q = em.CreateEntityQuery(ComponentType.ReadOnly<PrefabData>(), ComponentType.ReadOnly<UnlockRequirement>()))
            using (var es = q.ToEntityArray(Allocator.Temp))
                foreach (var e in es)
                {
                    if (milestones.ContainsKey(e)) continue;
                    foreach (var req in em.GetBuffer<UnlockRequirement>(e, true))
                    {
                        if (!milestones.TryGetValue(req.m_Prefab, out int index)) continue;
                        if (!ps.TryGetPrefab<PrefabBase>(e, out var p) || p == null) break;
                        if (!unlocks.TryGetValue(index, out var list)) unlocks[index] = list = new JArray();
                        if (list.Count < 120) list.Add(new JObject { ["name"] = p.name, ["kind"] = Kind(p), ["locked"] = IsPrefabLocked(em, e) });
                        break;
                    }
                }
            var summary = MilestoneSummary(w); int achieved = (int?)summary["achievedMilestone"] ?? 0;
            var rows = new JArray();
            foreach (var kv in milestones.OrderBy(k => k.Value))
            {
                var d = em.GetComponentData<MilestoneData>(kv.Key);
                rows.Add(new JObject
                {
                    ["index"] = d.m_Index, ["name"] = ps.GetPrefabName(kv.Key), ["xpRequired"] = d.m_XpRequried, ["achieved"] = d.m_Index <= achieved,
                    ["moneyReward"] = d.m_Reward, ["developmentPoints"] = d.m_DevTreePoints, ["mapTiles"] = d.m_MapTiles, ["loanLimit"] = d.m_LoanLimit,
                    ["unlocks"] = unlocks.TryGetValue(d.m_Index, out var l) ? l : new JArray()
                });
            }
            summary["milestones"] = rows;
            summary["meaning"] = "XP comes from population growth, building and happiness. unlocks lists prefabs whose unlock requirement names that milestone directly; buildings of a service also need that service (itself often milestone-gated) and sometimes a development-tree node.";
            return summary;
        }

        private static string Kind(PrefabBase p) => p is ZonePrefab ? "zone" : p is BuildingPrefab ? "building" : p is ServicePrefab ? "service" : p is NetPrefab ? "network" : "other";

        // Why is a prefab locked? Names of its unlock requirements (milestones, services, dev-tree nodes).
        private static JArray UnlockBlockers(EntityManager em, PrefabSystem ps, Entity e)
        {
            var locked = new JArray(); var all = new JArray();
            if (!em.HasBuffer<UnlockRequirement>(e)) return locked;
            foreach (var req in em.GetBuffer<UnlockRequirement>(e, true))
            {
                if (req.m_Prefab == e || !em.Exists(req.m_Prefab)) continue;
                string name = ps.GetPrefabName(req.m_Prefab);
                if (all.Count < 4) all.Add(name);
                if (IsPrefabLocked(em, req.m_Prefab) && locked.Count < 4) locked.Add(name);
            }
            return locked.Count > 0 ? locked : all;
        }
    }
}
