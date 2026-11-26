local initialized = false

function LeoTrainer.IsInUsableStation()
    local station = GetCraftingInteractionType()

    return station == CRAFTING_TYPE_BLACKSMITHING or
        station == CRAFTING_TYPE_WOODWORKING or
        station == CRAFTING_TYPE_CLOTHIER or
        station == CRAFTING_TYPE_JEWELRYCRAFTING or
        station == CRAFTING_TYPE_ENCHANTING
end

function LeoTrainer.LLC_Completed(event, station, result)
    if event == LLC_NO_FURTHER_CRAFT_POSSIBLE then
        LeoTrainer.debug("Nothing more to craft at this station.")
        if LeoTrainer.stage == LEOTRAINER_STAGE_CRAFT then
            LeoTrainer.nextStage()
        end
        return
    end

    if event ~= LLC_CRAFT_SUCCESS then return end

    if result.Requester ~= LeoTrainer.name then return end

    if LeoTrainer.data.craftQueue[result.reference] then
        LeoTrainer.data.craftQueue[result.reference].crafted = true
    end
    LeoTrainer.ui.queueScroll:RefreshData()

    LeoTrainer.craft.MarkItem(result.bag, result.slot)

    if LeoTrainer.craft.StillHaveCraftToDo(station) then return end

    LeoTrainer.debug("All crafts done at this station.")
    LeoTrainer.nextStage()
end

function LeoTrainer.nextStage(moreDelay)
    LeoTrainer.stage = LeoTrainer.stage + 1
    if LeoTrainer.stage > LEOTRAINER_STAGE_DONE then
        LeoTrainer.stage = LEOTRAINER_STAGE_START
    end
    local craftSkill = GetCraftingInteractionType()
    if craftSkill > 0 then
        zo_callLater(function() LeoTrainer.continueAtStation(craftSkill) end, moreDelay and 200 or 10)
    end
end

function LeoTrainer.continueAtStation(craftSkill)
    if LeoTrainer.stage == LEOTRAINER_STAGE_RESEARCH then
        LeoTrainer.ui.OnStationEnter(craftSkill)
        zo_callLater(function() LeoTrainer.research.OnStationEnter(craftSkill) end, 10)
        return
    end

    if LeoTrainer.stage == LEOTRAINER_STAGE_DECONSTRUCT then
        zo_callLater(function() LeoTrainer.deconstruct.OnStationEnter(craftSkill) end, 10)
        return
    end

    if LeoTrainer.stage == LEOTRAINER_STAGE_CRAFT then
        zo_callLater(function() LeoTrainer.craft.OnStationEnter(craftSkill) end, 10)
        return
    end

    if LeoTrainer.stage == LEOTRAINER_STAGE_DONE then
        zo_callLater(function() LeoTrainer.craft.TryWritCreator(craftSkill) end, 10)
        return
    end
end

function LeoTrainer.stationEnter(craftSkill, sameStation)
    if sameStation then
        return
    end

    if not LeoTrainer.IsInUsableStation() then
        LeoTrainer.craft.TryWritCreator(craftSkill)
        return
    end

    if WritCreater then
        EVENT_MANAGER:UnregisterForEvent(WritCreater.name, EVENT_CRAFT_COMPLETED)
    end

    LeoTrainer.ScanBags(craftSkill)

    LeoTrainer.stage = LEOTRAINER_STAGE_RESEARCH

    LeoTrainer.continueAtStation(craftSkill)
end

function LeoTrainer.stationExit(_, craftSkill)
    EVENT_MANAGER:UnregisterForEvent(LeoTrainer.name, EVENT_CRAFT_COMPLETED)
    if WritCreater then
        EVENT_MANAGER:UnregisterForEvent(WritCreater.name, EVENT_CRAFTING_STATION_INTERACT)
        EVENT_MANAGER:UnregisterForEvent(WritCreater.name, EVENT_CRAFT_COMPLETED)
    end

    LeoTrainer.ui.OnStationExit(craftSkill)
    LeoTrainer.research.OnStationExit(craftSkill)
    LeoTrainer.deconstruct.OnStationExit(craftSkill)
    LeoTrainer.craft.OnStationExit(craftSkill)
end

local woodworkingWeapons = {
    [WEAPONTYPE_BOW]             = true,
    [WEAPONTYPE_SHIELD]          = true,
    [WEAPONTYPE_FIRE_STAFF]      = true,
    [WEAPONTYPE_FROST_STAFF]     = true,
    [WEAPONTYPE_LIGHTNING_STAFF] = true,
    [WEAPONTYPE_HEALING_STAFF]   = true,
}

function LeoTrainer.CraftToLineSkill(craftSkill)
    local skillType, skillLineIndex = GetCraftingSkillLineIndices(craftSkill)
    if skillType == SKILL_TYPE_TRADESKILL and skillLineIndex and skillLineIndex > 0 then
        return skillLineIndex
    end
    return 0
end

function LeoTrainer.ItemLinkToCraftskill(itemLink)
    if not itemLink or itemLink == "" then return 0 end

    local weaponType = GetItemLinkWeaponType(itemLink)
    if weaponType and weaponType ~= WEAPONTYPE_NONE then
        if woodworkingWeapons[weaponType] then
            return CRAFTING_TYPE_WOODWORKING
        end
        return CRAFTING_TYPE_BLACKSMITHING
    end

    local armorType = GetItemLinkArmorType(itemLink)
    if armorType == ARMORTYPE_HEAVY then
        return CRAFTING_TYPE_BLACKSMITHING
    elseif armorType == ARMORTYPE_LIGHT or armorType == ARMORTYPE_MEDIUM then
        return CRAFTING_TYPE_CLOTHIER
    end

    local equipType = GetItemLinkEquipType(itemLink)
    if equipType == EQUIP_TYPE_NECK or equipType == EQUIP_TYPE_RING then
        return CRAFTING_TYPE_JEWELRYCRAFTING
    end

    if GetItemSoundCategoryFromLink(itemLink) == ITEM_SOUND_CATEGORY_ENCHANTMENT then
        return CRAFTING_TYPE_ENCHANTING
    end

    return 0
end

function LeoTrainer.GetCharacterId(char)
    if not char then return GetCurrentCharacterId() end
    return char.bio and char.bio.id or nil
end

function LeoTrainer.GetCharNameById(charId)
    if not charId or charId == "" or charId == "Anyone" then return charId end
    local char = LeoAltholic.GetCharById(charId)
    if char and char.bio and char.bio.name then
        return char.bio.name
    end
    for i = 1, GetNumCharacters() do
        local rawName, _, _, _, _, _, id = GetCharacterInfo(i)
        if id == charId then
            return zo_strformat("<<1>>", rawName)
        end
    end
    return charId
end

function LeoTrainer.IsTraitKnownOrFinished(char, craftSkill, line, trait)
    local charId = LeoTrainer.GetCharacterId(char)
    local isKnown, isResearching = LeoAltholic.ResearchStatus(craftSkill, line, trait, charId)
    if isKnown or isResearching then
        return true
    end
    if char.research and char.research.doing and char.research.doing[craftSkill] then
        for _, researching in pairs(char.research.doing[craftSkill]) do
            if researching.line == line and researching.trait == trait then
                return true
            end
        end
    end
    return false
end

local function isLineBeingResearched(research, craft, line)
    if not research or not research.doing or not research.doing[craft] then return false end
    for _, researching in pairs(research.doing[craft]) do
        if researching.line == line then
            if researching.doneAt and researching.doneAt - GetTimeStamp() > 0 then
                return true
            end
        end
    end
    return false
end

local function get(tbl, k, ...)
    if tbl == nil or tbl[k] == nil then return nil end
    if select('#', ...) == 0 then return tbl[k] end
    return get(tbl[k], ...)
end

local function set(tbl, k, maybeValue, ...)
    if select('#', ...) == 0 then
        tbl[k] = maybeValue
        return
    end
    if tbl[k] == nil then tbl[k] = {} end
    set(tbl[k], maybeValue, ...)
end

function LeoTrainer.GetPriorityLineList(charIdFilter, craftSkillFilter)
    local charList
    if charIdFilter == nil then
        charList = LeoAltholic.ExportCharacters()
    else
        local char = LeoAltholic.GetCharById(charIdFilter)
        charList = char and { char } or {}
    end

    local craftSkillList = LeoAltholic.craftResearch
    if craftSkillFilter ~= nil then craftSkillList = {craftSkillFilter} end
    local knownCount = {}
    local unknownTraits = {}
    local lineList = {}
    for _, char in pairs(charList) do
        local charId = LeoTrainer.GetCharacterId(char)
        for _, craftSkill in pairs(craftSkillList) do
            set(lineList, charId, craftSkill, {})

            if LeoTrainer.isTrackingSkill(charId, craftSkill) and LeoTrainer.canFillSlotWithSkill(charId, craftSkill) then

                for line = 1, GetNumSmithingResearchLines(craftSkill) do
                    local lineName, _, numTraits = GetSmithingResearchLineInfo(craftSkill, line)

                    set(unknownTraits, charId, craftSkill, line, {})
                    set(knownCount, charId, craftSkill, line, 0)

                    for trait = 1, numTraits do
                        if LeoTrainer.IsTraitKnownOrFinished(char, craftSkill, line, trait) then
                            local numKnown = get(knownCount, charId, craftSkill, line)
                            numKnown = numKnown + 1
                            set(knownCount, charId, craftSkill, line, numKnown)
                        else
                            table.insert(unknownTraits[charId][craftSkill][line], trait)
                        end
                    end

                    table.insert(lineList[charId][craftSkill], {
                        line = line,
                        lineName = lineName,
                        count = knownCount[charId][craftSkill][line],
                        unknownTraits = unknownTraits[charId][craftSkill][line],
                        isResearching = isLineBeingResearched(char.research, craftSkill, line)
                    })
                end

                table.sort(lineList[charId][craftSkill], function(a, b)
                    if a.count == b.count then
                        return a.line < b.line
                    end
                    return a.count < b.count
                end)

            end
        end
    end

    return lineList
end

function LeoTrainer.ScanBags(craftSkill)
    local shouldResearch = LeoTrainer.research.ShouldResearch(craftSkill)
    local shouldDeconstruct = LeoTrainer.deconstruct.ShouldDeconstruct(craftSkill)
    local list = {}
    local bags = { BAG_BACKPACK, BAG_BANK }
    if IsESOPlusSubscriber() then
        table.insert(bags, BAG_SUBSCRIBER_BANK)
    end

    for _, bagId in ipairs(bags) do
        local bagSize = GetBagSize(bagId)
        for slotIndex = 0, bagSize - 1 do
            if GetItemId(bagId, slotIndex) ~= 0 then
                local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
                local itemCraftSkill = LeoTrainer.ItemLinkToCraftskill(itemLink)
                if itemCraftSkill ~= nil and itemCraftSkill > 0 and itemCraftSkill == craftSkill then
                    local handled = false
                    if shouldResearch then
                        handled = LeoTrainer.research.HandleItem(bagId, slotIndex, itemLink, craftSkill)
                    end
                    if not handled and shouldDeconstruct then
                        handled = LeoTrainer.deconstruct.HandleItem(bagId, slotIndex, itemLink, craftSkill)
                    end
                end
            end
        end
    end

    return list
end

function LeoTrainer.isTrackingSkill(charId, craftId)
    return LeoTrainer.data.trackedTraits[charId] and LeoTrainer.data.trackedTraits[charId][craftId] or false
end

function LeoTrainer.setTrackingSkill(charId, craftId, tracking)
    LeoTrainer.data.trackedTraits[charId] = LeoTrainer.data.trackedTraits[charId] or {}
    LeoTrainer.data.trackedTraits[charId][craftId] = tracking
end

function LeoTrainer.canFillSlotWithSkill(charId, craftId)
    return LeoTrainer.data.fillSlot[charId] and LeoTrainer.data.fillSlot[charId][craftId] or false
end

function LeoTrainer.setFillSlotWithSkill(charId, craftId, tracking)
    LeoTrainer.data.fillSlot[charId] = LeoTrainer.data.fillSlot[charId] or {}
    LeoTrainer.data.fillSlot[charId][craftId] = tracking
end

local function copyLegacyTable(source, target)
    if type(source) ~= "table" or type(target) ~= "table" then return end
    for k, v in pairs(source) do
        if k ~= "version" and k ~= "$LastCharacterName" then
            if type(v) == "table" and type(target[k]) == "table" then
                copyLegacyTable(v, target[k])
            else
                target[k] = ZO_DeepTableCopy(v)
            end
        end
    end
end

local function migrateLegacySavedVars(worldName)
    if LeoTrainer.data.migratedFromLegacy then return end

    local displayName = GetDisplayName()
    local currentCharId = GetCurrentCharacterId()

    -- 1. Migrate from upstream LibSavedVars structure if present
    local legacySettingsRoot = LeoTrainer_Settings and LeoTrainer_Settings["Default"] and LeoTrainer_Settings["Default"][displayName]
    if legacySettingsRoot then
        local legacyAccount = legacySettingsRoot["$AccountWide"] or legacySettingsRoot["Account"]
        local legacyChar = legacySettingsRoot["Characters"] and legacySettingsRoot["Characters"][currentCharId]
        if legacyChar and legacyChar.accountWide == false then
            LeoTrainer.settingsControl.accountWide = false
            LeoTrainer.settings = ZO_SavedVars:NewCharacterIdSettings("LeoTrainer_Settings", 1, nil, LeoTrainer.settingsDefaults, worldName)
            copyLegacyTable(legacyChar, LeoTrainer.settings)
        elseif legacyAccount then
            copyLegacyTable(legacyAccount, LeoTrainer.settings)
        end
    end

    local legacyDataRoot = LeoTrainer_Data and LeoTrainer_Data["Default"] and LeoTrainer_Data["Default"][displayName]
    if legacyDataRoot and legacyDataRoot["$AccountWide"] then
        copyLegacyTable(legacyDataRoot["$AccountWide"], LeoTrainer.data)
    end

    -- 2. Convert any legacy character-name keys in trackedTraits, fillSlot, defaultTrainer, and craftQueue to charId (id64)
    local nameToId = {}
    for i = 1, GetNumCharacters() do
        local rawName, _, _, _, _, _, charId = GetCharacterInfo(i)
        if charId and charId ~= "" then
            local cleanName = zo_strformat("<<1>>", rawName)
            nameToId[cleanName] = charId
        end
    end

    local function migrateCharKeys(tbl)
        if type(tbl) ~= "table" then return end
        local pending = {}
        for key, value in pairs(tbl) do
            local resolvedId = nameToId[key]
            if resolvedId and resolvedId ~= key then
                table.insert(pending, { oldKey = key, newId = resolvedId, value = value })
            end
        end
        for _, entry in ipairs(pending) do
            if tbl[entry.newId] == nil then
                tbl[entry.newId] = entry.value
            end
            tbl[entry.oldKey] = nil
        end
    end

    migrateCharKeys(LeoTrainer.data.trackedTraits)
    migrateCharKeys(LeoTrainer.data.fillSlot)

    if LeoTrainer.settings.defaultTrainer and nameToId[LeoTrainer.settings.defaultTrainer] then
        LeoTrainer.settings.defaultTrainer = nameToId[LeoTrainer.settings.defaultTrainer]
    end

    if LeoTrainer.data.craftQueue then
        for _, item in pairs(LeoTrainer.data.craftQueue) do
            if item.trainer and nameToId[item.trainer] then
                item.trainer = nameToId[item.trainer]
            end
            if item.trainee and nameToId[item.trainee] then
                item.trainee = nameToId[item.trainee]
            end
            if item.knownList then
                for idx, trainerKey in ipairs(item.knownList) do
                    if nameToId[trainerKey] then
                        item.knownList[idx] = nameToId[trainerKey]
                    end
                end
            end
        end
    end

    LeoTrainer.data.migratedFromLegacy = true
end

function LeoTrainer.InitSavedVars()
    local worldName = GetWorldName()

    LeoTrainer.settingsControl = ZO_SavedVars:NewAccountWide("LeoTrainer_Settings", 1, "AccountWide", { accountWide = true }, worldName)

    if LeoTrainer.settingsControl.accountWide then
        LeoTrainer.settings = ZO_SavedVars:NewAccountWide("LeoTrainer_Settings", 1, nil, LeoTrainer.settingsDefaults, worldName)
    else
        LeoTrainer.settings = ZO_SavedVars:NewCharacterIdSettings("LeoTrainer_Settings", 1, nil, LeoTrainer.settingsDefaults, worldName)
    end

    LeoTrainer.data = ZO_SavedVars:NewAccountWide("LeoTrainer_Data", 1, nil, LeoTrainer.dataDefaults, worldName)

    migrateLegacySavedVars(worldName)

    LeoTrainer.settings.loaded = true
    LeoTrainer.data.loaded = true
end

function LeoTrainer.Initialize()
    LeoTrainer.InitSavedVars()

    if LeoTrainer.data.defaultTrainer ~= nil and LeoTrainer.settings.defaultTrainer == "Anyone" then
        LeoTrainer.settings.defaultTrainer = LeoTrainer.data.defaultTrainer
        LeoTrainer.data.defaultTrainer = nil
    end

    if LeoTrainer.data.silent == nil then LeoTrainer.data.silent = false end

    if LeoTrainer.settings.deconstruct.maxQuality[CRAFTING_TYPE_ENCHANTING] == nil then
        LeoTrainer.settings.deconstruct.maxQuality[CRAFTING_TYPE_ENCHANTING] = ITEM_FUNCTIONAL_QUALITY_ARCANE
    end

    LeoTrainer.stage = LEOTRAINER_STAGE_START

    LeoTrainer.craft.Initialize()
    LeoTrainer.research.Initialize()
    LeoTrainer.bank.Initialize()
    LeoTrainer.ui.Initialize()

    SLASH_COMMANDS["/leotrainer"] = function(cmd)
        if cmd == nil or cmd == "" then
            LeoTrainer.ui:ToggleUI()
            return
        end

        if cmd == "debug" then
            if not LeoTrainer.isDebug then
                LeoTrainer.isDebug = true
                LeoTrainer.debug("Debug mode ON")
            else
                LeoTrainer.isDebug = false
                LeoTrainer.log("Debug mode OFF")
            end
            return
        end

        if cmd == "decon" and LeoTrainer.IsInUsableStation() then
            LeoTrainer.deconstruct.DoDeconstruct()
        end
    end
end

function LeoTrainer.log(message, force)
    if force == nil then force = false end
    if LeoTrainer.data.silent == true and not force then return end

    d(LeoTrainer.chatPrefix .. message)
end

function LeoTrainer.debug(message)
    if not LeoTrainer.isDebug then return end
    LeoTrainer.log('[D] ' .. message, true)
end

local function onNewMovementInUIMode(eventCode)
    if not LeoTrainerWindow:IsHidden() then LeoTrainer.ui:CloseUI() end
end

local function onChampionPerksSceneStateChange(oldState, newState)
    if newState == SCENE_SHOWING then
        if not LeoTrainerWindow:IsHidden() then LeoTrainer.ui:CloseUI() end
    end
end

local function finishStartup()
    if initialized then return end
    if not LeoAltholic or not LeoAltholic.ExportCharacters then return end
    initialized = true

    CALLBACK_MANAGER:UnregisterCallback("LeoAltholicInitialized", finishStartup)
    SCENE_MANAGER:RegisterTopLevel(LeoTrainerWindow, false)

    LeoTrainer.Initialize()

    if WritCreater then
        EVENT_MANAGER:UnregisterForEvent(WritCreater.name, EVENT_CRAFTING_STATION_INTERACT)
        EVENT_MANAGER:UnregisterForEvent(WritCreater.name, EVENT_CRAFT_COMPLETED)
    end
    EVENT_MANAGER:UnregisterForEvent("LibLazyCrafting", EVENT_CRAFTING_STATION_INTERACT)

    EVENT_MANAGER:RegisterForEvent(LeoTrainer.name, EVENT_CRAFTING_STATION_INTERACT, function(_, ...) LeoTrainer.stationEnter(...) end)
    EVENT_MANAGER:RegisterForEvent(LeoTrainer.name, EVENT_END_CRAFTING_STATION_INTERACT, LeoTrainer.stationExit)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel) LeoTrainer.settingsMenu:OnSettingsControlsCreated(panel) end)
    EVENT_MANAGER:RegisterForEvent(LeoTrainer.name, EVENT_NEW_MOVEMENT_IN_UI_MODE, onNewMovementInUIMode)
    CHAMPION_PERKS_SCENE:RegisterCallback('StateChange', onChampionPerksSceneStateChange)

    LeoTrainer.LLC = LibLazyCrafting:AddRequestingAddon(LeoTrainer.name, true, LeoTrainer.LLC_Completed)

    LeoTrainer.log("started.", true)
end

function LeoTrainer.OnAddOnLoaded(event, addonName)
    if addonName == LeoTrainer.name then
        EVENT_MANAGER:UnregisterForEvent(LeoTrainer.name, EVENT_ADD_ON_LOADED)
        finishStartup()
    end
end

EVENT_MANAGER:RegisterForEvent(LeoTrainer.name, EVENT_ADD_ON_LOADED, LeoTrainer.OnAddOnLoaded)
CALLBACK_MANAGER:RegisterCallback("LeoAltholicInitialized", finishStartup)