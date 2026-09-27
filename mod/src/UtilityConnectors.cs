using System;
using System.Collections.Generic;
using Game.Common;
using Game.Prefabs;
using Game.Simulation;
using Game.Tools;
using Newtonsoft.Json.Linq;
using Unity.Entities;

namespace CitiesIIAgentBridge
{
    public sealed partial class Mod
    {
        private JObject UtilityConnectors(JObject args)
        {
            var w=RequireCity(); var em=w.EntityManager; var ps=w.GetExistingSystemManaged<PrefabSystem>();
            var root=new Entity { Index=RequiredInt(args,"index"), Version=RequiredInt(args,"version") };
            if(!em.Exists(root)) throw new ArgumentException("entity_not_found_or_stale");
            var queue=new Queue<Entity>(); var seen=new HashSet<Entity>(); var rows=new JArray();
            queue.Enqueue(root); bool truncated=false;
            while(queue.Count>0)
            {
                if(seen.Count>=512 || rows.Count>=128){truncated=true;break;}
                var e=queue.Dequeue();
                if(!seen.Add(e) || !em.Exists(e) || em.HasComponent<Temp>(e) || em.HasComponent<Deleted>(e))continue;
                if(em.HasBuffer<Game.Net.SubNet>(e)) foreach(var sub in em.GetBuffer<Game.Net.SubNet>(e,true)) queue.Enqueue(sub.m_SubNet);
                if(e==root && em.HasComponent<Game.Buildings.Building>(e)) queue.Enqueue(em.GetComponentData<Game.Buildings.Building>(e).m_RoadEdge);
                if(em.HasComponent<Game.Net.Edge>(e)) {var edge=em.GetComponentData<Game.Net.Edge>(e);queue.Enqueue(edge.m_Start);queue.Enqueue(edge.m_End);}
                if(!em.HasComponent<Game.Net.Node>(e))continue;
                bool water=em.HasComponent<WaterPipeNodeConnection>(e) && em.Exists(em.GetComponentData<WaterPipeNodeConnection>(e).m_WaterPipeNode);
                bool power=em.HasComponent<ElectricityNodeConnection>(e) && em.Exists(em.GetComponentData<ElectricityNodeConnection>(e).m_ElectricityNode);
                if(!water && !power)continue;
                var row=NativeBuild.Id(e); var position=em.GetComponentData<Game.Net.Node>(e).m_Position;
                row["position"]=Vector(position); row["waterFamily"]=water; row["electricityFamily"]=power;
                row["evidence"]="reachable_via_entity_subnets_or_building_road_reference_not_proof_of_service";
                var edges=new JArray();
                if(em.HasBuffer<Game.Net.ConnectedEdge>(e))foreach(var link in em.GetBuffer<Game.Net.ConnectedEdge>(e,true))
                {
                    var edge=link.m_Edge;if(!em.Exists(edge)||em.HasComponent<Temp>(edge)||em.HasComponent<Deleted>(edge)||!em.HasComponent<PrefabRef>(edge))continue;
                    var p=em.GetComponentData<PrefabRef>(edge).m_Prefab;var info=NativeBuild.Id(edge);
                    info["prefabName"]=ps.GetPrefabName(p);
                    if(em.HasComponent<ElectricityConnectionData>(p)){var d=em.GetComponentData<ElectricityConnectionData>(p);info["voltage"]=d.m_Voltage.ToString();info["electricityCapacity"]=d.m_Capacity;}
                    if(em.HasComponent<WaterPipeConnectionData>(p)){var d=em.GetComponentData<WaterPipeConnectionData>(p);info["freshCapacity"]=d.m_FreshCapacity;info["sewageCapacity"]=d.m_SewageCapacity;}
                    edges.Add(info);
                }
                row["incidentEdges"]=edges;row["liveDegree"]=edges.Count;row["terminalOrOpenEnd"]=edges.Count<=1;
                row["attachment"] = new JObject { ["x"]=position.x,["y"]=position.y,["z"]=position.z,["index"]=e.Index,["version"]=e.Version };
                rows.Add(row);
            }
            return new JObject { ["entity"]=NativeBuild.Id(root),["candidates"]=rows,["truncated"]=truncated,
                ["status"]=rows.Count==0?"no_verified_connector_candidates":"inspect_candidate_layers_before_planning",
                ["next"]="Discover both source and consumer. Match voltage and fresh/sewage capacity from incident edges; absent fields mean unknown. Use connection-check on chosen node IDs. Candidates are references, not proof of supply; do not pick by proximity alone." };
        }
    }
}
