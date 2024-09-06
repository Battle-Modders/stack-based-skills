::StackBasedSkills.HooksMod.hook("scripts/skills/skill", function(q) {
	q.m.SBS_AddedStack <- 1;
	q.m.SBS_IsSerializedStack <- {
		[true] = 0,
		[false] = 0
	};

	q.isKeepingAddRemoveHistory <- function()
	{
		return !this.isStacking() && !this.isType(::Const.SkillType.Special) && (this.isType(::Const.SkillType.Perk) || !this.isType(::Const.SkillType.StatusEffect));
	}

	local original_removeSelf;
	q.removeSelf = function( __original )
	{
		original_removeSelf = __original;
		return function()
		{
			this.removeSelfByStack(::new(::IO.scriptFilenameByHash(this.ClassNameHash)).isSerialized());
		}
	}

	q.updateIsSerialized <- function()
	{
		if (this.m.SBS_IsSerializedStack[true] == 0 && this.m.SBS_IsSerializedStack[false] == 0)
		{
			throw "SBS_IsSerializedStack for " + this.getID() + " has both true and false at 0";
		}

		this.m.IsSerialized = this.m.SBS_IsSerializedStack[true] > 0;
	}

	q.removeSelfByStack <- function( _isSerialized = false )
	{
		if (!this.isKeepingAddRemoveHistory()) return original_removeSelf();

		local count = this.m.SBS_IsSerializedStack[_isSerialized];
		if (count == 0) return;

		this.m.SBS_IsSerializedStack[_isSerialized] = count - 1;
		if (--this.m.SBS_AddedStack == 0) return original_removeSelf();

		if (this.getID() == ::getModSetting(::StackBasedSkills.ID, "LoggingSkillID").getValue())
		{
			::StackBasedSkills.Mod.Debug.printLog("Before updateIsSerialized: " + this.m.IsSerialized);
			::StackBasedSkills.Mod.Debug.printLog("SBS_AddedStack: " + this.m.SBS_AddedStack);
			if (::StackBasedSkills.Mod.Debug.isEnabled()) ::MSU.Log.printData(this.m.SBS_IsSerializedStack, 99, false, 99);
		}

		this.updateIsSerialized();

		if (this.getID() == ::getModSetting(::StackBasedSkills.ID, "LoggingSkillID").getValue())
		{
			::StackBasedSkills.Mod.Debug.printLog("After updateIsSerialized (skill): " + this.m.IsSerialized);
			if (::StackBasedSkills.Mod.Debug.isEnabled()) ::MSU.Log.printData(this.m.SBS_IsSerializedStack, 99, false, 99);
		}

		// The actual item which provided this skill isn't unequipped yet because
		// the removeSelf is called BEFORE the item is unequipped. So, we iterate over
		// all items and skip the one that is going to be unequipped
		if (::MSU.isEqual(this.getContainer().getActor().getItems().m.SBS_ItemBeingUnequipped, this.getItem()))
		{
			foreach (item in this.getContainer().getActor().getItems().getAllItems())
			{
				if (::MSU.isEqual(item, this.getItem())) continue;

				foreach (skill in item.m.SkillPtrs)
				{
					if (skill.getID() == this.getID())
					{
						this.setItem(item);
						return;
					}
				}
			}
		}

		this.setItem(null);
	}
});
