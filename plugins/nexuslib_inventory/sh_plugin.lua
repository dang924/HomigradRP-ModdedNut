PLUGIN.name = "NexusLib Inventory"
PLUGIN.author = "GitHub Copilot"
PLUGIN.desc = "Gear-reactive inventory layer inspired by ZScav."

nut.config.add("nxInvBaseCarry", 38, "Base carry capacity before gear bonuses.", nil, {
    data = {min = 1, max = 300},
    category = "inventory"
})

nut.config.add("nxInvUnitWeight", 1, "Fallback item weight when no weight is defined.", nil, {
    data = {min = 0.1, max = 25},
    category = "inventory"
})

nut.config.add("nxInvBagCellBonus", 0.6, "Carry bonus per bag cell when the bag is equipped.", nil, {
    data = {min = 0, max = 10},
    category = "inventory"
})

nut.config.add("nxInvOutfitBonus", 4, "Default carry bonus for equipped outfits without explicit bonus.", nil, {
    data = {min = 0, max = 100},
    category = "inventory"
})

if (SERVER) then
    util.AddNetworkString("nutNxInvStatus")
end
