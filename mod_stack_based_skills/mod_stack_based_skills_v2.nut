/* Documentation
This version is built around the idea that only the IsSerialized variable of a skill need be tracked in its stacking addition/removal. (imo this is simpler and enough).
- By default we use the default value for IsSerialized defined in the skill's file.
- If you want to add a skill with modified IsSerialized, you add that manually by changing the value during addition.
- Then you are responsible for removing the stack with the appropraite value during removal.

e.g.
Shield Expert is serialized by default.
I add a non-serialized version of it to a character.
Calling the default "removeSelf" on this skill will use stacks of IsSerialized = true. Which are 0, so the skill will get removed.
If I want to remove the stack which wasn't serialized, I have to manually request that i.e. `removeSelfByStack( false )`

The opposite is true if one is adding a by-default non-serialized skill as serialized.
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
			if (script == "scripts/skills/skill_container") continue;

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

		this.m.IsSerialized = this.m.MSU_IsSerializedStack[true] > 0 || this.m.MSU_IsSerializedStack[::MSU.Skills.ClassNameHashToIsSerializedMap[this.ClassNameHash]] > 0;
	}

	o.removeSelfByStack <- function( _isSerialized )
	{
		if (!this.isKeepingAddRemoveHistory()) return removeSelf();
		if (--this.m.MSU_AddedStack == 0) return removeSelf();

		// ::logInfo(this.m.MSU_AddedStack);

		local count = this.m.MSU_IsSerializedStack[_isSerialized];
		if (count > 0) this.m.MSU_IsSerializedStack[_isSerialized] = count - 1;
		else throw "trying to remove " + this.getID() + " but all its stacked additions with \'IsSerialized = " + value + "\' have already been removed";

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
	local add = o.add;
	o.add = function( _skill, _order = 0 )
	{
		if (!_skill.isKeepingAddRemoveHistory()) return add(_skill, _order);

		_skill.m.MSU_IsSerializedStack[_skill.m.IsSerialized]++;

		if (_skill.getID() == ::getModSetting(::StackBasedSkills.ID, "LoggingSkillID").getValue())
		{
			::StackBasedSkills.Mod.Debug.printLog("Adding Skill: " + _skill.getID());
			::StackBasedSkills.Mod.Debug.printLog("MSU_AddedStack: " + _skill.m.MSU_AddedStack);
			::StackBasedSkills.Mod.Debug.printLog("IsSerialized (skill): " + _skill.m.IsSerialized);
			if (::StackBasedSkills.Mod.Debug.isEnabled()) ::MSU.Log.printData(_skill.m.MSU_IsSerializedStack, 99, false, 99);
		}

		local skills = clone this.m.Skills;
		skills.extend(this.m.SkillsToAdd);

		foreach (i, alreadyPresentSkill in skills)
		{
			if (alreadyPresentSkill.getID() == _skill.getID())
			{
				if (!::MSU.isNull(_skill.getItem()))
				{
					if (::MSU.isNull(alreadyPresentSkill.getItem())) alreadyPresentSkill.setItem(_skill.getItem());
					foreach (j, itemSkill in _skill.getItem().m.SkillPtrs)
					{
						if (itemSkill.getID() == _skill.getID())
						{
							_skill.getItem().m.SkillPtrs[j] = alreadyPresentSkill;
							_skill.setItem(null);
							break;
						}
					}
				}

				if (alreadyPresentSkill.m.IsSerialized && _skill.m.IsSerialized)
					break;

				if (++alreadyPresentSkill.m.MSU_AddedStack > 0)
					alreadyPresentSkill.m.IsGarbage = false;

				alreadyPresentSkill.m.MSU_IsSerializedStack[_skill.m.IsSerialized]++;

				alreadyPresentSkill.updateIsSerialized();

				if (alreadyPresentSkill.getID() == ::getModSetting(::StackBasedSkills.ID, "LoggingSkillID").getValue())
				{
					::StackBasedSkills.Mod.Debug.printLog("Already present skill:");
					::StackBasedSkills.Mod.Debug.printLog("MSU_AddedStack: " + alreadyPresentSkill.m.MSU_AddedStack);
					::StackBasedSkills.Mod.Debug.printLog("IsSerialized (skill): " + alreadyPresentSkill.m.IsSerialized);
					if (::StackBasedSkills.Mod.Debug.isEnabled()) ::MSU.Log.printData(alreadyPresentSkill.m.MSU_IsSerializedStack, 99, false, 99);
				}

				break;
			}
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

	o.removeByStack <- function( _skill, _isSerialized )
	{
		if (skill.m.MSU_AddedStack == 1) return remove(_skillID);
		else return skill.removeSelfByStack(_isSerialized);
	}

	o.removeByStackByID <- function( _skillID, _isSerialized )
	{
		local skill = this.getSkillByID(_skillID);
		if (skill == null) return;

		if (skill.m.MSU_AddedStack == 1) return removeByID(_skillID);
		else return skill.removeSelfByStack(_isSerialized);
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

// ::mods_hookNewObject("entity/tactical/tactical_entity_manager", function(o) {
// 	local spawn = o.spawn;
// 	o.spawn = function( _properties )
// 	{
// 		local ret = spawn(_properties);
// 		foreach (i, faction in this.getAllInstances())
// 		{
// 			if (i != ::Const.Faction.Player)
// 			{
// 				foreach (actor in faction)
// 				{
// 					actor.getSkills().onCombatStarted();
// 					actor.getItems().onCombatStarted();
// 					actor.getSkills().update();
// 				}
// 			}
// 		}

// 		::Math.seedRandom(::Time.getRealTime());
// 	}
// });

// Test perk
// ::mods_hookExactClass("skills/perks/perk_colossus", function(o) {
// 	o.onCombatStarted <- function()
// 	{
// 		::logInfo(this.getContainer().getActor().getID() + " onCombatStarted");
// 	}
// 	o.onCombatFinished <- function()
// 	{
// 		::logInfo(this.getContainer().getActor().getID() + " onCombatFinished");
// 	}
// 	o.onEquip <- function( _item )
// 	{
// 		if (_item.getSlotType() != ::Const.ItemSlot.Mainhand) return;

// 		// Add Shield Expert, Reach Advantage, and Duelist while a weapon is equipped
// 		// But add non-permanent (i.e. IsSerialized = false) versions of these skills

// 		this.getContainer().add(::MSU.new("scripts/skills/perks/perk_shield_expert", function(o) {
// 			o.m.IsSerialized = false;
// 			// o.m.IsRefundable = false;
// 		}));
// 		this.getContainer().add(::MSU.new("scripts/skills/perks/perk_reach_advantage", function(o) {
// 			o.m.IsSerialized = false;
// 			// o.m.IsRefundable = false;
// 		}));
// 		this.getContainer().add(::MSU.new("scripts/skills/perks/perk_duelist", function(o) {
// 			o.m.IsSerialized = false;
// 			// o.m.IsRefundable = false;
// 		}));

// 		// add shield_expert permanently (i.e. normal IsSerialized = true version)
// 		// for testing the stacking addition/removal of serialized skills
// 		this.getContainer().add(::MSU.new("scripts/skills/perks/perk_shield_expert"));
// 	}

// 	o.onUnequip <- function( _item )
// 	{
// 		// Remove the Shield Expert, Reach Advantage and Duelist skills when a weapon is unequipped
// 		// But we must remove the "non-permanent" i.e. "IsSerialized = false" versions of these skills (that we added in onEquip)

// 		this.getContainer().removeByStackByID("perk.shield_expert", false);
// 		this.getContainer().removeByStackByID("perk.reach_advantage", false);
// 		this.getContainer().removeByStackByID("perk.duelist", false);
// 	}

// 	o.onAdded <- function()
// 	{
// 		local equippedItem = this.getContainer().getActor().getMainhandItem();
// 		if (equippedItem != null)
// 		{
// 			this.getContainer().getActor().getItems().unequip(equippedItem);
// 			this.getContainer().getActor().getItems().equip(equippedItem);
// 		}
// 	}

// 	o.onRemoved <- function()
// 	{
// 		local equippedItem = this.getContainer().getActor().getMainhandItem();
// 		if (equippedItem != null)
// 		{
// 			this.getContainer().getActor().getItems().unequip(equippedItem);
// 			this.getContainer().getActor().getItems().equip(equippedItem);
// 		}
// 	}
// });


