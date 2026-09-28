using System;

namespace CitiesIIAgentBridge
{
    // Which commands stop the simulation clock before they run.
    // Reads never pause (0.5.0): agents kept leaving the city frozen after every question.
    // Mutations keep the original pause-then-build behaviour the construction tools were validated with.
    public static class PausePolicy
    {
        public static readonly string[] Mutations =
        {
            "build_road", "build_network", "upgrade_network", "zone_rectangle", "clear_zoning",
            "place_building", "preview_building", "relocate_building", "demolish", "purchase_tiles",
            "purchase_node", "save_checkpoint", "batch_execute",
            "execute_neighborhood", "cancel_tool", "pause_for_analysis"
        };

        public static bool Pauses(string command, bool requested) =>
            requested || Array.IndexOf(Mutations, command) >= 0;
    }
}
