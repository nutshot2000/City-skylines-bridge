using System;
using Newtonsoft.Json.Linq;

namespace CitiesIIAgentBridge
{
    internal static class PreviewPolicy
    {
        // Validate the entire batch before dispatch can pause or execute its first step.
        internal static void Validate(string command, JObject args)
        {
            var preview = args?["previewOnly"];
            if (preview != null && preview.Type != JTokenType.Boolean)
                throw new ArgumentException("previewOnly_must_be_boolean");
            if ((bool?)preview == true && command != "place_building" && command != "relocate_building" && command != "preview_building" && command != "zone_rectangle" && command != "clear_zoning")
                throw new ArgumentException("preview_not_supported_for_" + command + "_nothing_executed_do_not_retry_without_previewOnly_unless_real_construction_is_authorized");
            if (command == "batch_execute" && args?["steps"] is JArray steps)
                foreach (var step in steps)
                    if (step is JObject row && row["args"] is JObject stepArgs)
                        Validate((string)row["command"], stepArgs);
        }
    }
}
