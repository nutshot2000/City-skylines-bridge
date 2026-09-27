using System;
using CitiesIIAgentBridge;
using Newtonsoft.Json.Linq;

internal static class PreviewTests
{
    internal static int Run()
    {
        int passed = 0;
        void Reject(string command, JObject args)
        {
            try { PreviewPolicy.Validate(command, args); }
            catch (ArgumentException) { passed++; return; }
            throw new Exception("Preview safety failed: " + command);
        }
        foreach (var command in new[] { "build_road", "build_network", "upgrade_network", "batch_execute", "demolish", "purchase_tiles" })
            Reject(command, new JObject { ["previewOnly"] = true });
        Reject("build_network", new JObject { ["previewOnly"] = "true" });
        Reject("batch_execute", JObject.Parse("{steps:[{command:'build_network',args:{}},{command:'build_network',args:{previewOnly:true}}]}"));
        foreach (var command in new[] { "place_building", "relocate_building", "preview_building", "zone_rectangle", "clear_zoning" })
        { PreviewPolicy.Validate(command, new JObject { ["previewOnly"] = true }); passed++; }
        PreviewPolicy.Validate("build_network", new JObject { ["previewOnly"] = false }); passed++;
        PreviewPolicy.Validate("batch_execute", JObject.Parse("{steps:[{command:'build_network',args:{}}]}")); passed++;
        return passed;
    }
}
