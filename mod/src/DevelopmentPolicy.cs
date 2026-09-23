namespace CitiesIIAgentBridge
{
    internal static class DevelopmentPolicy
    {
        internal static string Blocker(bool locked,bool serviceAvailable,bool hasRequirements,bool anyUnlocked,int points,int cost,bool pending)
        {
            if(pending) return "development_purchase_pending_verify_get_devtree_first";
            if(!locked) return "development_node_already_unlocked";
            if(cost<0) return "invalid_development_cost";
            if(!serviceAvailable) return "service_gate_locked";
            if(hasRequirements && !anyUnlocked) return "development_prerequisite_locked";
            if(points<cost) return "insufficient_development_points";
            return null;
        }
    }
}
