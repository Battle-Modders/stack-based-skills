::StackBasedSkills.MH.hook("scripts/items/item_container", function(q) {
	q.m.SBS_ItemBeingUnequipped <- null;

	q.unequip = @(__original) function( _item )
	{
		// This variable is needed for proper functionality in the skill.removeSelf function because
		// in that function we want to know if the item being unequipped is the one that is attached to that skill
		// and skills are removed before the item is unequipped
		local old_itemBeingUnequipped = this.m.SBS_ItemBeingUnequipped;
		this.m.SBS_ItemBeingUnequipped = _item;
		local ret = __original(_item);
		this.m.SBS_ItemBeingUnequipped = old_itemBeingUnequipped;

		return ret;
	}

	q.removeFromBag = @(__original) function( _item )
	{
		// This variable is needed for proper functionality in the skill.removeSelf function because
		// in that function we want to know if the item being unequipped is the one that is attached to that skill
		// and skills are removed before the item is unequipped
		local old_itemBeingUnequipped = this.m.SBS_ItemBeingUnequipped;
		this.m.SBS_ItemBeingUnequipped = _item;
		local ret = __original(_item);
		this.m.SBS_ItemBeingUnequipped = old_itemBeingUnequipped;

		return ret;
	}

	q.removeFromBagSlot = @(__original) function( _slot )
	{
		// This variable is needed for proper functionality in the skill.removeSelf function because
		// in that function we want to know if the item being unequipped is the one that is attached to that skill
		// and skills are removed before the item is unequipped
		local old_itemBeingUnequipped = this.m.SBS_ItemBeingUnequipped;
		this.m.SBS_ItemBeingUnequipped = this.m.Items[::Const.ItemSlot.Bag][_slot];
		local ret = __original(_item);
		this.m.SBS_ItemBeingUnequipped = old_itemBeingUnequipped;

		return ret;
	}
});
