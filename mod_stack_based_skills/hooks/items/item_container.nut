::StackBasedSkills.MH.hook("scripts/items/item_container", function(q) {
	q.m.SBS_ItemBeingUnequipped <- null;

	q.unequip = @(__original) function( _item )
	{
		// This variable is needed for proper functionality in the skill.removeSelf function because
		// in that function we want to know if the item being unequipped is the one that is attached to that skill
		// and skills are removed before the item is unequipped
		this.m.SBS_ItemBeingUnequipped = _item;
		local ret = __original(_item);
		this.m.SBS_ItemBeingUnequipped = null;

		return ret;
	}
});
