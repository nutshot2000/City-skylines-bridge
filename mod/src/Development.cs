using System;
using System.Collections.Generic;
using Game.City;
using Game.Prefabs;
using Newtonsoft.Json.Linq;
using Unity.Collections;
using Unity.Entities;

namespace CitiesIIAgentBridge
{
    public sealed partial class Mod
    {
        private Dictionary<Entity, JObject> developmentAttempts;
        private JObject DevelopmentNode(World w, Entity e, int points)
        {
            var em = w.EntityManager; var ps = w.GetExistingSystemManaged<PrefabSystem>();
            var d = em.GetComponentData<DevTreeNodeData>(e);
            bool locked = IsPrefabLocked(em,e);
            bool serviceAvailable = d.m_Service == Entity.Null || (em.Exists(d.m_Service) && !IsPrefabLocked(em,d.m_Service));
            var requirements = new JArray(); bool hasRequirements = false, anyUnlocked = false;
            if (em.HasBuffer<DevTreeNodeRequirement>(e)) foreach(var requirement in em.GetBuffer<DevTreeNodeRequirement>(e,true))
            {
                if(requirement.m_Node == Entity.Null) continue;
                hasRequirements = true;
                bool unlocked = em.Exists(requirement.m_Node) && !IsPrefabLocked(em,requirement.m_Node);
                anyUnlocked |= unlocked;
                var row=NativeBuild.Id(requirement.m_Node); row["unlocked"]=unlocked; requirements.Add(row);
            }
            bool pending = developmentAttempts != null && developmentAttempts.ContainsKey(e) && locked;
            string blocker = DevelopmentPolicy.Blocker(locked,serviceAvailable,hasRequirements,anyUnlocked,points,d.m_Cost,pending);
            var result=NativeBuild.Id(e); result["name"]=ps.GetPrefabName(e); result["cost"]=d.m_Cost;
            result["locked"]=locked; result["serviceAvailable"]=serviceAvailable;
            result["service"]=d.m_Service == Entity.Null ? null : NativeBuild.Id(d.m_Service);
            if(d.m_Service != Entity.Null && em.Exists(d.m_Service)) result["service"]["name"]=ps.GetPrefabName(d.m_Service);
            result["requirements"]=requirements; result["requirementRule"]="any_unlocked_or_none";
            result["purchasable"]=blocker == null; result["blocker"]=blocker;
            if(developmentAttempts != null && developmentAttempts.TryGetValue(e,out var attempt))
            { result["purchase"] = attempt.DeepClone(); result["purchase"]["status"] = locked ? "pending_or_unknown_do_not_repeat" : "unlock_verified"; }
            return result;
        }
        private JObject DevelopmentTree()
        {
            var w=RequireCity(); var system=w.GetExistingSystemManaged<DevTreeSystem>();
            if(system==null) throw new InvalidOperationException("development_system_unavailable");
            int points=system.points; var rows=new JArray();
            using(var q=w.EntityManager.CreateEntityQuery(ComponentType.ReadOnly<DevTreeNodeData>()))
            using(var es=q.ToEntityArray(Allocator.Temp)) foreach(var e in es) rows.Add(DevelopmentNode(w,e,points));
            return new JObject { ["developmentPoints"]=points, ["cityXp"]=CityState()["xp"], ["nodes"]=rows, ["pausesGame"]=false,
                ["meaning"]="XP is milestone progress, not spendable development points. Service availability is an eligibility gate, not the building unlocked by this node. Copy node index/version here; never use building prefab IDs. Confirm target building locked:false separately." };
        }
        private JObject PurchaseDevelopment(JObject args)
        {
            var w=RequireCity(); RequireControl(); CheckBuildTool(w);
            if(SimulationRunning || ConstructionAccess.Active!=null || (string)batch?["status"]=="running") throw new InvalidOperationException("finish_current_operation_before_purchase");
            var e=new Entity {Index=RequiredInt(args,"index"),Version=RequiredInt(args,"version")};
            if(!w.EntityManager.Exists(e) || !w.EntityManager.HasComponent<DevTreeNodeData>(e)) throw new ArgumentException("entity_not_a_devtree_node_use_get_devtree");
            var system=w.GetExistingSystemManaged<DevTreeSystem>(); if(system==null) throw new InvalidOperationException("development_system_unavailable");
            int before=system.points; var node=DevelopmentNode(w,e,before); int max=RequiredInt(args,"maxPoints");
            if(max<0 || (int)node["cost"]>max) throw new ArgumentException("development_cost_exceeds_maxPoints");
            if(!(bool)node["purchasable"]) throw new InvalidOperationException((string)node["blocker"]+": available="+before+", cost="+node["cost"]);
            // Keep an attempt even if native purchase throws after spending. Never replay uncertain purchases.
            if(developmentAttempts==null) developmentAttempts=new Dictionary<Entity,JObject>();
            foreach(var pair in developmentAttempts) if(w.EntityManager.Exists(pair.Key) && IsPrefabLocked(w.EntityManager,pair.Key)) throw new InvalidOperationException("development_purchase_pending_verify_get_devtree_first");
            var attempt=new JObject { ["purchaseId"]=Guid.NewGuid().ToString("N"), ["pointsBefore"]=before, ["cost"]=node["cost"], ["status"]="pending_or_unknown_do_not_repeat" };
            developmentAttempts[e]=attempt;
            system.Purchase(e);
            attempt["pointsAfter"]=system.points;
            return new JObject { ["status"]="accepted_pending_verification", ["purchase"]=attempt.DeepClone(), ["node"]=NativeBuild.Id(e),
                ["nextAction"]="Do not purchase again. Read get_devtree to verify this node unlocked. If still pending, run one authorized bounded settle interval then read again. Separately check the intended building lock. A method return or points deduction is not completion." };
        }
    }
}
