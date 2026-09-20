using System.Collections.Generic;
using Colossal;
using Game.Modding;
using Game.Settings;

namespace CitiesIIAgentBridge
{
    public sealed class BridgeSettings : ModSetting
    {
        public BridgeSettings(IMod mod) : base(mod) { SetDefaults(); }

        [SettingsUISection("Main", "Control")]
        public bool AllowControl { get; set; }

        [SettingsUISection("Main", "Control")]
        [SettingsUIMultilineText]
        public string ControlStatus => System.IO.File.Exists(System.IO.Path.Combine(System.Environment.GetFolderPath(System.Environment.SpecialFolder.LocalApplicationData), "CitiesIIAgentBridge", "STOP"))
            ? "STOP latch is active. The access checkbox is held off. With the owner's permission, remove only %LOCALAPPDATA%/CitiesIIAgentBridge/STOP, then enable controls here."
            : "After loading a city, enable controls here and close Options before sending commands. Long operations return an ID: poll it instead of sending the command again.";

        public override void SetDefaults() { AllowControl = false; }
    }

    public sealed class LocaleEN : IDictionarySource
    {
        private readonly BridgeSettings settings;
        public LocaleEN(BridgeSettings settings) { this.settings = settings; }
        public IEnumerable<KeyValuePair<string, string>> ReadEntries(IList<IDictionaryEntryError> errors, Dictionary<string, int> indexCounts)
        {
            return new Dictionary<string, string>
            {
                { settings.GetSettingsLocaleID(), "Cities II Agent Bridge" },
                { settings.GetOptionTabLocaleID("Main"), "Bridge" },
                { settings.GetOptionGroupLocaleID("Control"), "Local control" },
                { settings.GetOptionLabelLocaleID(nameof(BridgeSettings.AllowControl)), "Allow local bridge controls" },
                { settings.GetOptionLabelLocaleID(nameof(BridgeSettings.ControlStatus)), "Bridge control status" },
                { settings.GetOptionDescLocaleID(nameof(BridgeSettings.ControlStatus)), "Why controls may be disabled and how to use the bridge." },
                { settings.GetOptionDescLocaleID(nameof(BridgeSettings.AllowControl)), "Allow construction, demolition, zoning, tile purchases, budgets, taxes, saves, and camera/simulation commands. Analysis commands pause the city. Bounded simulation steps pause when they finish or time out. Construction uses native placement checks and spending limits. Off after loading a city. With controls off, pause the city manually before inspection. If the checkbox switches off immediately, the STOP latch exists at %LOCALAPPDATA%/CitiesIIAgentBridge/STOP. After explicitly authorizing resume, remove only that file and re-enable this option. Close this menu before sending bridge commands." }
            };
        }
        public void Unload() { }
    }
}
