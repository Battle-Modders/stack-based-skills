::StackBasedSkills <- {
	Version = "0.5.0",
	ID = "mod_stack_based_skills",
	Name = "Stack Based Skills",
};

::StackBasedSkills.HooksMod <- ::Hooks.register(::StackBasedSkills.ID, ::StackBasedSkills.Version, ::StackBasedSkills.Name);
::StackBasedSkills.HooksMod.require("mod_msu"); // TODO: Can't put a version requirement right now due to a bug in Modern Hooks
::StackBasedSkills.HooksMod.queue(">mod_msu", function() {

	::StackBasedSkills.Mod <- ::MSU.Class.Mod(::StackBasedSkills.ID, ::StackBasedSkills.Version, ::StackBasedSkills.Name);
	::StackBasedSkills.Mod.Registry.addModSource(::MSU.System.Registry.ModSourceDomain.GitHub, "https://github.com/Battle-Modders/stack-based-skills");
	::StackBasedSkills.Mod.Registry.setUpdateSource(::MSU.System.Registry.ModSourceDomain.GitHub);

	::include("mod_stack_based_skills/mod_settings.nut");

	::MSU.new <- function( _script, _function = null )
	{
		local obj = ::new(_script);
		if (_function != null) _function(obj);
		return obj;
	}

	::include("mod_stack_based_skills/mod_stack_based_skills_v4.nut");
});
