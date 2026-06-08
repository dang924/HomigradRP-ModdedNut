ITEM.name = "Ballistic Helmet"
ITEM.desc = "A high-cut ballistic helmet with ear protection."
ITEM.model = "models/props_junk/cardboard_box004a.mdl"
ITEM.category = "Gear"
ITEM.nxGearSlot = "helmet"
ITEM.nxGearEntityClass = "nut_gear_helmet"
ITEM.nxCarryBonus = 0
ITEM.nxWeight = 1.8
ITEM.nxArmorValue = 15

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
