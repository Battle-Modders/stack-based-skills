::StackBasedSkills <- {
	Version = "0.4.0",
	ID = "mod_stack_based_skills",
	Name = "Stack Based Skills",
};

::mods_registerMod(::StackBasedSkills.ID, ::StackBasedSkills.Version, ::StackBasedSkills.Name);
::mods_queue(::StackBasedSkills.ID, "mod_msu(>=1.2.0.rc.2)", function() {

	::StackBasedSkills.Mod <- ::MSU.Class.Mod(::StackBasedSkills.ID, ::StackBasedSkills.Version, ::StackBasedSkills.Name);
	::include("mod_stack_based_skills/mod_settings.nut");

	::MSU.new <- function( _script, _function = null )
	{
		local obj = ::new(_script);
		if (_function != null) _function(obj);
		return obj;
	}

	::include("mod_stack_based_skills/mod_stack_based_skills_v4.nut");
});
