::StackBasedSkills.Mod.Debug.disable();
local page = ::StackBasedSkills.Mod.ModSettings.addPage("Logging");
local setting = page.addBooleanSetting("EnableLogging", false, "Enable Logging", "Print to log when adding/removing a skill.");
setting.addAfterChangeCallback(function( _oldValue ) {
	if (this.getValue()) ::StackBasedSkills.Mod.Debug.enable();
	else ::StackBasedSkills.Mod.Debug.disable();
});
page.addStringSetting("LoggingSkillID", "", "Skill ID", "Logging will trigger only for this skill id");
