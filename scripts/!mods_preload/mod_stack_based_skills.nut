/* Documentation
This version is built around the idea that we can have a list of fields in skills for which stacked state is saved during addition/removal
- The preferred value of fields is given in an ::MSU.Skills.StackedFields table
- If you want to add a skill with modified value, you add that manually by changing the value during addition.
- Then you are responsible for removing the stack with the appropraite value during removal.

e.g.
Shield Expert is serialized by default.
I add a non-serialized version of it to a character.
Calling the default "removeSelf" on this skill will use stacks of IsSerialized = true. Which are 0, so the skill will get removed.
If I want to remove the stack which wasn't serialized, I have to manually request that i.e. `removeSelfByStack( false )`

The opposite is true if one is adding a by-default non-serialized skill as serialized.
*/

// ::StackBasedSkills <- {
// 	Version = "0.1.0",
// 	ID = "mod_stack_based_skills",
// 	Name = "Stack Based Skills",
// };

// ::mods_registerMod(::StackBasedSkills.ID, ::StackBasedSkills.Version, ::StackBasedSkills.Name);
// ::mods_queue(::StackBasedSkills.ID, "mod_msu(>=1.2.0.rc.2)", function() {

// 	// ::StackBasedSkills.Mod <- ::MSU.Class.Mod(::StackBasedSkills.ID, ::StackBasedSkills.Version, ::StackBasedSkills.Name);

// 	::MSU.new <- function( _script, _function = null )
// 	{
// 		local obj = ::new(_script);
// 		if (_function != null) _function(obj);
// 		return obj;
// 	}

// 	// Contains a list of "preferred" values for skill fields
// 	// Preferred value means that even if one stack of this skill exists with this value then
// 	// this value will be used to set the skill's respective field's value
// 	::MSU.Skills.StackedFields <- {
// 		IsSerialized = true
// 	};

// 	::mods_hookBaseClass("skills/skill", function(o) {
// 		o = o[o.SuperName];

// 		o.m.MSU_AddedStack <- 1;
// 		o.m.MSU_StackedFields <- {};		

// 		o.isKeepingAddRemoveHistory <- function()
// 		{
// 			return !this.isStacking() && (this.isType(::Const.SkillType.Perk) || !this.isType(::Const.SkillType.StatusEffect));
// 		}

// 		local removeSelf = o.removeSelf;
// 		o.removeSelf = function()
// 		{
// 			this.removeSelfByStack(::MSU.Skills.StackedFields);
// 		}

// 		o.updateStackedField <- function( _fieldName )
// 		{
// 			local value = ::MSU.Skills.StackedFields[_fieldName];

// 			if (this.m.MSU_StackedFields[_fieldName][value] == 0)
// 			{
// 				value = this.m[_fieldName];
// 				local bestCount = 0;
// 				foreach (localValue, localCount in this.m.MSU_StackedFields[_fieldName])
// 				{
// 					if (localCount > bestCount) value = localValue;
// 				}
// 			}
			
// 			this.m[_fieldName] = value;
// 		}

// 		o.removeSelfByStack <- function( _stackedFields )
// 		{
// 			if (!this.isKeepingAddRemoveHistory()) return removeSelf();
// 			if (--this.m.MSU_AddedStack == 0) return removeSelf();

// 			foreach (fieldName, preferredValue in ::MSU.Skills.StackedFields)
// 			{
// 				local value = fieldName in _stackedFields ? _stackedFields[fieldName] : preferredValue;
// 				local count = this.m.MSU_StackedFields[fieldName][value];

// 				if (count > 0) this.m.MSU_StackedFields[fieldName][value] = count - 1;
// 				else throw "trying to remove " + this.getID() + " but all its stacked additions with \'" + fieldName + " = " + value + "\' have already been removed";

// 				this.updateStackedField(fieldName);

// 				if (this.getID() == "perk.shield_expert")
// 				{					
// 					::logInfo("Removing shield expert");
// 					::logInfo("IsSerialized (skill): " + this.m[fieldName]);					
// 					// ::logInfo("IsSerialized (skill): " + this.m.MSU_StackedFields[fieldName][preferredValue]);					
// 					::MSU.Log.printData(this.m.MSU_StackedFields, 2, false, 5);
// 				}
// 			}

// 			// The actual item which provided this skill isn't unequipped yet because
// 			// the removeSelf is called BEFORE the item is unequipped. So, we iterate over
// 			// all items and skip the one that is going to be unequipped
// 			if (::MSU.isEqual(this.getContainer().getActor().getItems().m.MSU_ItemBeingUnequipped, this.getItem()))
// 			{
// 				foreach (item in this.getContainer().getActor().getItems().getAllItems())
// 				{
// 					if (::MSU.isEqual(item, this.getItem())) continue;

// 					foreach (skill in item.m.SkillPtrs)
// 					{
// 						if (skill.getID() == this.getID())
// 						{
// 							this.setItem(item);
// 							return;
// 						}
// 					}
// 				}
// 			}

// 			this.setItem(null);
// 		}
// 	});

// 	::mods_hookNewObject("skills/skill_container", function(o) {
// 		local add = o.add;
// 		o.add = function( _skill, _order = 0 )
// 		{
// 			if (_skill.getID() == "perk.shield_expert")
// 			{
// 				::logInfo("add()");
// 			}

// 			if (!_skill.isKeepingAddRemoveHistory()) return add(_skill, _order);			

// 			// Each skill contains a `this.m.MSU_StackedFields` table where each key is a fieldName and its value is a table
// 			// this table's keys are all the values of this.m[fieldName] with which this skill was ever added
// 			// and each key corresponds to a value of how many times this value occurs in stacked additions e.g. 
// 			// 	this.m.MSU_StackedFields = {
// 			// 		IsSerialized = {
// 			// 			true = 1, // this skill was added 1 times with this.m.IsSerialized = true
// 			// 			false = 3 // this skill was added 3 times with this.m.IsSerialized = false
// 			// 		}
// 			// 	}
// 			foreach (fieldName, preferredValue in ::MSU.Skills.StackedFields)
// 			{
// 				_skill.m.MSU_StackedFields[fieldName] <- {};
// 				_skill.m.MSU_StackedFields[fieldName][preferredValue] <- 0;
// 				_skill.m.MSU_StackedFields[fieldName][_skill.m[fieldName]] <- 1;				
// 			}

// 			local skills = clone this.m.Skills;
// 			skills.extend(this.m.SkillsToAdd);

// 			foreach (i, alreadyPresentSkill in skills)
// 			{
// 				if (alreadyPresentSkill.getID() == _skill.getID())
// 				{
// 					if (!::MSU.isNull(_skill.getItem()))
// 					{
// 						if (::MSU.isNull(alreadyPresentSkill.getItem())) alreadyPresentSkill.setItem(_skill.getItem());
// 						foreach (j, itemSkill in _skill.getItem().m.SkillPtrs)
// 						{
// 							if (itemSkill.getID() == _skill.getID())
// 							{
// 								_skill.getItem().m.SkillPtrs[j] = alreadyPresentSkill;
// 								_skill.setItem(null);
// 								break;
// 							}
// 						}
// 					}

// 					if (alreadyPresentSkill.m.IsSerialized && _skill.m.IsSerialized)
// 						break;

// 					if (++alreadyPresentSkill.m.MSU_AddedStack > 0)
// 						alreadyPresentSkill.m.IsGarbage = false;

// 					foreach (fieldName, preferredValue in ::MSU.Skills.StackedFields)
// 					{
// 						// this.m.MSU_StackedFields is a table where each key is a fieldName and its value is a table
// 						// this table's keys are the values of this.m[fieldName] and its values are how many times
// 						// this value occurs in stacked additions e.g.
// 						// 	this.m.MSU_StackedFields = {
// 						// 		IsSerialized = {
// 						// 			true = 1, // this skill was added 1 times with this.m.IsSerialized = true
// 						// 			false = 3 // this skill was added 3 times with this.m.IsSerialized = false
// 						// 		}
// 						// 	}				

// 						local value = _skill.m[fieldName];
// 						if (value in alreadyPresentSkill.m.MSU_StackedFields[fieldName]) alreadyPresentSkill.m.MSU_StackedFields[fieldName][value]++;
// 						else alreadyPresentSkill.m.MSU_StackedFields[fieldName][value] <- 1;

// 						alreadyPresentSkill.updateStackedField(fieldName);
// 					}

// 					if (_skill.getID() == "perk.shield_expert")
// 					{					
// 						::logInfo("Adding shield expert");
// 						::logInfo("MSU_AddedStack: " + alreadyPresentSkill.m.MSU_AddedStack);
// 						::logInfo("IsSerialized (skill): " + alreadyPresentSkill.m[fieldName]);												
// 						::MSU.Log.printData(alreadyPresentSkill.m.MSU_StackedFields, 2, false, 5);
// 					}

// 					break;
// 				}
// 			}

// 			return add(_skill, _order);
// 		}

// 		local remove = o.remove;
// 		o.remove = function( _skill )
// 		{
// 			if (_skill.m.MSU_AddedStack == 1) return remove(_skill);
// 			else return _skill.removeSelf();
// 		}

// 		local removeByID = o.removeByID;
// 		o.removeByID = function( _skillID )
// 		{
// 			local skill = this.getSkillByID(_skillID);
// 			if (skill == null) return;

// 			if (skill.m.MSU_AddedStack == 1) return removeByID(_skillID);
// 			else return skill.removeSelf();
// 		}
		
// 		o.removeByStack <- function( _skill, _stackedFields )
// 		{
// 			if (skill.m.MSU_AddedStack == 1) return remove(_skillID);
// 			else return skill.removeSelfByStack(_stackedFields);
// 		}

// 		o.removeByStackByID <- function( _skillID, _stackedFields )
// 		{
// 			local skill = this.getSkillByID(_skillID);
// 			if (skill == null) return;

// 			if (skill.m.MSU_AddedStack == 1) return removeByID(_skillID);
// 			else return skill.removeSelfByStack(_stackedFields);
// 		}
// 	});

// 	::mods_hookNewObject("items/item_container", function(o) {
// 		o.m.MSU_ItemBeingUnequipped <- null;

// 		local unequip = o.unequip;
// 		o.unequip = function( _item )
// 		{
// 			// This variable is needed for proper functionality in the skill.removeSelf function because
// 			// in that function we want to know if the item being unequipped is the one that is attached to that skill
// 			// and skills are removed before the item is unequipped
// 			this.m.MSU_ItemBeingUnequipped = _item;		
// 			local ret = unequip(_item);
// 			this.m.MSU_ItemBeingUnequipped = null;

// 			return ret;
// 		}
// 	});

// 	// Test perk
// 	::mods_hookExactClass("skills/perks/perk_colossus", function(o) {
// 		o.onEquip <- function( _item )
// 		{
// 			if (_item.getSlotType() != ::Const.ItemSlot.Mainhand) return;

// 			// Add Shield Expert, Reach Advantage, and Duelist while a weapon is equipped
// 			// But add non-permanent (i.e. IsSerialized = false) versions of these skills

// 			this.getContainer().add(::MSU.new("scripts/skills/perks/perk_shield_expert", function(o) {
// 				o.m.IsSerialized = false;
// 				// o.m.IsRefundable = false;
// 			}));
// 			this.getContainer().add(::MSU.new("scripts/skills/perks/perk_reach_advantage", function(o) {
// 				o.m.IsSerialized = false;
// 				// o.m.IsRefundable = false;
// 			}));
// 			this.getContainer().add(::MSU.new("scripts/skills/perks/perk_duelist", function(o) {
// 				o.m.IsSerialized = false;
// 				// o.m.IsRefundable = false;
// 			}));
				
// 			// add shield_expert permanently (i.e. normal IsSerialized = true version)
// 			// for testing the stacking addition/removal
// 			this.getContainer().add(::MSU.new("scripts/skills/perks/perk_shield_expert"));
// 		}

// 		o.onUnequip <- function( _item )
// 		{
// 			// Remove the Shield Expert, Reach Advantage and Duelist skills when a weapon is unequipped
// 			// But we must remove the "non-permanent" i.e. "IsSerialized = false" versions of these skills (that we added in onEquip)

// 			this.getContainer().removeByStackByID("perk.shield_expert", {IsSerialized = false});
// 			this.getContainer().removeByStackByID("perk.reach_advantage", {IsSerialized = false});
// 			this.getContainer().removeByStackByID("perk.duelist", {IsSerialized = false});			
// 		}

// 		o.onAdded <- function()
// 		{
// 			local equippedItem = this.getContainer().getActor().getMainhandItem();
// 			if (equippedItem != null)
// 			{
// 				this.getContainer().getActor().getItems().unequip(equippedItem);
// 				this.getContainer().getActor().getItems().equip(equippedItem);
// 			}
// 		}

// 		o.onRemoved <- function()
// 		{
// 			local equippedItem = this.getContainer().getActor().getMainhandItem();
// 			if (equippedItem != null)
// 			{
// 				this.getContainer().getActor().getItems().unequip(equippedItem);
// 				this.getContainer().getActor().getItems().equip(equippedItem);
// 			}
// 		}	
// 	});
// });


