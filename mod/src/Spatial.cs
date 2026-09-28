using System;
using System.Linq;
using Game.Prefabs;
using Newtonsoft.Json.Linq;
using Unity.Entities;
using Unity.Mathematics;

namespace CitiesIIAgentBridge
{
    public sealed partial class Mod
    {
        private JObject Footprint(Unity.Entities.World w, Entity e)
        {
            var em=w.EntityManager; var t=em.GetComponentData<Game.Objects.Transform>(e); var pe=em.GetComponentData<PrefabRef>(e).m_Prefab;
            var row=NativeBuild.Id(e); row["prefab"]=w.GetExistingSystemManaged<PrefabSystem>().GetPrefabName(pe); row["position"]=Vector(t.m_Position);
            row["rotation"]=new JArray(t.m_Rotation.value.x,t.m_Rotation.value.y,t.m_Rotation.value.z,t.m_Rotation.value.w);
            float2 half=em.HasComponent<BuildingData>(pe)?(float2)em.GetComponentData<BuildingData>(pe).m_LotSize*4:new float2(4);
            row["halfSize"]=new JArray(half.x,half.y);
            var corners=new JArray(); foreach(var p in new[]{new float3(-half.x,0,-half.y),new float3(half.x,0,-half.y),new float3(half.x,0,half.y),new float3(-half.x,0,half.y)}) corners.Add(Vector(t.m_Position+math.mul(t.m_Rotation,p)));
            row["polygon"]=corners; row["underConstruction"]=em.HasComponent<Game.Objects.UnderConstruction>(e);
            row["roadEdge"]=NativeBuild.Id(em.GetComponentData<Game.Buildings.Building>(e).m_RoadEdge);
            row["shortages"]=Shortages(em,e);
            return row;
        }
        private JObject CityMap(JObject args)
        {
            var w=RequireCity(); float x=RequiredFloat(args,"x"),z=RequiredFloat(args,"z"),radius=RequiredFloat(args,"radius");
            if(radius<16 || radius>500) throw new ArgumentException("map_radius_must_be_16_to_500");
            var buildings=new JArray();
            foreach(var e in NativeBuild.Buildings(w.EntityManager).OrderBy(e=>e.Index))
            {
                var em=w.EntityManager; if(!em.HasComponent<Game.Objects.Transform>(e)||em.HasComponent<PrefabData>(e)) continue;
                if(math.distance(em.GetComponentData<Game.Objects.Transform>(e).m_Position.xz,new float2(x,z))>radius+200) continue;
                buildings.Add(Footprint(w,e));
            }
            var zoneArgs=(JObject)args.DeepClone(); zoneArgs["limit"]=65536; zoneArgs["offset"]=0;
            var zones=ZoneCells(zoneArgs); var terrainPoints=new JArray(); float spacing=Math.Max(16,radius/15);
            var catalog=new JObject();
            using(var query=w.EntityManager.CreateEntityQuery(ComponentType.ReadOnly<ZoneData>()))
            using(var entities=query.ToEntityArray(Unity.Collections.Allocator.Temp)) foreach(var e in entities)
            {
                if(!w.EntityManager.HasComponent<PrefabData>(e))continue;
                var zone=w.EntityManager.GetComponentData<ZoneData>(e);
                catalog[zone.m_ZoneType.m_Index.ToString()]=new JObject{["name"]=w.GetExistingSystemManaged<PrefabSystem>().GetPrefabName(e),["areaType"]=zone.m_AreaType.ToString()};
            }
            zones["catalog"]=catalog;
            for(float px=x-radius;px<=x+radius;px+=spacing) for(float pz=z-radius;pz<=z+radius;pz+=spacing)
                terrainPoints.Add(new JObject{["x"]=px,["z"]=pz});
            return new JObject { ["citySession"]=citySession,["simulationFrame"]=CityState()["simulationFrame"], ["paused"]=(float)CityState()["selectedSpeed"]==0,
                ["bounds"]=new JObject{["minX"]=x-radius,["maxX"]=x+radius,["minZ"]=z-radius,["maxZ"]=z+radius},
                ["buildings"]=buildings,["network"]=NetworkEdges(args),["zoning"]=zones,["terrain"]=Terrain(new JObject{["points"]=terrainPoints}),["tiles"]=Tiles(),
                ["units"]="World metres; footprints are oriented zoning-lot rectangles. Terrain samples are a coarse grid, not a placement guarantee." };
        }
        private JObject FindBuildingSites(JObject args)
        {
            var w=RequireCity(); var em=w.EntityManager; var prefab=BuildPrefab<BuildingPrefab>(w,args); var pe=w.GetExistingSystemManaged<PrefabSystem>().GetEntity(prefab);
            if(!em.HasComponent<BuildingData>(pe)) throw new ArgumentException("building_lot_data_required");
            var lot=em.GetComponentData<BuildingData>(pe).m_LotSize;
            float radius=args["radius"]==null?150:RequiredFloat(args,"radius"); if(radius<16||radius>500) throw new ArgumentException("site_radius_must_be_16_to_500");
            float x=RequiredFloat(args,"x"),z=RequiredFloat(args,"z");
            var edges=(JArray)NetworkEdges(new JObject{["x"]=x,["z"]=z,["radius"]=radius})["edges"];
            var candidates=new JArray(); int overlapping=0, outsideCity=0;
            var owned=OwnedTileBoxes(w);
            foreach(JObject edge in edges.OrderBy(e=> (int)e["index"]))
            {
                var entity=new Entity{Index=(int)edge["index"],Version=(int)edge["version"]};
                if(!em.HasComponent<Game.Net.Road>(entity)) continue;
                var netPrefab=em.GetComponentData<PrefabRef>(entity).m_Prefab;
                float halfRoad=em.HasComponent<NetGeometryData>(netPrefab)?em.GetComponentData<NetGeometryData>(netPrefab).m_DefaultWidth*0.5f:8;
                var curve=em.GetComponentData<Game.Net.Curve>(entity).m_Bezier;
                foreach(float t in new[]{0.1f,0.25f,0.4f,0.5f,0.6f,0.75f,0.9f}) foreach(int side in new[]{-1,1})
                {
                    float u=1-t; float3 centre=u*u*u*curve.a+3*u*u*t*curve.b+3*u*t*t*curve.c+t*t*t*curve.d;
                    float3 tangent=math.normalizesafe(3*u*u*(curve.b-curve.a)+6*u*t*(curve.c-curve.b)+3*t*t*(curve.d-curve.c));
                    float3 outward=new float3(-tangent.z,0,tangent.x)*side;
                    float3 pos=centre+outward*(halfRoad+lot.y*4); if(math.distance(pos.xz,new float2(x,z))>radius) continue;
                    // Local +Z is the front of the lot, facing back toward the road.
                    float rotation=math.degrees(math.atan2(-outward.x,-outward.z));
                    // The game refuses buildings outside purchased map tiles; find_building_sites used to suggest them.
                    if(owned.Count>0 && !owned.Any(b=>pos.x>=b.x && pos.x<=b.z && pos.z>=b.y && pos.z<=b.w)) { outsideCity++; continue; }
                    var candidate=new JObject{["position"]=Vector(pos),["rotation"]=rotation,["roadEdge"]=NativeBuild.Id(entity),["curvePosition"]=t};
                    if(!LotOverlaps(w,pos,quaternion.RotateY(math.radians(rotation)),(float2)lot*4,Entity.Null)) candidates.Add(candidate); else overlapping++;
                }
            }
            var sorted=new JArray(candidates.OrderBy(c=>math.distance(new float2((float)c["position"]["x"],(float)c["position"]["z"]),new float2(x,z))).Take(16));
            return new JObject{["prefabIndex"]=pe.Index,["prefabVersion"]=pe.Version,["lotSizeCells"]=new JArray(lot.x,lot.y),["lotSizeMetres"]=new JArray(lot.x*8,lot.y*8),
                ["candidates"]=sorted,["rejectedOverlappingBuildings"]=overlapping,["rejectedOutsideOwnedTiles"]=outsideCity,
                ["next"]=sorted.Count==0?"No free road-side lot here. Roadsides are taken by buildings, or the area is outside your land. Build a short road into empty unzoned land you own, then retry near it.":null,
                ["validation"]="Geometric candidates only. Native preview checks road access, terrain, zoning, cost, and remaining collisions before placement."};
        }
        // Purchased map tiles as axis-aligned boxes: x=minX, y=minZ, z=maxX, w=maxZ.
        private static System.Collections.Generic.List<float4> OwnedTileBoxes(Unity.Entities.World w)
        {
            var em=w.EntityManager; var boxes=new System.Collections.Generic.List<float4>();
            using(var q=em.CreateEntityQuery(ComponentType.ReadOnly<Game.Areas.MapTile>()))
            using(var es=q.ToEntityArray(Unity.Collections.Allocator.Temp)) foreach(var e in es)
            {
                if(em.HasComponent<Game.Common.Native>(e) || !em.HasBuffer<Game.Areas.Node>(e)) continue;
                var b=new float4(float.MaxValue,float.MaxValue,float.MinValue,float.MinValue);
                foreach(var n in em.GetBuffer<Game.Areas.Node>(e,true)) b=new float4(math.min(b.x,n.m_Position.x),math.min(b.y,n.m_Position.z),math.max(b.z,n.m_Position.x),math.max(b.w,n.m_Position.z));
                boxes.Add(b);
            }
            return boxes;
        }
        private static bool LotOverlaps(Unity.Entities.World w,float3 p,quaternion rotation,float2 half,Entity ignore)
        {
            var em=w.EntityManager;
            foreach(var e in NativeBuild.Buildings(em))
            {
                if(e==ignore||!em.HasComponent<Game.Objects.Transform>(e)||!em.HasComponent<PrefabRef>(e)||em.HasComponent<PrefabData>(e)) continue;
                var pe=em.GetComponentData<PrefabRef>(e).m_Prefab; if(!em.HasComponent<BuildingData>(pe)) continue;
                var t=em.GetComponentData<Game.Objects.Transform>(e); var b=(float2)em.GetComponentData<BuildingData>(pe).m_LotSize*4;
                if(math.distance(p.xz,t.m_Position.xz)>math.length(half)+math.length(b)) continue;
                if(PlanGeometry.Overlap(Box(p,rotation,half),Box(t.m_Position,t.m_Rotation,b))) return true;
            }
            return false;
        }
        private static double[][] Box(float3 p,quaternion q,float2 half)
        {
            return new[]{new float3(-half.x,0,-half.y),new float3(half.x,0,-half.y),new float3(half.x,0,half.y),new float3(-half.x,0,half.y)}
                .Select(a=>p+math.mul(q,a)).Select(a=>new[]{(double)a.x,(double)a.z}).ToArray();
        }
    }
}
