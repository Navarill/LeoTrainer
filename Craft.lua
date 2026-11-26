local Craft = {
    namesToPatternIndexes = {},
    isCrafting = false
}

function Craft.Initialize()
end

function Craft.MaxStyle(piece)
    local maxStyleId = -1
    local maxQty = 0
    for _, i in ipairs(LeoTrainer.const.racialStyles) do
        if IsSmithingStyleKnown(i, piece) == true then
            local qty = GetCurrentSmithingStyleItemCount(i)
            if qty > maxQty then
                maxStyleId = i
                maxQty = qty
            end
        end
    end
    return maxStyleId
end

function Craft.GetPatternIndexes(craft)
    Craft.namesToPatternIndexes[craft] = {
        ["names"] = {},
        ["lines"] = {}
    }
    for patternIndex = 1, GetNumSmithingPatterns() do
        local _, name = GetSmithingPatternInfo(patternIndex)
        Craft.namesToPatternIndexes[craft]["names"][name] = patternIndex
    end

    for line = 1, GetNumSmithingResearchLines(craft) do
        local lineName = GetSmithingResearchLineInfo(craft, line)
        Craft.namesToPatternIndexes[craft]["lines"][line] = Craft.namesToPatternIndexes[craft]["names"][lineName]
    end
end

function Craft.GetPattern(craftSkill, line)
    return Craft.namesToPatternIndexes[craftSkill] and Craft.namesToPatternIndexes[craftSkill]["lines"][line] or nil
end

local function wasCraftedByMe(bagId, slotIndex)
    local creator = GetItemCreatorName(bagId, slotIndex)
    if creator == nil or creator == "" then return false end

    local charList = LeoAltholic.ExportCharacters()
    for _, char in pairs(charList) do
        if creator == char.bio.name then return true end
    end

    return false
end

function Craft.ScanBackpackForCrafted()
    local list = {}
    local bag = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
    for _, data in pairs(bag) do
        local itemLink = GetItemLink(data.bagId, data.slotIndex, LINK_STYLE_BRACKETS)
        local itemType = GetItemType(data.bagId, data.slotIndex)
        local trait = GetItemLinkTraitInfo(itemLink)
        if wasCraftedByMe(data.bagId, data.slotIndex)
            and (itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON)
            and trait ~= ITEM_TRAIT_TYPE_NONE
            and GetItemFunctionalQuality(data.bagId, data.slotIndex) == ITEM_FUNCTIONAL_QUALITY_NORMAL then
            table.insert(list, {
                bagId = data.bagId,
                slotIndex = data.slotIndex,
                itemLink = itemLink
            })
        end
    end
    return list
end

function Craft.MarkItem(bagId, slotIndex)
    if FCOIS then
        local itemLinkBag = GetItemLink(bagId, slotIndex)
        LeoTrainer.log("Marking " .. itemLinkBag .. " for research")
        FCOIS.MarkItem(bagId, slotIndex, FCOIS_CON_ICON_RESEARCH, true)
    end
end

local function addItemToLLC(queueIndex, data)
    LeoTrainer.log("Crafting " .. data.itemLink .. " (" .. data.researchName .. ") ...")

    local craftLines = Craft.namesToPatternIndexes and Craft.namesToPatternIndexes[data.craft] and Craft.namesToPatternIndexes[data.craft]["lines"]
    local patternIndex = craftLines and craftLines[data.line]
    if not patternIndex then
        LeoTrainer.debug("Missing pattern mapping for craft " .. tostring(data.craft) .. " line " .. tostring(data.line))
        return false
    end
    data.patternIndex = patternIndex

    local matName, _, matReq = GetSmithingPatternMaterialItemInfo(data.patternIndex, data.materialIndex)
    data.materialQuantity = matReq

    local curMats = GetCurrentSmithingMaterialItemCount(data.patternIndex, data.materialIndex)
    if curMats < data.materialQuantity then
        local diff = data.materialQuantity - curMats
        LeoTrainer.log("Not enough " .. matName .. ". Need " .. diff .. " more.")
        return false
    end

    data.itemStyleId = Craft.MaxStyle(data.line)

    if data.itemStyleId == -1 and data.craft ~= CRAFTING_TYPE_JEWELRYCRAFTING then
        LeoTrainer.log("Not enough known style material.")
        return false
    end

    LeoTrainer.LLC:CraftSmithingItem(
        data.patternIndex,
        data.materialIndex,
        data.materialQuantity,
        data.itemStyleId,
        data.traitIndex + 1,
        data.useUniversalStyleItem,
        nil,
        nil,
        ITEM_FUNCTIONAL_QUALITY_NORMAL,
        true,
        queueIndex
    )

    return true
end

local function isTrainerMatch(trainer, currentCharId)
    if trainer == "Anyone" then return true end
    local currentIdStr = tostring(currentCharId)
    if tostring(trainer) == currentIdStr then return true end
    local char = LeoAltholic.GetCharByName and LeoAltholic.GetCharByName(trainer)
    return char and char.bio and tostring(char.bio.id) == currentIdStr or false
end

local function addItemsToLLC()
    local craftSkill = GetCraftingInteractionType()
    local currentCharId = GetCurrentCharacterId()
    for index, data in ipairs(LeoTrainer.data.craftQueue) do
        local canTrainerCraft = isTrainerMatch(data.trainer, currentCharId)
        if not data.crafted and canTrainerCraft and data.craft == craftSkill and LeoAltholic.CharKnowsTrait(data.craft, data.line, data.trait) == true then
            if addItemToLLC(index, data) then Craft.isCrafting = true end
        end
    end
    if Craft.isCrafting == true then return end

    LeoTrainer.debug("Nothing more to craft at this station.")
    Craft.isCrafting = false
end

function Craft.TryWritCreator(craftSkill)
    if WritCreater then
        EVENT_MANAGER:RegisterForEvent(WritCreater.name, EVENT_CRAFT_COMPLETED, WritCreater.craftCompleteHandler)
        WritCreater.craftCheck(1, craftSkill)
    end
    LibLazyCrafting.craftInteract(1, craftSkill)
end

function Craft.StillHaveCraftToDo(craftSkill)
    local currentCharId = GetCurrentCharacterId()
    for _, data in pairs(LeoTrainer.data.craftQueue) do
        local canTrainerCraft = isTrainerMatch(data.trainer, currentCharId)
        if canTrainerCraft and data.craft == craftSkill and not data.crafted then return true end
    end

    return false
end

function Craft.RemoveCraftedFromQueue(craftSkill)
    local i = 1
    while i <= #LeoTrainer.data.craftQueue do
        if LeoTrainer.data.craftQueue[i].crafted then
            table.remove(LeoTrainer.data.craftQueue, i)
        else
            i = i + 1
        end
    end
    LeoTrainer.LLC:cancelItem(craftSkill)
end

function Craft.OnStationExit(craftSkill)
    Craft.RemoveCraftedFromQueue(craftSkill)
end

function Craft.StartCraft(craftSkill)
    LeoTrainerWindowQueuePanelQueueScrollCraftAll:SetState(BSTATE_DISABLED)
    if craftSkill == nil then craftSkill = GetCraftingInteractionType() end
    addItemsToLLC()
    LibLazyCrafting.craftInteract(1, craftSkill)
end

function Craft.OnStationEnter(craftSkill)
    if craftSkill == CRAFTING_TYPE_ENCHANTING then
        LeoTrainer.nextStage()
        return
    end

    Craft.GetPatternIndexes(craftSkill)

    Craft.isCrafting = false

    if #LeoTrainer.data.craftQueue > 0 and LeoTrainer.settings.craft.auto then
        Craft.StartCraft(craftSkill)
        return
    end

    LeoTrainer.nextStage()
end

LeoTrainer.craft = Craft