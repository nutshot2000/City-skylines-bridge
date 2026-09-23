using System;
using CitiesIIAgentBridge;
internal static class DevelopmentTests
{
    internal static int Run()
    {
        int n=0;
        void Check(bool ok,string label){if(!ok)throw new Exception(label);n++;Console.WriteLine("PASS: "+label);}
        Check(DevelopmentPolicy.Blocker(true,true,true,true,2,1,false)==null,"one unlocked prerequisite suffices");
        Check(DevelopmentPolicy.Blocker(true,true,false,false,1,1,false)==null,"root node has no prerequisite");
        Check(DevelopmentPolicy.Blocker(true,true,true,false,99,1,false)=="development_prerequisite_locked","points cannot bypass prerequisites");
        Check(DevelopmentPolicy.Blocker(true,false,false,false,99,1,false)=="service_gate_locked","points cannot bypass service gate");
        Check(DevelopmentPolicy.Blocker(true,true,false,false,0,1,false)=="insufficient_development_points","insufficient development points rejected");
        Check(DevelopmentPolicy.Blocker(false,true,false,false,99,1,false)=="development_node_already_unlocked","unlocked node cannot be purchased twice");
        Check(DevelopmentPolicy.Blocker(true,true,false,false,99,1,true)=="development_purchase_pending_verify_get_devtree_first","pending purchase cannot be repeated");
        Check(DevelopmentPolicy.Blocker(true,true,false,false,99,-1,false)=="invalid_development_cost","negative cost rejected");
        return n;
    }
}
