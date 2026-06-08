ITEM.name = "Gear"
ITEM.desc = "Base gear item."
ITEM.category = "Gear"
ITEM.model = "models/props_junk/cardboard_box004a.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.nxGearSlot = "armor"
ITEM.nxCarryBonus = 0
ITEM.nxWeight = 1

local function getInventory(item)
    local player = item.player
    if (not IsValid(player) or not player.getChar) then return nil end

    local char = player:getChar()
    if (not char) then return nil end

    return char:getInv(), player
end

if (CLIENT) then
    function ITEM:paintOver(item, w, h)
        if (item:getData("equip") == true) then
            surface.SetDrawColor(110, 210, 255, 150)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end
    end
end

ITEM:hook("drop", function(item)
    if (item:getData("equip") == true and NexusLib and NexusLib.Inventory) then
        NexusLib.Inventory.UnequipItem(item.player, item)
        item:call("onTakeOff", item.player)
    end
end)

ITEM.functions.EquipUn = {
    name = "Unequip",
    tip = "unequipTip",
    icon = "icon16/cross.png",
    onRun = function(item)
        local client = item.player

        if (NexusLib and NexusLib.Inventory) then
            NexusLib.Inventory.UnequipItem(client, item)
        else
            item:setData("equip", nil)
        end

        item:call("onTakeOff", client)

        if (IsValid(client)) then
            client:EmitSound("items/ammo_pickup.wav", 65, 88)
        end

        return false
    end,
    onCanRun = function(item)
        return (not IsValid(item.entity)) and item:getData("equip") == true
    end
}

ITEM.functions.Equip = {
    name = "Equip",
    tip = "equipTip",
    icon = "icon16/tick.png",
    onRun = function(item)
        local inventory, client = getInventory(item)
        if (not inventory or not IsValid(client)) then
            return false
        end

        local ok, reason
        if (NexusLib and NexusLib.Inventory) then
            ok, reason = NexusLib.Inventory.EquipItem(client, item)
        else
            item:setData("equip", true)
            ok = true
        end

        if (ok == false) then
            client:notifyLocalized(reason or "notAllowed")
            return false
        end

        item:call("onWear", client)

        client:EmitSound("items/ammo_pickup.wav", 70, 115)
        return false
    end,
    onCanRun = function(item)
        return (not IsValid(item.entity)) and item:getData("equip") ~= true
    end
}

function ITEM:onCanBeTransfered(oldInventory, newInventory)
    if (newInventory and self:getData("equip") == true) then
        return false
    end

    return true
end

function ITEM:onLoadout()
    if (self:getData("equip") == true and IsValid(self.player)) then
        self:call("onWear", self.player)
    end
end

function ITEM:onWear(client)
end

function ITEM:onTakeOff(client)
end

if (SERVER) then
    function ITEM:spawn(position, angles)
        local nx = NexusLib and NexusLib.Inventory
        if (nx and nx.SpawnItemEntity) then
            local entClass = nx.GetGearEntityClass and nx.GetGearEntityClass(self) or "nut_item"
            return nx.SpawnItemEntity(self, position, angles, entClass)
        end

        return self.BaseClass.spawn(self, position, angles)
    end
end
