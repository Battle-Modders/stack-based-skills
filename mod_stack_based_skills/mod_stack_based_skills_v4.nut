/* Documentation
This is an improved/fixed version of v2.
This version is built around the idea that for skills we only keep a single stack of "IsSerialized" versin of the skill
but keep infinite stacks of "IsSerialized = false" versions of the skill.
- By default we use the default value for IsSerialized defined in the skill's file.
- If you want to add a skill with modified IsSerialized, you add that manually by changing the value during addition.
- Then you are responsible for removing the stack with the appropriate value during removal.
- Use addByStack and removeByStack type functions - which automatically set and assume the IsSerialized to be false.
- Removing by stack does nothing if no stack of IsSerialized with the passed value exists.

e.g.
Shield Expert is serialized by default.
I add a non-serialized version of it to a character.
Calling the default "removeSelf" on this skill will use stacks of IsSerialized = true. Which are 0, so the skill will NOT be removed.
If I want to remove the stack which wasn't serialized, I have to manually request that i.e. `removeSelfByStack(false)` // defaults to false
*/

::MSU.Skills.ClassNameHashToIsSerializedMap <- {};

::mods_hookExactClass("root_state", function(o) {
	local onInit = o.onInit;
	o.onInit = function()
	{
		// add the slot because a vanilla teleport_skill tries to access it in its create() function
		::MapGen <- ::new("scripts/mapgen/map_generator");

		foreach (script in ::IO.enumerateFiles("scripts/skills"))
		{
			if (script == "scripts/skills/skill_container" || script == "scripts/skills/skill") continue;

			try
			{
				// Store the default value of every skill's IsSerialized
				// This is used in the `removeSelf` function to pass the default value for this skill
				local skill = ::new(script);
				::MSU.Skills.ClassNameHashToIsSerializedMap[skill.ClassNameHash] <- skill.isSerialized();
			}
			catch (error)
			{
				::logError("Could not instaniate or get ClassNameHash or isSerialized() of skill: " + script + ". Error: " + error);
			}
		}

		delete ::MapGen;

		return onInit();
	}
});

::mods_hookBaseClass("skills/skill", function(o) {
	o = o[o.SuperName];

	o.m.MSU_AddedStack <- 1;
	o.m.MSU_IsSerializedStack <- {
		[true] = 0,
		[false] = 0
	};

	o.isKeepingAddRemoveHistory <- function()
	{
		return !this.isStacking() && !this.isType(::Const.SkillType.Special) && (this.isType(::Const.SkillType.Perk) || !this.isType(::Const.SkillType.StatusEffect));
	}

	local removeSelf = o.removeSelf;
	o.removeSelf = function()
	{
		this.removeSelfByStack(::MSU.Skills.ClassNameHashToIsSerializedMap[this.ClassNameHash]);
	}

	o.updateIsSerialized <- function()
	{
		if (this.m.MSU_IsSerializedStack[true] == 0 && this.m.MSU_IsSerializedStack[false] == 0)
		{
			throw "MSU_IsSerializedStack for " + this.getID() + " has both true and false at 0";
		}

		this.m.IsSerialized = this.m.MSU_IsSerializedStack[true] > 0;
	}

	o.removeSelfByStack <- function( _isSerialized = false )
	{
		if (!this.isKeepingAddRemoveHistory()) return removeSelf();

		local count = this.m.MSU_IsSerializedStack[_isSerialized];
		if (count == 0) return;

		this.m.MSU_IsSerializedStack[_isSerialized] = count - 1;
		if (--this.m.MSU_AddedStack == 0) return removeSelf();

		this.updateIsSerialized();

		if (this.getID() == ::getModSetting(::StackBasedSkills.ID, "LoggingSkillID").getValue())
		{
			::StackBasedSkills.Mod.Debug.printLog("IsSerialized (skill): " + this.m.IsSerialized);
			if (::StackBasedSkills.Mod.Debug.isEnabled()) ::MSU.Log.printData(this.m.MSU_IsSerializedStack, 99, false, 99);
		}

		// The actual item which provided this skill isn't unequipped yet because
		// the removeSelf is called BEFORE the item is unequipped. So, we iterate over
		// all items and skip the one that is going to be unequipped
		if (::MSU.isEqual(this.getContainer().getActor().getItems().m.MSU_ItemBeingUnequipped, this.getItem()))
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

::mods_hookNewObject("skills/skill_container", function(o) {
	o.addByStack <- function( _skill, _order = 0 )
	{
		_skill.m.IsSerialized = false;
		return this.add(_skill, _order);
	}

	local add = o.add;
	o.add = function( _skill, _order = 0 )
	{
		if (!_skill.isKeepingAddRemoveHistory()) return add(_skill, _order);

		_skill.m.MSU_IsSerializedStack[_skill.m.IsSerialized] = 1;

		if (_skill.getID() == ::getModSetting(::StackBasedSkills.ID, "LoggingSkillID").getValue())
		{
			::StackBasedSkills.Mod.Debug.printLog(format("Adding Skill:\nMSU_AddedStack: %i\nIsSerialized: %s", _skill.m.MSU_AddedStack, _skill.m.IsSerialized + ""));
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
				_skill.m.MSU_IsSerializedStack[true] = 1;
				_skill.m.MSU_IsSerializedStack = clone alreadyPresentSkill.m.MSU_IsSerializedStack;
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

		return add(_skill, _order);
	}

	local remove = o.remove;
	o.remove = function( _skill )
	{
		// ::logInfo(_skill.getID() + ": " + _skill.m.MSU_AddedStack);
		if (_skill.m.MSU_AddedStack == 1) return remove(_skill);
		else return _skill.removeSelf();
	}

	local removeByID = o.removeByID;
	o.removeByID = function( _skillID )
	{
		local skill = this.getSkillByID(_skillID);
		if (skill == null) return;

		if (skill.m.MSU_AddedStack == 1) return removeByID(_skillID);
		else return skill.removeSelf();
	}

	o.removeByStack <- function( _skill, _isSerialized = false )
	{
		return skill.removeSelfByStack(_isSerialized);
	}

	o.removeByStackByID <- function( _skillID, _isSerialized = false )
	{
		local skill = this.getSkillByID(_skillID);
		if (skill == null) return;

		return skill.removeSelfByStack(_isSerialized);
	}
});

::mods_hookNewObject("items/item_container", function(o) {
	o.m.MSU_ItemBeingUnequipped <- null;

	local unequip = o.unequip;
	o.unequip = function( _item )
	{
		// This variable is needed for proper functionality in the skill.removeSelf function because
		// in that function we want to know if the item being unequipped is the one that is attached to that skill
		// and skills are removed before the item is unequipped
		this.m.MSU_ItemBeingUnequipped = _item;
		local ret = unequip(_item);
		this.m.MSU_ItemBeingUnequipped = null;

		return ret;
	}
});

// Test perk
// ::mods_hookExactClass("skills/perks/perk_colossus", function(o) {
// 	o.onEquip <- function( _item )
// 	{
// 		if (_item.getSlotType() != ::Const.ItemSlot.Mainhand) return;

// 	// 	// Add Shield Expert, Reach Advantage, and Duelist while a weapon is equipped
// 	// 	// But add non-permanent (i.e. IsSerialized = false) versions of these skills

// 		this.getContainer().addByStack(::new("scripts/skills/perks/perk_shield_expert"));
// 		this.getContainer().addByStack(::new("scripts/skills/perks/perk_reach_advantage"));
// 		this.getContainer().addByStack(::new("scripts/skills/perks/perk_duelist"));
// 	}

// 	o.onUnequip <- function( _item )
// 	{
// 		// Remove the Shield Expert, Reach Advantage and Duelist skills when a weapon is unequipped
// 		// But we must remove the "non-permanent" i.e. "IsSerialized = false" versions of these skills (that we added in onEquip)
// 		if (_item.getSlotType() != ::Const.ItemSlot.Mainhand) return;

// 		this.getContainer().removeByStackByID("perk.shield_expert");
// 		this.getContainer().removeByStackByID("perk.reach_advantage");
// 		this.getContainer().removeByStackByID("perk.duelist");
// 	}

// 	o.onAdded <- function()
// 	{
// 		// this.getContainer().addByStack(::new("scripts/skills/perks/perk_shield_expert"));
// 		// this.getContainer().addByStack(::new("scripts/skills/perks/perk_reach_advantage"));
// 		// this.getContainer().addByStack(::new("scripts/skills/perks/perk_duelist"));
// 		local equippedItem = this.getContainer().getActor().getMainhandItem();
// 		if (equippedItem != null)
// 		{
// 			this.getContainer().getActor().getItems().unequip(equippedItem);
// 			this.getContainer().getActor().getItems().equip(equippedItem);
// 		}
// 	}

// 	o.onRemoved <- function()
// 	{
// 		// local equippedItem = this.getContainer().getActor().getMainhandItem();
// 		// if (equippedItem != null)
// 		// {
// 		// 	this.getContainer().getActor().getItems().unequip(equippedItem);
// 		// 	this.getContainer().getActor().getItems().equip(equippedItem);
// 		// }
// 	}
// });
