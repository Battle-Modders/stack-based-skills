::StackBasedSkills <- {
	Version = "0.5.1",
	ID = "mod_stack_based_skills",
	Name = "Stack Based Skills",
};

::StackBasedSkills.MH <- ::Hooks.register(::StackBasedSkills.ID, ::StackBasedSkills.Version, ::StackBasedSkills.Name);
::StackBasedSkills.MH.require("mod_msu"); // TODO: Can't put a version requirement right now due to a bug in Modern Hooks
::StackBasedSkills.MH.queue(">mod_msu", function() {

	::StackBasedSkills.Mod <- ::MSU.Class.Mod(::StackBasedSkills.ID, ::StackBasedSkills.Version, ::StackBasedSkills.Name);
	::StackBasedSkills.Mod.Registry.addModSource(::MSU.System.Registry.ModSourceDomain.GitHub, "https://github.com/Battle-Modders/stack-based-skills");
	::StackBasedSkills.Mod.Registry.setUpdateSource(::MSU.System.Registry.ModSourceDomain.GitHub);

	::include("mod_stack_based_skills/mod_settings.nut");

	foreach (file in ::IO.enumerateFiles("mod_stack_based_skills/hooks"))
	{
		::include(file);
	}
});
