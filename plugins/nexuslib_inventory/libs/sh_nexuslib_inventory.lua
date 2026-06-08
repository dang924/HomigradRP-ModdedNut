NexusLib = NexusLib or {}
NexusLib.Inventory = NexusLib.Inventory or {}

local INV = NexusLib.Inventory

local ACTION_ADD = "add"

INV.GearEntityClasses = INV.GearEntityClasses or {
    backpack = "nut_gear_backpack",
    rig = "nut_gear_rig",
    tactical_rig = "nut_gear_rig",
    armor = "nut_gear_armor",
    helmet = "nut_gear_helmet"
}

local function ensureGearEntityClass(className, printName)
    if (not SERVER) then return end
    if (not isstring(className) or className == "") then return end
    if (scripted_ents.GetStored(className) ~= nil) then return end

    scripted_ents.Register({
        Base = "nut_item",
        Type = "anim",
        PrintName = printName,
        Category = "NexusLib Gear",
        Spawnable = false,
        AdminOnly = true
    }, className)
end

function INV.EnsureGearEntityClasses()
    if (not SERVER) then return end

    local seen = {}
    for slot, className in pairs(INV.GearEntityClasses or {}) do
        if (not seen[className]) then
            local label = "Gear"
            if (slot == "backpack") then
                label = "Backpack"
            elseif (slot == "rig" or slot == "tactical_rig") then
                label = "Tactical Rig"
            elseif (slot == "armor") then
                label = "Armor"
            elseif (slot == "helmet") then
                label = "Helmet"
            end

            ensureGearEntityClass(className, label)
            seen[className] = true
        end
    end
end

local function getConfig(name, fallback)
    if (nut and nut.config and nut.config.get) then
        return nut.config.get(name, fallback)
    end

    return fallback
end

local function findClientByCharID(charID)
    if (not charID) then return nil end

    for _, client in ipairs(player.GetAll()) do
        local char = client.getChar and client:getChar() or nil
        if (char and char:getID() == charID) then
            return client
        end
    end

    return nil
end

local HGRP_ARMOR_CONTAINER_CHAR_KEY = "nxHGRPArmorContainers"
local HGRP_ARMOR_CONTAINER_NETVAR = "HGRPArmorContainers"

local function normalizeArmorContainerClass(equipment)
    local className = string.lower(string.Trim(tostring(equipment or "")))
    if (className == "") then
        return ""
    end

    if (string.StartWith(className, "ent_")) then
        return className
    end

    return "ent_armor_"..className
end

local function getArmorContainerGrid(def)
    if (not istable(def)) then return 0, 0 end

    if (ZSCAV and ZSCAV.GetGearInternalSize) then
        local width, height = ZSCAV:GetGearInternalSize(def)
        if (width > 0 and height > 0) then
            return width, height
        end
    end

    local internal = istable(def.internal) and def.internal or nil
    local width = math.max(0, math.floor(tonumber(internal and internal.w) or 0))
    local height = math.max(0, math.floor(tonumber(internal and internal.h) or 0))
    return width, height
end

local function getArmorContainerRegistryKey(placement, className)
    return string.lower(string.Trim(tostring(placement or ""))).."::"..normalizeArmorContainerClass(className)
end

local function getArmorContainerRegistry(character)
    if (not character or not character.getData) then
        return {}
    end

    local stored = character:getData(HGRP_ARMOR_CONTAINER_CHAR_KEY, {})
    if (not istable(stored)) then
        return {}
    end

    return table.Copy(stored)
end

local function saveArmorContainerRegistry(character, registry)
    if (not character or not character.setData) then return end

    if (not istable(registry) or next(registry) == nil) then
        character:setData(HGRP_ARMOR_CONTAINER_CHAR_KEY, nil)
        return
    end

    character:setData(HGRP_ARMOR_CONTAINER_CHAR_KEY, registry)
end

local function inventoryHasItems(inventory)
    if (not inventory or not inventory.getItems) then return false end

    local items = inventory:getItems(true)
    return next(items or {}) ~= nil
end

local function getArmorContainerDisplayName(className, fallback)
    if (ZSCAV and ZSCAV.GetGearDef) then
        local ok, gearDef = pcall(ZSCAV.GetGearDef, ZSCAV, className)
        if (ok and istable(gearDef) and isstring(gearDef.name) and gearDef.name ~= "") then
            return gearDef.name
        end
    end

    local nice = string.NiceName(string.gsub(className or "", "^ent_", ""))
    if (nice ~= "") then
        return nice
    end

    return fallback or "Tactical Rig"
end

local function getHGRPCurrentArmorClasses(client)
    local equipped = {}
    if (not IsValid(client)) then
        return equipped
    end

    local armorState = nil
    if (SERVER and istable(client.armors)) then
        armorState = client.armors
    elseif (client.GetNetVar) then
        armorState = client:GetNetVar("Armor", {})
    end

    for placement, equipment in pairs(armorState or {}) do
        local className = normalizeArmorContainerClass(equipment)
        if (className ~= "") then
            equipped[tostring(placement)] = className
        end
    end

    return equipped
end

local function buildArmorContainerPublicData(client, registry)
    local equipped = getHGRPCurrentArmorClasses(client)
    local publicData = {}

    for placement, className in pairs(equipped) do
        local key = getArmorContainerRegistryKey(placement, className)
        local entry = registry[key]
        if (istable(entry) and tonumber(entry.invID) and tonumber(entry.invID) > 0) then
            publicData[key] = {
                class = className,
                placement = placement,
                invID = tonumber(entry.invID),
                w = tonumber(entry.w) or 0,
                h = tonumber(entry.h) or 0,
                name = tostring(entry.name or getArmorContainerDisplayName(className)),
            }
        end
    end

    return publicData
end

local function syncArmorContainerState(client, character, registry)
    if (not SERVER or not IsValid(client)) then return end

    character = character or (client.getChar and client:getChar() or nil)
    if (not character) then
        client:SetNetVar(HGRP_ARMOR_CONTAINER_NETVAR, {})
        return
    end

    registry = registry or getArmorContainerRegistry(character)
    client:SetNetVar(HGRP_ARMOR_CONTAINER_NETVAR, buildArmorContainerPublicData(client, registry))
end

-- Only push data over the network when the value actually changes. Newly
-- created / freshly loaded inventories already carry these keys (set via the
-- instance initialData), so blindly calling setData here would fire
-- "nutInventoryData" net messages BEFORE the inventory is synced to the
-- client, producing "Got data X for non-existent instance Y" errors and a
-- missing vest/rig storage panel. Skipping no-op writes avoids that race.
local function setIfChanged(inventory, key, value)
    if (not inventory or not inventory.getData or not inventory.setData) then return end
    if (inventory:getData(key) ~= value) then
        inventory:setData(key, value)
    end
end

-- Synchronous guard against creating the same armor/rig container twice. The
-- equip flow can call EnsureHGRPArmorContainer more than once (equip hook firing
-- twice, plus the 2s retry in sv_equipment) before the FIRST asynchronous
-- nut.inventory.instance() has resolved. While pending, registry[key] is still
-- nil, so without this lock every call would spawn another orphan inventory ->
-- "duplicate on equip". Keyed by charID + registry key, cleared when the create
-- promise resolves (or rejects).
local pendingArmorContainerCreation = {}

local function armorPendingKey(character, key)
    return tostring(character and character.getID and character:getID() or 0) .. "|" .. tostring(key)
end

local function prepareArmorContainerInventory(inventory, character, className, placement, width, height)
    if (not inventory or not character) then return end

    -- Register the instance on the client FIRST. Net messages are reliable and
    -- ordered, so any setData/setSize fired below now always arrives AFTER the
    -- "nutInventoryInit" that registers the instance client-side. This makes the
    -- "Got data X for non-existent instance Y" error impossible regardless of
    -- whether the data actually changed or what order things load in.
    if (inventory.sync) then
        inventory:sync()
    end

    setIfChanged(inventory, "char", character:getID())
    setIfChanged(inventory, "hgrpArmor", true)
    setIfChanged(inventory, "hgrpArmorClass", className)
    setIfChanged(inventory, "hgrpArmorPlacement", placement)

    -- Only resize when it actually differs (avoids redundant net traffic).
    local curW = inventory.getData and inventory:getData("w")
    local curH = inventory.getData and inventory:getData("h")
    if (inventory.setSize and (curW ~= width or curH ~= height)) then
        inventory:setSize(width, height)
    elseif (not inventory.setSize) then
        setIfChanged(inventory, "w", width)
        setIfChanged(inventory, "h", height)
    end

    if (PLUGIN and PLUGIN.EnsureCarryRule) then
        PLUGIN:EnsureCarryRule(inventory)
    end
end

function INV.GetHGRPEquippedArmorContainers(client)
    local entries = {}
    if (not IsValid(client) or not client.GetNetVar) then
        return entries
    end

    local publicData = client:GetNetVar(HGRP_ARMOR_CONTAINER_NETVAR, {}) or {}

    for key, entry in pairs(publicData) do
        if (not istable(entry)) then continue end

        local placement = tostring(entry.placement or "")
        local className = normalizeArmorContainerClass(entry.class)
        if (placement == "" or className == "") then continue end

        -- The server already rebuilds this netvar from CURRENTLY equipped gear
        -- only (buildArmorContainerPublicData), so do NOT re-filter against a
        -- client-side "Armor" netvar here. That re-check could silently drop every
        -- card when the client armor table is shaped/keyed differently than the
        -- placement stored server-side, which is exactly why vest/rig storage
        -- cards failed to appear. Trust the networked container list.

        local invID = tonumber(entry.invID) or 0
        local inventory = invID > 0 and nut.inventory.instances[invID] or nil
        if (not inventory) then continue end

        entries[#entries + 1] = {
            key = tostring(key),
            class = className,
            placement = placement,
            invID = invID,
            inventory = inventory,
            w = tonumber(entry.w) or 0,
            h = tonumber(entry.h) or 0,
            name = tostring(entry.name or getArmorContainerDisplayName(className)),
        }
    end

    table.sort(entries, function(a, b)
        if (a.placement == b.placement) then
            return a.name < b.name
        end

        return a.placement < b.placement
    end)

    return entries
end

function INV.EnsureHGRPArmorContainer(client, equipment, placement)
    if (not SERVER or not IsValid(client) or not client.getChar) then
        return true
    end

    local className = normalizeArmorContainerClass(equipment)
    if (className == "") then return true end

    local gearDef = ZSCAV and ZSCAV.GetGearDef and ZSCAV:GetGearDef(className) or nil
    local width, height = getArmorContainerGrid(gearDef)
    local slot = tostring(gearDef and gearDef.slot or "")

    -- Grant a storage container to ANY worn gear that defines a positive internal
    -- grid in the ZSCAV config (def.internal / GetGearInternalSize). This covers
    -- tactical rigs, armored vests with compartments, AND backpacks equipped via
    -- the homigrad armor system. Gear without a configured internal grid (plain
    -- body armor, helmets) gets no storage. Nutscript bag ITEMS carry their own
    -- inventory separately and never reach this path.
    if (width <= 0 or height <= 0) then
        syncArmorContainerState(client)
        return true
    end

    local character = client:getChar()
    if (not character) then return true end

    local key = getArmorContainerRegistryKey(placement, className)
    local registry = getArmorContainerRegistry(character)
    local entry = registry[key]
    local displayName = getArmorContainerDisplayName(className, gearDef and gearDef.name)

    local function storeInventory(inventory)
        if (not inventory) then return end

        prepareArmorContainerInventory(inventory, character, className, placement, width, height)

        registry[key] = {
            class = className,
            placement = placement,
            invID = inventory:getID(),
            w = width,
            h = height,
            name = displayName,
        }

        saveArmorContainerRegistry(character, registry)
        syncArmorContainerState(client, character, registry)
    end

    if (istable(entry) and tonumber(entry.invID) and tonumber(entry.invID) > 0) then
        local inventory = nut.inventory.instances[tonumber(entry.invID)]
        if (inventory) then
            storeInventory(inventory)
            return true
        end

        if (nut.inventory.loadByID) then
            nut.inventory.loadByID(tonumber(entry.invID))
                :next(function(loadedInventory)
                    if (not IsValid(client)) then return end
                    storeInventory(loadedInventory)
                end)
            return true
        end
    end

    -- Block duplicate asynchronous creation while one is already in flight.
    local pendKey = armorPendingKey(character, key)
    if (pendingArmorContainerCreation[pendKey]) then
        return true
    end
    pendingArmorContainerCreation[pendKey] = true

    nut.inventory.instance("grid", {
        char = character:getID(),
        w = width,
        h = height,
        hgrpArmor = true,
        hgrpArmorClass = className,
        hgrpArmorPlacement = placement,
    }):next(function(inventory)
        pendingArmorContainerCreation[pendKey] = nil
        if (not IsValid(client)) then return end
        storeInventory(inventory)
    end, function()
        -- Clear the lock on failure so a later attempt can retry.
        pendingArmorContainerCreation[pendKey] = nil
    end)

    return true
end

function INV.CanRemoveHGRPArmor(client, equipment, placement)
    if (not SERVER or not IsValid(client) or not client.getChar) then
        return true
    end

    local className = normalizeArmorContainerClass(equipment)
    if (className == "") then return true end

    local character = client:getChar()
    if (not character) then return true end

    local registry = getArmorContainerRegistry(character)
    local entry = registry[getArmorContainerRegistryKey(placement, className)]
    if (not istable(entry) or not tonumber(entry.invID) or tonumber(entry.invID) <= 0) then
        return true
    end

    local inventory = nut.inventory.instances[tonumber(entry.invID)]
    if (not inventory) then
        return false, "Rig inventory is still loading. Try again in a moment."
    end

    if (inventoryHasItems(inventory)) then
        return false, "Empty the rig inventory before removing this gear."
    end

    return true
end

function INV.HandleHGRPArmorRemoved(client, equipment, placement)
    if (not SERVER or not IsValid(client) or not client.getChar) then
        return true
    end

    local className = normalizeArmorContainerClass(equipment)
    if (className == "") then return true end

    local character = client:getChar()
    if (not character) then return true end

    local key = getArmorContainerRegistryKey(placement, className)
    local registry = getArmorContainerRegistry(character)
    local entry = registry[key]
    if (not istable(entry) or not tonumber(entry.invID) or tonumber(entry.invID) <= 0) then
        syncArmorContainerState(client, character, registry)
        return true
    end

    local inventory = nut.inventory.instances[tonumber(entry.invID)]
    if (inventory and not inventoryHasItems(inventory)) then
        nut.inventory.deleteByID(tonumber(entry.invID))
        registry[key] = nil
        saveArmorContainerRegistry(character, registry)
    end

    syncArmorContainerState(client, character, registry)
    return true
end

function INV.SyncHGRPArmorContainerState(client)
    if (not SERVER or not IsValid(client) or not client.getChar) then return end

    local character = client:getChar()
    if (not character) then
        client:SetNetVar(HGRP_ARMOR_CONTAINER_NETVAR, {})
        return
    end

    syncArmorContainerState(client, character)
end

function INV.GetGearSlot(item)
    if (not item) then return nil end

    local explicit = item.nxGearSlot or item.gearSlot
    if (isstring(explicit) and explicit ~= "") then
        return string.lower(string.Trim(explicit))
    end

    if (item.isBag) then
        return "backpack"
    end

    if (item.isOutfit) then
        return "outfit"
    end

    return nil
end

function INV.IsGearItem(item)
    return INV.GetGearSlot(item) ~= nil
end

function INV.GetGearEntityClass(item)
    if (not item) then
        return "nut_item"
    end

    local explicit = item.nxGearEntityClass or item.gearEntityClass
    if (isstring(explicit) and explicit ~= "") then
        return explicit
    end

    local slot = INV.GetGearSlot(item)
    if (slot and INV.GearEntityClasses[slot]) then
        return INV.GearEntityClasses[slot]
    end

    return "nut_item"
end

function INV.GetItemWeight(item)
    if (not item) then
        return tonumber(getConfig("nxInvUnitWeight", 1)) or 1
    end

    local explicit = tonumber(item.nxWeight or item.weight)
    if (explicit and explicit > 0) then
        return explicit
    end

    local w = tonumber(item.width) or 1
    local h = tonumber(item.height) or 1
    local areaWeight = math.max(0.2, w * h * 0.8)

    return areaWeight
end

function INV.GetInventoryCharID(inventory)
    if (not inventory) then return nil end

    local charID = inventory:getData("char")
    if (charID) then
        return tonumber(charID)
    end

    local bagItemID = inventory:getData("item")
    if (not bagItemID) then
        return nil
    end

    local bagItem = nut.item.instances[bagItemID]
    if (not bagItem) then
        return nil
    end

    local parentInventory = nut.inventory.instances[bagItem.invID]
    if (not parentInventory or parentInventory == inventory) then
        return nil
    end

    return INV.GetInventoryCharID(parentInventory)
end

function INV.GetCharacterRootInventory(client)
    if (not IsValid(client) or not client.getChar) then return nil end

    local char = client:getChar()
    if (not char) then return nil end

    return char:getInv()
end

function INV.GetCharacterLoad(client, excludedItemID)
    local root = INV.GetCharacterRootInventory(client)
    if (not root) then return 0 end

    local total = 0
    local items = root:getItems()

    for id, item in pairs(items) do
        if (id ~= excludedItemID) then
            total = total + INV.GetItemWeight(item)
        end
    end

    return math.Round(total, 2)
end

function INV.GetEquippedGear(client)
    local root = INV.GetCharacterRootInventory(client)
    if (not root) then return {} end

    local slots = {}
    for _, item in pairs(root:getItems()) do
        if (item.getData and item:getData("equip") == true) then
            local slot = INV.GetGearSlot(item)
            if (slot and not slots[slot]) then
                slots[slot] = item
            end
        end
    end

    return slots
end

function INV.GetGearCarryBonus(item)
    if (not item) then return 0 end

    local explicit = tonumber(item.nxCarryBonus or item.carryBonus)
    if (explicit) then
        return explicit
    end

    if (item.isBag) then
        local w = tonumber(item.invWidth) or 2
        local h = tonumber(item.invHeight) or 2
        local perCell = tonumber(getConfig("nxInvBagCellBonus", 0.6)) or 0.6
        return w * h * perCell
    end

    if (item.isOutfit) then
        return tonumber(getConfig("nxInvOutfitBonus", 4)) or 4
    end

    return 0
end

function INV.GetCarryCapacity(client)
    local base = tonumber(getConfig("nxInvBaseCarry", 38)) or 38
    local bonus = 0

    for _, item in pairs(INV.GetEquippedGear(client)) do
        bonus = bonus + INV.GetGearCarryBonus(item)
    end

    return math.Round(base + bonus, 2)
end

local function getDropPosition(position)
    local client

    if (type(position) == "Player") then
        client = position
        position = position:getItemDropPos()
    end

    return position, client
end

function INV.SpawnItemEntity(item, position, angles, className)
    local instance = nut.item.instances[item and item.id or 0]
    if (not instance) then return nil end

    if (IsValid(instance.entity)) then
        instance.entity.nutIsSafe = true
        instance.entity:Remove()
    end

    position, client = getDropPosition(position)

    local entClass = isstring(className) and className ~= "" and className or "nut_item"
    local entity = ents.Create(entClass)
    if (not IsValid(entity)) then
        entity = ents.Create("nut_item")
    end
    if (not IsValid(entity)) then
        return nil
    end

    entity:Spawn()
    entity:SetPos(position)
    entity:SetAngles(angles or Angle(0, 0, 0))
    entity:setItem(item.id)
    instance.entity = entity

    if (IsValid(client)) then
        entity.nutSteamID = client:SteamID()
        entity.nutCharID = client:getChar():getID()
    end

    return entity
end

function INV.CanEquipItem(client, item)
    if (not IsValid(client) or not client.getChar or not item) then
        return false, "notAllowed"
    end

    local slot = INV.GetGearSlot(item)
    if (not slot) then
        return true
    end

    local root = INV.GetCharacterRootInventory(client)
    if (not root) then
        return false, "invalidInventory"
    end

    for _, other in pairs(root:getItems()) do
        if (other ~= item and other.getData and other:getData("equip") == true and INV.GetGearSlot(other) == slot) then
            return false, "nxGearSlotTaken"
        end
    end

    return true
end

function INV.EquipItem(client, item)
    local allowed, reason = INV.CanEquipItem(client, item)
    if (allowed == false) then
        return false, reason
    end

    item:setData("equip", true)
    return true
end

function INV.UnequipItem(client, item)
    if (not item) then return false end

    item:setData("equip", nil)
    return true
end

local function canFitCarryForInventory(inventory, item)
    local charID = INV.GetInventoryCharID(inventory)
    if (not charID) then
        return true
    end

    local client = findClientByCharID(charID)
    if (not IsValid(client)) then
        return true
    end

    local current = INV.GetCharacterLoad(client)
    local projected = current + INV.GetItemWeight(item)
    local maxCarry = INV.GetCarryCapacity(client)

    if (projected <= maxCarry) then
        return true
    end

    return false, "nxCarryOverLimit"
end

local function carryAccessRule(inventory, action, context)
    if (action ~= ACTION_ADD) then return nil end
    if (not context or not context.item) then return nil end

    return canFitCarryForInventory(inventory, context.item)
end

function PLUGIN:EnsureCarryRule(inventory)
    if (not inventory or not inventory.addAccessRule) then return end
    if (inventory.nxCarryRuleAdded) then return end

    inventory.nxCarryRuleAdded = true
    inventory:addAccessRule(carryAccessRule, 1)
end

function PLUGIN:CharacterLoaded(id)
    local character = nut.char.loaded[id]
    if (not character or not character.getInv) then return end

    self:EnsureCarryRule(character:getInv())
end

function PLUGIN:PlayerLoadedChar(client, character)
    if (not character or not character.getInv) then return end

    self:EnsureCarryRule(character:getInv())

    if (SERVER) then
        INV.SyncHGRPArmorContainerState(client)
    end
end

function PLUGIN:SetupBagInventoryAccessRules(inventory)
    self:EnsureCarryRule(inventory)
end

function PLUGIN:OnLoaded()
    INV.EnsureGearEntityClasses()

    for _, inventory in pairs(nut.inventory.instances or {}) do
        self:EnsureCarryRule(inventory)
    end
end

function PLUGIN:CanItemBeTransfered(itemObject, curInv, inventory)
    if (not itemObject) then return nil end

    if (inventory and itemObject.getData and itemObject:getData("equip") == true and INV.IsGearItem(itemObject)) then
        return false, "equippedBag"
    end

    return nil
end

function PLUGIN:CanPlayerDropItem(client, item)
    if (item and item.getData and item:getData("equip") == true and INV.IsGearItem(item)) then
        client:notifyLocalized("nxUnequipFirst")
        return false
    end
end

function PLUGIN:InitializedItems()
    local bagBase = nut.item.base["base_bags"]
    if (not bagBase) then return end

    bagBase.nxGearSlot = bagBase.nxGearSlot or "backpack"
    bagBase.nxGearEntityClass = bagBase.nxGearEntityClass or INV.GearEntityClasses.backpack

    bagBase.functions = bagBase.functions or {}

    if (not bagBase.functions.Equip) then
        bagBase.functions.Equip = {
            name = "Equip",
            tip = "equipTip",
            icon = "icon16/tick.png",
            onRun = function(item)
                local client = item.player
                if (not IsValid(client) or not client.getChar) then return false end

                local ok, reason = INV.EquipItem(client, item)
                if (ok == false) then
                    client:notifyLocalized(reason or "notAllowed")
                    return false
                end

                client:EmitSound("items/ammo_pickup.wav", 70, 115)
                return false
            end,
            onCanRun = function(item)
                return (not IsValid(item.entity)) and item:getData("equip") ~= true
            end
        }
    end

    if (not bagBase.functions.EquipUn) then
        bagBase.functions.EquipUn = {
            name = "Unequip",
            tip = "unequipTip",
            icon = "icon16/cross.png",
            onRun = function(item)
                local client = item.player
                INV.UnequipItem(client, item)

                if (IsValid(client)) then
                    client:EmitSound("items/ammo_pickup.wav", 65, 88)
                end

                return false
            end,
            onCanRun = function(item)
                return (not IsValid(item.entity)) and item:getData("equip") == true
            end
        }
    end

    local previousDropHook = bagBase.hooks and bagBase.hooks.drop
    bagBase.hooks = bagBase.hooks or {}
    bagBase.hooks.drop = function(item, data)
        if (item:getData("equip") == true) then
            INV.UnequipItem(item.player, item)
        end

        if (isfunction(previousDropHook)) then
            return previousDropHook(item, data)
        end
    end

    local previousTransfer = bagBase.onCanBeTransfered
    bagBase.onCanBeTransfered = function(self, oldInventory, newInventory)
        if (newInventory and self:getData("equip") == true) then
            return false
        end

        if (previousTransfer) then
            return previousTransfer(self, oldInventory, newInventory)
        end

        return true
    end

    local previousSpawn = bagBase.spawn
    bagBase.spawn = function(self, position, angles)
        local className = INV.GetGearEntityClass(self)
        if (className ~= "nut_item") then
            return INV.SpawnItemEntity(self, position, angles, className)
        end

        if (isfunction(previousSpawn)) then
            return previousSpawn(self, position, angles)
        end

        return INV.SpawnItemEntity(self, position, angles, "nut_item")
    end

    local outfitBase = nut.item.base["base_outfit"]
    if (outfitBase) then
        outfitBase.nxGearSlot = outfitBase.nxGearSlot or "armor"
        outfitBase.nxGearEntityClass = outfitBase.nxGearEntityClass or INV.GearEntityClasses.armor
    end

    local pacOutfitBase = nut.item.base["base_pacoutfit"]
    if (pacOutfitBase) then
        pacOutfitBase.nxGearSlot = pacOutfitBase.nxGearSlot or "armor"
        pacOutfitBase.nxGearEntityClass = pacOutfitBase.nxGearEntityClass or INV.GearEntityClasses.armor
    end
end

if (SERVER) then
    nut.command.add("nxinvstatus", {
        onRun = function(client)
            if (not IsValid(client) or not client.getChar or not client:getChar()) then
                return
            end

            local load = INV.GetCharacterLoad(client)
            local cap = INV.GetCarryCapacity(client)
            local equipped = INV.GetEquippedGear(client)

            local slots = {}
            for slot, item in pairs(equipped) do
                slots[#slots + 1] = slot..":"..(item.name or item.uniqueID or "item")
            end
            table.sort(slots)

            client:notify(string.format("Carry %.1f / %.1f", load, cap))
            client:notify("Gear "..(#slots > 0 and table.concat(slots, ", ") or "none"))
        end
    })
end
