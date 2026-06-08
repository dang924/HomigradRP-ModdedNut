ITEM.name = "Plate Carrier"
ITEM.desc = "Body armor with front and back plate coverage."
ITEM.model = "models/props_junk/cardboard_box004a.mdl"
ITEM.category = "Gear"
ITEM.nxGearSlot = "armor"
ITEM.nxGearEntityClass = "nut_gear_armor"
ITEM.nxCarryBonus = 2
ITEM.nxWeight = 6.5
ITEM.nxArmorValue = 40

function ITEM:onWear(client)
    if (not IsValid(client) or not SERVER) then return end

    local nextArmor = math.max(client:Armor(), self.nxArmorValue or 0)
    client:SetArmor(nextArmor)
end

function ITEM:onTakeOff(client)
    if (not IsValid(client) or not SERVER) then return end

    local current = client:Armor()
    local removed = tonumber(self.nxArmorValue) or 0
    client:SetArmor(math.max(0, current - removed))
end
