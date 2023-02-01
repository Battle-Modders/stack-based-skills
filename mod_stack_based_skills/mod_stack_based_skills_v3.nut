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
::MSU.Skills.ClassNameHashToDefaultValuesMap <- {};
	::MSU.Skills.StackedFields <- { // Provide non-stacking values for stacked fields
		"IsSerialized": true,
		"IsRefundable": false
	};

::mods_hookExactClass("root_state", function(o) {
	local onInit = o.onInit;
	o.onInit = function()
	{
		// add the slot because a vanilla teleport_skill tries to access it in its create() function
		::MapGen <- ::new("scripts/mapgen/map_generator");

		foreach (script in ::IO.enumerateFiles("scripts/skills"))
		{
			if (script == "scripts/skills/skill_container" || script = "scripts/skills/skill") continue;

			try
			{
				// Store the default value of every skill's IsSerialized
				// This is used in the `removeSelf` function to pass the default value for this skill
				local skill = ::new(script);
				local valuesMap = {};
				foreach (fieldName, preferredValue in ::MSU.Skills.StackedFields)
				{
					valuesMap[fieldName] <- skill.m[fieldName];
				}
				::MSU.Skills.ClassNameHashToDefaultValuesMap[skill.ClassNameHash] <- valuesMap;
			}
			catch (error)
			{
				::logError("Error saving default values of: " + script + ". Error: " + error);
			}
		}

		delete ::MapGen;

		return onInit();
	}
});

::mods_hookBaseClass("skills/skill", function(o) {
	o = o[o.SuperName];

	o.m.MSU_AddedStack <- 1;
	o.m.MSU_StackedFields <- {};
	foreach (fieldName, nonStackingValue in ::MSU.Skills.StackedFields)
	{
		o.m.MSU_StackedFields[fieldName] <- {
			[nonStackingValue] = 0
		};
	}

	o.isKeepingAddRemoveHistory <- function()
	{
		return !this.isStacking() && !this.isType(::Const.SkillType.Special) && (this.isType(::Const.SkillType.Perk) || !this.isType(::Const.SkillType.StatusEffect));
	}

	local removeSelf = o.removeSelf;
	o.removeSelf = function()
	{
		this.removeSelfByStack(::MSU.Skills.ClassNameHashToDefaultValuesMap[this.ClassNameHash]);
	}

	o.updateStackedValues <- function()
	{
		foreach (fieldName, countInfo in this.m.MSU_StackedFields)
		{
			local bestValue = ::MSU.Skills.StackedFields[fieldName];
			if (this.m.MSU_StackedFields[fieldName][bestValue] > 0)
			{
				this.m[fieldName] = bestValue
				if (this.getID() == ::getModSetting(::StackBasedSkills.ID, "LoggingSkillID").getValue())
				{
					::StackBasedSkills.Mod.Debug.printLog("Setting " + fieldName + " to the NON-STACKING value: " + bestValue);
				}
				continue;
			}

			local bestCount = 0;
			foreach (value, count in countInfo)
			{
				if (count > bestCount)
				{
					bestCount = count;
					bestValue = value;
				}
			}
			this.m[fieldName] = bestValue;
			if (this.getID() == ::getModSetting(::StackBasedSkills.ID, "LoggingSkillID").getValue())
			{
				::StackBasedSkills.Mod.Debug.printLog("Setting " + fieldName + " to the stacking value: " + bestValue);
			}
		}

		if (this.getID() == ::getModSetting(::StackBasedSkills.ID, "LoggingSkillID").getValue())
		{
			local toPrint = "";
			foreach (fieldName, _ in ::MSU.Skills.StackedFields)
			{
				toPrint += fieldName + ": " + this.m[fieldName] + "\n";
			}
			::StackBasedSkills.Mod.Debug.printLog("Updated Stacked Values:\n" + toPrint);
			if (::StackBasedSkills.Mod.Debug.isEnabled()) ::MSU.Log.printData(this.m.MSU_StackedFields, 99, false, 99);
		}
	}

	o.removeSelfByStack <- function( _stackedFields )
	{
		if (!this.isKeepingAddRemoveHistory()) return removeSelf();
		if (--this.m.MSU_AddedStack == 0) return removeSelf();

		foreach (fieldName, value in _stackedFields)
		{
			local count = this.m.MSU_StackedFields[fieldName][value];
			if (count > 0) this.m.MSU_StackedFields[fieldName][value] = count - 1;
			else throw format("trying to remove skill \'%s\' but all its stacked additions with \'%s = %s\' have already been removed", this.getID(), fieldName, value + "");
		}

		this.updateStackedValues();

		if (this.getID() == ::getModSetting(::StackBasedSkills.ID, "LoggingSkillID").getValue())
		{
			local toPrint = "";
			foreach (fieldName, _ in ::MSU.Skills.StackedFields)
			{
				toPrint += fieldName + ": " + this.m[fieldName] + "\n";
			}
			::StackBasedSkills.Mod.Debug.printLog("Removing skill:\n" + toPrint);
			if (::StackBasedSkills.Mod.Debug.isEnabled()) ::MSU.Log.printData(this.m.MSU_StackedFields, 99, false, 99);
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

		foreach (fieldName, valueCountInfo in _skill.m.MSU_StackedFields)
		{
			local currValue = _skill.m[fieldName];
			if (currValue in _skill.m.MSU_StackedFields[fieldName]) _skill.m.MSU_StackedFields[fieldName][currValue]++;
			else _skill.m.MSU_StackedFields[fieldName][currValue] <- 1;
		}

		if (_skill.getID() == ::getModSetting(::StackBasedSkills.ID, "LoggingSkillID").getValue())
		{
			local toPrint = "";
			foreach (fieldName, _ in ::MSU.Skills.StackedFields)
			{
				toPrint += fieldName + ": " + _skill.m[fieldName] + "\n";
			}
			::StackBasedSkills.Mod.Debug.printLog(format("Adding skill:\nMSU_AddedStack: %i\n%s", _skill.m.MSU_AddedStack, toPrint));
			if (::StackBasedSkills.Mod.Debug.isEnabled()) ::MSU.Log.printData(_skill.m.MSU_StackedFields, 99, false, 99);
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

				local newStackCount = alreadyPresentSkill.m.MSU_AddedStack + 1;
				if (newStackCount > 0) alreadyPresentSkill.m.IsGarbage = false;

				local bumpStack = false;

				if (_skill.m.IsSerialized)
				{
					if (!alreadyPresentSkill.m.IsSerialized)
					{
						foreach (fieldName, valueCountInfo in _skill.m.MSU_StackedFields)
						{
							// Bump stack only when adding a skill with a non-stacking value OR
							// with stacking value if already present skill doesn't already have that value
							local newValue = _skill.m[fieldName];
							if (newValue != ::MSU.Skills.StackedFields[fieldName])
							{
								bumpStack = true;
							}
							else
							{
								if (alreadyPresentSkill.m[fieldName] != newValue) bumpStack = true;
								alreadyPresentSkill.m.MSU_StackedFields[fieldName][newValue] <- 1;
								continue;
							}

							if (newValue in alreadyPresentSkill.m.MSU_StackedFields[fieldName]) alreadyPresentSkill.m.MSU_StackedFields[fieldName][newValue]++;
							else alreadyPresentSkill.m.MSU_StackedFields[fieldName][newValue] <- 1;
						}
					}
				}

				if (bumpStack) alreadyPresentSkill.m.MSU_AddedStack = newStackCount;

				alreadyPresentSkill.updateStackedValues();

				if (alreadyPresentSkill.getID() == ::getModSetting(::StackBasedSkills.ID, "LoggingSkillID").getValue())
				{
					local toPrint = "";
					foreach (fieldName, _ in ::MSU.Skills.StackedFields)
					{
						toPrint += fieldName + ": " + alreadyPresentSkill.m[fieldName] + "\n";
					}
					::StackBasedSkills.Mod.Debug.printLog(format("Already present skill:\nMSU_AddedStack: %i\n%s", alreadyPresentSkill.m.MSU_AddedStack, toPrint));
					if (::StackBasedSkills.Mod.Debug.isEnabled()) ::MSU.Log.printData(alreadyPresentSkill.m.MSU_StackedFields, 99, false, 99);
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

	o.removeByStack <- function( _skill, _stackedFields )
	{
		if (skill.m.MSU_AddedStack == 1) return remove(_skillID);
		else return skill.removeSelfByStack(_stackedFields);
	}

	o.removeByStackByID <- function( _skillID, _stackedFields )
	{
		local skill = this.getSkillByID(_skillID);
		if (skill == null) return;

		if (skill.m.MSU_AddedStack == 1) return removeByID(_skillID);
		else return skill.removeSelfByStack(_stackedFields);
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
::mods_hookExactClass("skills/perks/perk_colossus", function(o) {
	o.onCombatStarted <- function()
	{
		::logInfo(this.getContainer().getActor().getID() + " onCombatStarted");
	}
	o.onCombatFinished <- function()
	{
		::logInfo(this.getContainer().getActor().getID() + " onCombatFinished");
	}
	o.onEquip <- function( _item )
	{
		if (_item.getSlotType() != ::Const.ItemSlot.Mainhand) return;

		// Add Shield Expert, Reach Advantage, and Duelist while a weapon is equipped
		// But add non-permanent (i.e. IsSerialized = false) versions of these skills

		this.getContainer().add(::MSU.new("scripts/skills/perks/perk_shield_expert", function(o) {
			o.m.IsSerialized = false;
			o.m.IsRefundable = false;
		}));
		this.getContainer().add(::MSU.new("scripts/skills/perks/perk_reach_advantage", function(o) {
			o.m.IsSerialized = false;
			o.m.IsRefundable = false;
		}));
		this.getContainer().add(::MSU.new("scripts/skills/perks/perk_duelist", function(o) {
			o.m.IsSerialized = false;
			o.m.IsRefundable = false;
		}));

		// add shield_expert permanently (i.e. normal IsSerialized = true version)
		// for testing the stacking addition/removal of serialized skills
		this.getContainer().add(::MSU.new("scripts/skills/perks/perk_shield_expert"));
	}

	o.onUnequip <- function( _item )
	{
		// Remove the Shield Expert, Reach Advantage and Duelist skills when a weapon is unequipped
		// But we must remove the "non-permanent" i.e. "IsSerialized = false" versions of these skills (that we added in onEquip)
		if (_item.getSlotType() != ::Const.ItemSlot.Mainhand) return;

		this.getContainer().removeByStackByID("perk.shield_expert", {IsSerialized = false, IsRefundable = false});
		this.getContainer().removeByStackByID("perk.reach_advantage", {IsSerialized = false, IsRefundable = false});
		this.getContainer().removeByStackByID("perk.duelist", {IsSerialized = false, IsRefundable = false});
	}

	o.onAdded <- function()
	{
		local equippedItem = this.getContainer().getActor().getMainhandItem();
		if (equippedItem != null)
		{
			this.getContainer().getActor().getItems().unequip(equippedItem);
			this.getContainer().getActor().getItems().equip(equippedItem);
		}
	}

	o.onRemoved <- function()
	{
		local equippedItem = this.getContainer().getActor().getMainhandItem();
		if (equippedItem != null)
		{
			this.getContainer().getActor().getItems().unequip(equippedItem);
			this.getContainer().getActor().getItems().equip(equippedItem);
		}
	}
});
