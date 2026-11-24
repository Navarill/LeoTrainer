local Research = {
    queue = {},
    isResearching = false,
    keybindStripDescriptor =
    {
        {
            name = "Research",
            keybind = "LEOTRAINER_RESEARCH",
            callback = function() LeoTrainer.research.ResearchNext() end,
        },
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
    }
}

local function resolveTraitIndex(craftSkill, line, itemTraitType)
    if not craftSkill or not line or not itemTraitType then return nil end
    local _, _, numTraits = GetSmithingResearchLineInfo(craftSkill, line)
    for traitIndex = 1, numTraits do
        if GetSmithingResearchLineTraitInfo(craftSkill, line, traitIndex) == itemTraitType then
            return traitIndex
        end
    end
    return nil
end

function Research.GetResearchData(link)
    if not link then return false end

    local craftSkill, line
    local traitType = GetItemLinkTraitInfo(link)
    local equipType = GetItemLinkEquipType(link)

    if traitType == ITEM_TRAIT_TYPE_NONE
        or traitType == ITEM_TRAIT_TYPE_ARMOR_INTRICATE or traitType == ITEM_TRAIT_TYPE_ARMOR_ORNATE
        or traitType == ITEM_TRAIT_TYPE_WEAPON_INTRICATE or traitType == ITEM_TRAIT_TYPE_WEAPON_ORNATE
        or traitType == ITEM_TRAIT_TYPE_JEWELRY_INTRICATE or traitType == ITEM_TRAIT_TYPE_JEWELRY_ORNATE then
        return false
    end

    local armorType = GetItemLinkArmorType(link)
    local weaponType = GetItemLinkWeaponType(link)

    if weaponType == WEAPONTYPE_AXE then craftSkill = CRAFTING_TYPE_BLACKSMITHING; line = 1
    elseif weaponType == WEAPONTYPE_HAMMER then craftSkill = CRAFTING_TYPE_BLACKSMITHING; line = 2
    elseif weaponType == WEAPONTYPE_SWORD then craftSkill = CRAFTING_TYPE_BLACKSMITHING; line = 3
    elseif weaponType == WEAPONTYPE_TWO_HANDED_AXE then craftSkill = CRAFTING_TYPE_BLACKSMITHING; line = 4
    elseif weaponType == WEAPONTYPE_TWO_HANDED_HAMMER then craftSkill = CRAFTING_TYPE_BLACKSMITHING; line = 5
    elseif weaponType == WEAPONTYPE_TWO_HANDED_SWORD then craftSkill = CRAFTING_TYPE_BLACKSMITHING; line = 6
    elseif weaponType == WEAPONTYPE_DAGGER then craftSkill = CRAFTING_TYPE_BLACKSMITHING; line = 7
    elseif weaponType == WEAPONTYPE_BOW then craftSkill = CRAFTING_TYPE_WOODWORKING; line = 1
    elseif weaponType == WEAPONTYPE_FIRE_STAFF then craftSkill = CRAFTING_TYPE_WOODWORKING; line = 2
    elseif weaponType == WEAPONTYPE_FROST_STAFF then craftSkill = CRAFTING_TYPE_WOODWORKING; line = 3
    elseif weaponType == WEAPONTYPE_LIGHTNING_STAFF then craftSkill = CRAFTING_TYPE_WOODWORKING; line = 4
    elseif weaponType == WEAPONTYPE_HEALING_STAFF then craftSkill = CRAFTING_TYPE_WOODWORKING; line = 5
    elseif weaponType == WEAPONTYPE_SHIELD then craftSkill = CRAFTING_TYPE_WOODWORKING; line = 6
    elseif equipType == EQUIP_TYPE_NECK then craftSkill = CRAFTING_TYPE_JEWELRYCRAFTING; line = 1
    elseif equipType == EQUIP_TYPE_RING then craftSkill = CRAFTING_TYPE_JEWELRYCRAFTING; line = 2
    else
        local armorLine
        if equipType == EQUIP_TYPE_CHEST then armorLine = 1
        elseif equipType == EQUIP_TYPE_FEET then armorLine = 2
        elseif equipType == EQUIP_TYPE_HAND then armorLine = 3
        elseif equipType == EQUIP_TYPE_HEAD then armorLine = 4
        elseif equipType == EQUIP_TYPE_LEGS then armorLine = 5
        elseif equipType == EQUIP_TYPE_SHOULDERS then armorLine = 6
        elseif equipType == EQUIP_TYPE_WAIST then armorLine = 7
        end

        if armorLine then
            if armorType == ARMORTYPE_HEAVY then
                craftSkill = CRAFTING_TYPE_BLACKSMITHING
                line = armorLine + 7
            elseif armorType == ARMORTYPE_MEDIUM then
                craftSkill = CRAFTING_TYPE_CLOTHIER
                line = armorLine + 7
            elseif armorType == ARMORTYPE_LIGHT then
                craftSkill = CRAFTING_TYPE_CLOTHIER
                line = armorLine
            end
        end
    end

    local trait = resolveTraitIndex(craftSkill, line, traitType)
    if craftSkill and line and trait then
        return craftSkill, line, trait
    end
    return false
end

local function canIResearchItem(itemLink)
    local craftSkill, line, trait = Research.GetResearchData(itemLink)

    if not craftSkill then return false end

    local isKnown, isResearching = LeoAltholic.ResearchStatus(craftSkill, line, trait)
    if isKnown or isResearching then
        return false
    end

    return true
end

function Research.CanItemBeResearched(bagId, slotIndex, itemLink, craftSkill)
    if not FCOIS then return false end

    if itemLink == nil then itemLink = GetItemLink(bagId, slotIndex) end

    local itemType = GetItemType(bagId, slotIndex)
    if itemType ~= ITEMTYPE_ARMOR and itemType ~= ITEMTYPE_WEAPON then return false end

    if FCOIS.IsIconEnabled(FCOIS_CON_ICON_RESEARCH) and not FCOIS.IsMarked(bagId, slotIndex, FCOIS_CON_ICON_RESEARCH) then
        return false
    end

    local creator = GetItemCreatorName(bagId, slotIndex)
    if not LeoTrainer.settings.research.allowCrafted and creator ~= nil and creator ~= "" then
        return false
    end

    local hasSet = GetItemLinkSetInfo(itemLink)
    if not LeoTrainer.settings.research.allowSets and hasSet then
        return false
    end

    if craftSkill ~= nil and craftSkill > 0 and LeoTrainer.settings.research.maxQuality[craftSkill] < GetItemFunctionalQuality(bagId, slotIndex) then
        return false
    end

    return true
end

function Research.ScanBags()
    local list = {}
    local items = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK)
    for _, data in pairs(items) do
        local itemLink = GetItemLink(data.bagId, data.slotIndex, LINK_STYLE_BRACKETS)
        local craftSkill, line, trait = LeoTrainer.research.GetResearchData(itemLink)
        if craftSkill and LeoTrainer.research.CanItemBeResearched(data.bagId, data.slotIndex, itemLink, craftSkill) then
            table.insert(list, {
                bagId = data.bagId,
                slotIndex = data.slotIndex,
                itemLink = itemLink,
                craftSkill = craftSkill,
                line = line,
                trait = trait,
                selected = false
            })
        end
    end

    return list
end

function Research.ScanBagsUnfiltered()
    local list = {}
    local items = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK)
    for _, data in pairs(items) do
        local itemLink = GetItemLink(data.bagId, data.slotIndex, LINK_STYLE_BRACKETS)
        local craftSkill, line, trait = LeoTrainer.research.GetResearchData(itemLink)
        if craftSkill then
            local hasSet = GetItemLinkSetInfo(itemLink)
            if LeoTrainer.settings.research.allowSets or not hasSet then
                table.insert(list, {
                    bagId = data.bagId,
                    slotIndex = data.slotIndex,
                    itemLink = itemLink,
                    craftSkill = craftSkill,
                    line = line,
                    trait = trait,
                    selected = false
                })
            end
        end
    end

    return list
end

function Research.HandleItem(bagId, slotIndex, itemLink, craftSkill)
    local itemCraftSkill, line, trait = Research.GetResearchData(itemLink)

    if itemCraftSkill ~= craftSkill then return false end

    if not Research.CanItemBeResearched(bagId, slotIndex, itemLink, craftSkill) then return false end

    if not canIResearchItem(itemLink) then return false end

    if LeoTrainer.settings.research.listInChat then
        LeoTrainer.log("Can be researched: " .. itemLink)
    end

    table.insert(Research.queue, {
        bagId = bagId,
        slotIndex = slotIndex,
        itemLink = itemLink,
        craftSkill = craftSkill,
        line = line,
        trait = trait,
        selected = false,
        isResearching = false
    })

    return true
end

function Research.OnResearchComplete(_, craftSkill)
    EVENT_MANAGER:UnregisterForUpdate(LeoTrainer.name .. ".ResearchTimeout")
    EVENT_MANAGER:UnregisterForEvent(LeoTrainer.name, EVENT_CRAFT_COMPLETED)

    if not Research.isResearching then
        LeoTrainer.nextStage(true)
        return
    end

    local researching, total = LeoAltholic.GetResearchCounters(craftSkill)
    for j, data in pairs(Research.queue) do
        if data.isResearching == true then
            table.remove(Research.queue, j)
            break
        end
    end
    Research.isResearching = false

    if researching >= total then
        LeoTrainer.debug("No empty research slots.")
        LeoTrainer.nextStage(true)
        return
    end

    if #Research.queue > 0 then
        zo_callLater(function() Research.ResearchNext(craftSkill) end, 200)
        return
    end

    LeoTrainer.nextStage(true)
end

local function OnResearchTimeout(craftSkill)
    return function()
        EVENT_MANAGER:UnregisterForUpdate(LeoTrainer.name .. ".ResearchTimeout")
        EVENT_MANAGER:UnregisterForEvent(LeoTrainer.name, EVENT_CRAFT_COMPLETED)
        Research.isResearching = false
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "Timeout during research")
        LeoTrainer.nextStage()
    end
end

local lineList

function Research.ResearchNext(craftSkill)
    Research.isResearching = false

    if craftSkill == nil then craftSkill = GetCraftingInteractionType() end

    if #Research.queue == 0 then
        LeoTrainer.debug("Nothing on research queue")
        LeoTrainer.nextStage()
        return
    end

    if not LeoTrainer.IsInUsableStation() or not LeoAltholic.HasStillResearchFor(craftSkill) then
        LeoTrainer.debug("Nothing to research here.")
        LeoTrainer.nextStage()
        return
    end

    local myName = GetUnitName("player")
    local researching, total = LeoAltholic.GetResearchCounters(craftSkill, myName)
    if researching >= total then
        LeoTrainer.debug("No empty research slots.")
        LeoTrainer.nextStage()
        return
    end
    if IsPerformingCraftProcess() == true then
        LeoTrainer.debug("Still crafting")
        Research.isResearching = true
        zo_callLater(function() Research.ResearchNext(craftSkill) end, 500)
        return
    end

    if lineList == nil then lineList = LeoTrainer.GetPriorityLineList(myName, craftSkill) end
    for i, lineData in ipairs(lineList[myName][craftSkill]) do
        if not lineData.added and not lineData.isResearching then
            for j, data in pairs(Research.queue) do
                if lineData.line == data.line then
                    lineList[myName][craftSkill][i].added = true
                    local itemLink = GetItemLink(data.bagId, data.slotIndex, LINK_STYLE_BRACKETS)
                    local traitType = GetItemLinkTraitInfo(itemLink)
                    local traitName = GetString("SI_ITEMTRAITTYPE", traitType)
                    local message = zo_strformat("<<1>> <<2>> (<<3>>)",
                        GetString(SI_GAMEPAD_SMITHING_CURRENT_RESEARCH_HEADER),
                        itemLink,
                        traitName)
                    LeoTrainer.log(message)

                    EVENT_MANAGER:RegisterForUpdate(LeoTrainer.name .. ".ResearchTimeout", 2000, OnResearchTimeout(craftSkill))
                    EVENT_MANAGER:RegisterForEvent(LeoTrainer.name, EVENT_CRAFT_COMPLETED, Research.OnResearchComplete)

                    Research.isResearching = true
                    Research.queue[j].isResearching = true
                    ResearchSmithingTrait(data.bagId, data.slotIndex)
                    return
                end
            end
        end
    end

    LeoTrainer.debug("No item found for research")
    LeoTrainer.nextStage()
end

function Research.ShouldResearch(craftSkill)
    return LeoAltholic.HasStillResearchFor(craftSkill)
end

function Research.OnStationEnter(craftSkill)
    lineList = nil
    if craftSkill == CRAFTING_TYPE_ENCHANTING or not LeoAltholic.HasStillResearchFor(craftSkill) then
        LeoTrainer.nextStage()
        return
    end

    if #Research.queue > 0 then
        KEYBIND_STRIP:AddKeybindButtonGroup(Research.keybindStripDescriptor)
    end

    if #Research.queue == 0 or not LeoTrainer.settings.research.auto then
        LeoTrainer.nextStage()
        return
    end

    Research.ResearchNext(craftSkill)
end

function Research.OnStationExit(craftSkill)
    EVENT_MANAGER:UnregisterForUpdate(LeoTrainer.name .. ".ResearchTimeout")
    EVENT_MANAGER:UnregisterForEvent(LeoTrainer.name, EVENT_CRAFT_COMPLETED)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(Research.keybindStripDescriptor)
    Research.isResearching = false
    lineList = nil
    Research.queue = {}
end

function Research.Initialize()
    local charList = LeoAltholic.ExportCharacters()

    LeoTrainer.knowledge = {}
    LeoTrainer.missingKnowledge = {}

    for _, char in pairs(charList) do
        if LeoTrainer.data.trackedTraits[char.bio.name] == nil then
            LeoTrainer.data.trackedTraits[char.bio.name] = {}
        end
        if not LeoTrainer.data.fillSlot[char.bio.name] then
            LeoTrainer.data.fillSlot[char.bio.name] = {}
        end
        for _, craftId in pairs(LeoAltholic.craftResearch) do
            LeoTrainer.data.trackedTraits[char.bio.name][craftId] = LeoTrainer.data.trackedTraits[char.bio.name][craftId] or false
            LeoTrainer.data.fillSlot[char.bio.name][craftId] = LeoTrainer.data.fillSlot[char.bio.name][craftId] or false
        end

        for _, craft in pairs(LeoAltholic.craftResearch) do
            if LeoTrainer.knowledge[craft] == nil then LeoTrainer.knowledge[craft] = {} end
            if LeoTrainer.missingKnowledge[craft] == nil then LeoTrainer.missingKnowledge[craft] = {} end
            for line = 1, GetNumSmithingResearchLines(craft) do
                if LeoTrainer.knowledge[craft][line] == nil then LeoTrainer.knowledge[craft][line] = {} end
                if LeoTrainer.missingKnowledge[craft][line] == nil then LeoTrainer.missingKnowledge[craft][line] = {} end
                local _, _, numTraits = GetSmithingResearchLineInfo(craft, line)
                for trait = 1, numTraits do
                    if LeoTrainer.knowledge[craft][line][trait] == nil then LeoTrainer.knowledge[craft][line][trait] = {} end
                    if LeoTrainer.missingKnowledge[craft][line][trait] == nil then LeoTrainer.missingKnowledge[craft][line][trait] = {} end
                    if LeoTrainer.IsTraitKnownOrFinished(char, craft, line, trait) then
                        table.insert(LeoTrainer.knowledge[craft][line][trait], char.bio.name)
                    else
                        table.insert(LeoTrainer.missingKnowledge[craft][line][trait], char.bio.name)
                    end
                end
            end
        end
    end
end

LeoTrainer.research = Research