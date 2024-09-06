::StackBasedSkills.HooksMod.hook("scripts/skills/skill_container", function(q) {
	q.addByStack <- function( _skill, _order = 0 )
	{
		_skill.m.IsSerialized = false;
		return this.add(_skill, _order);
	}

	q.add = @(__original) function( _skill, _order = 0 )
	{
		if (!_skill.isKeepingAddRemoveHistory()) return __original(_skill, _order);

		_skill.m.MSU_IsSerializedStack[_skill.m.IsSerialized] = 1;

		if (_skill.getID() == ::getModSetting(::StackBasedSkills.ID, "LoggingSkillID").getValue())
		{
			::StackBasedSkills.Mod.Debug.printLog(format("Adding Skill:\nMSU_AddedStack: %i\nIsSerialized: %s", _skill.m.MSU_AddedStack, _skill.m.IsSerialized + ""));
			::MSU.Log.printStackTrace();
		}

		local skills = clone this.m.Skills;
		skills.extend(this.m.SkillsToAdd);

		local skillToKeep = _skill;
		foreach (i, alreadyPresentSkill in skills)
		{
			if (alreadyPresentSkill.isGarbage() || alreadyPresentSkill.getID() != _skill.getID())
				continue;

			if (_skill.m.IsSerialized)
			{
				// We ignore stacking when trying to add a Serialized skill when a Serialized skill is already present
				if (alreadyPresentSkill.m.IsSerialized)
					break;

				// If already present skill is NOT serialized, and new skill IS serialized, then we intend to replace
				// the already present one with this new one (to ensure that the serialized skill's data is what is kept)
				_skill.m.MSU_IsSerializedStack = clone alreadyPresentSkill.m.MSU_IsSerializedStack;
				_skill.m.MSU_IsSerializedStack[true] = 1;
				_skill.m.MSU_AddedStack = alreadyPresentSkill.m.MSU_AddedStack;
			}
			else
			{
				// If the skill being added is NOT serialized, then just add it as a stack
				alreadyPresentSkill.m.MSU_IsSerializedStack[false]++;
				skillToKeep = alreadyPresentSkill;
			}

			local skillToDiscard = skillToKeep == _skill ? alreadyPresentSkill : _skill;
			skillToDiscard.m.IsGarbage = true;
			skillToKeep.m.MSU_AddedStack++;
			if (!::MSU.isNull(skillToDiscard.getItem()))
			{
				foreach (i, itemSkill in skillToDiscard.getItem().m.SkillPtrs)
				{
					if (itemSkill.getID() == skillToDiscard.getID())
					{
						skillToDiscard.getItem().m.SkillPtrs[i] = skillToKeep;
						skillToDiscard.setItem(null);
						break;
					}
				}
			}
			if (::MSU.isNull(skillToKeep.getItem())) skillToKeep.setItem(skillToDiscard.getItem());

			skillToKeep.updateIsSerialized();
			break;
		}

		if (skillToKeep.getID() == ::getModSetting(::StackBasedSkills.ID, "LoggingSkillID").getValue())
		{
			::StackBasedSkills.Mod.Debug.printLog(format("Skill in Container:\nMSU_AddedStack: %i\nIsSerialized: %s", skillToKeep.m.MSU_AddedStack, skillToKeep.m.IsSerialized + ""));
			if (::StackBasedSkills.Mod.Debug.isEnabled()) ::MSU.Log.printData(skillToKeep.m.MSU_IsSerializedStack, 99, false, 99);
		}

		return __original(_skill, _order);
	}

	q.remove = @(__original) function( _skill )
	{
		// ::logInfo(_skill.getID() + ": " + _skill.m.MSU_AddedStack);
		if (_skill.m.MSU_AddedStack == 1) return __original(_skill);
		else return _skill.removeSelf();
	}

	q.removeByID = @(__original) function( _skillID )
	{
		local skill = this.getSkillByID(_skillID);
		if (skill == null) return;

		if (skill.m.MSU_AddedStack == 1) return __original(_skillID);
		else return skill.removeSelf();
	}

	q.removeByStack <- function( _skill, _isSerialized = false )
	{
		return skill.removeSelfByStack(_isSerialized);
	}

	q.removeByStackByID <- function( _skillID, _isSerialized = false )
	{
		local skill = this.getSkillByID(_skillID);
		if (skill == null) return;

		return skill.removeSelfByStack(_isSerialized);
	}
});
