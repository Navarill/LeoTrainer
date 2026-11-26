LeoTrainer.ui.hidden = true

local function addLine(tooltip, text, color, alignment)
    if not color then color = ZO_TOOLTIP_DEFAULT_COLOR end
    local r, g, b = color:UnpackRGB()
    tooltip:AddLine(text, "LeoTrainerNormalFont", r, g, b, CENTER, MODIFY_TEXT_TYPE_NONE, alignment, alignment ~= TEXT_ALIGN_LEFT)
end

local function addLineTitle(tooltip, text, color)
    if not color then color = ZO_SELECTED_TEXT end
    local r, g, b = color:UnpackRGB()
    tooltip:AddLine(text, "ZoFontHeader3", r, g, b, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
end

local function addLineSubTitle(tooltip, text, color, alignment)
    if not color then color = ZO_SELECTED_TEXT end
    if not alignment then alignment = TEXT_ALIGN_CENTER end
    local r, g, b = color:UnpackRGB()
    tooltip:AddLine(text, "ZoFontWinH3", r, g, b, CENTER, MODIFY_TEXT_TYPE_NONE, alignment, true)
end

function LeoTrainer.ui:OnWindowMoveStop()
    LeoTrainer.data.position = {
        left = LeoTrainerWindow:GetLeft(),
        top = LeoTrainerWindow:GetTop()
    }
end

function LeoTrainer.ui:OnHide(control, hidden)
    if hidden ~= false then LeoTrainer.ui.HideUI() end
end

function LeoTrainer.ui:OnShow(control, hidden)
    if not hidden then LeoTrainer.ui.ShowUI() end
end

function LeoTrainer.ui:isHidden()
    return LeoTrainer.hidden
end

function LeoTrainer.ui.RestorePosition()
    local position = LeoTrainer.data.position or { left = 200, top = 200 }
    local left = position.left
    local top = position.top

    LeoTrainerWindow:ClearAnchors()
    LeoTrainerWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    LeoTrainerWindow:SetDrawTier(DT_MEDIUM)
end

function LeoTrainer.ui.CloseUI()
    SCENE_MANAGER:HideTopLevel(LeoTrainerWindow)
end

function LeoTrainer.ui.ShowUI()
    LeoTrainer.ui.UpdateUI()
    LeoTrainer.hidden = false
end

function LeoTrainer.ui.HideUI()
    LeoTrainer.hidden = true
end

function LeoTrainer.ui.ToggleUI()
    SCENE_MANAGER:ToggleTopLevel(LeoTrainerWindow)
end

function LeoTrainer.ui:OnMouseEnterTrait(control)
    if not control or not control.materialItemID then return end
    InitializeTooltip(ItemTooltip, control, LEFT, 5, 0)
    ItemTooltip:SetLink(ZO_LinkHandler_CreateLink("", nil, ITEM_LINK_TYPE, control.materialItemID, 30, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    ItemTooltip:SetHidden(false)
end

function LeoTrainer.ui.OnStationEnter(craftSkill)
    LeoTrainer.ui.queueScroll:RefreshData()
    LeoTrainerWindowQueuePanelQueueScrollCraftAll:SetState(BSTATE_NORMAL)
end

function LeoTrainer.ui.OnStationExit(craftSkill)
    LeoTrainerWindowQueuePanelQueueScrollCraftAll:SetState(BSTATE_DISABLED)
    LeoTrainer.ui.queueScroll:RefreshData()
    LeoTrainer.ui.HideUI()
end

function LeoTrainer.ui.Initialize()
    if LibFeedback then
        local _, feedbackWindow = LibFeedback:initializeFeedbackWindow(
            LeoTrainer,
            LeoTrainer.name,
            LeoTrainerWindow,
            "@LeandroSilva",
            { TOPRIGHT, LeoTrainerWindow, TOPRIGHT, -50, 3 },
            { 0, 1000, 10000, "https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=Y9KM4PZU2UZ6A" },
            "If you found a bug, have a request or a suggestion, or simply wish to donate, send a mail."
        )
        LeoTrainer.feedback = feedbackWindow
        if LeoTrainer.feedback then
            LeoTrainer.feedback:SetDrawTier(DT_MEDIUM)
        end
    end

    LeoTrainerWindowTitle:SetText(LeoTrainer.displayName .. " v" .. LeoTrainer.version)

    LeoTrainer.settingsMenu = LeoTrainer.SettingsMenu:New()
    LeoTrainer.settingsMenu:CreatePanel()

    LeoTrainer.launcher = LeoTrainer.Launcher:New()
    LeoTrainer.launcher:SetHidden(false)

    LeoTrainer.ui.RestorePosition()
    LeoTrainer.ui.CreateUI()
    LeoTrainer.ui.UpdateUI()
end

local function copy(obj)
    if type(obj) ~= 'table' then return obj end
    return ZO_ShallowTableCopy(obj)
end

LeoTrainer.QueueList = ZO_SortFilterList:Subclass()
function LeoTrainer.QueueList:New(control)
    local object = ZO_Object.New(self)
    ZO_SortFilterList.InitializeSortFilterList(object, control)

    local sorterKeys =
    {
        ["trainer"] = {},
        ["trainee"] = { tiebreaker = "trainer" },
        ["researchName"] = { tiebreaker = "trainee" },
        ["itemLink"] = { tiebreaker = "researchName" },
    }

    object.masterList = {}
    object.currentSortKey = "trainee"
    object.currentSortOrder = ZO_SORT_ORDER_UP
    ZO_ScrollList_AddDataType(object.list, 1, "LeoTrainerQueueListTemplate", 32, function(ctrl, data) object:SetupEntry(ctrl, data) end)

    object.sortFunction = function(listEntry1, listEntry2)
        return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, object.currentSortKey, sorterKeys, object.currentSortOrder)
    end

    return object
end

function LeoTrainer.QueueList:SetupEntry(control, data)
    control.data = data

    control.trainer = GetControl(control, "Trainer")
    control.trainer:SetText(LeoTrainer.GetCharNameById(data.trainer) or "Anyone")
    control.trainer.knownList = data.knownList
    if data.knownList ~= nil and #data.knownList > 1 then
        control.trainer:SetHandler('OnMouseEnter', function(self)
            InitializeTooltip(InformationTooltip, self, LEFT, 5, 0)
            addLineTitle(InformationTooltip, "Trainers", ZO_TOOLTIP_DEFAULT_COLOR)
            ZO_Tooltip_AddDivider(InformationTooltip)

            for _, knowId in pairs(data.knownList) do
                addLine(InformationTooltip, LeoTrainer.GetCharNameById(knowId), LeoTrainer.const.colors.green)
            end

            addLine(InformationTooltip, zo_iconTextFormat("esoui/art/icons/icon_lmb.dds", 26, 26, "Change Trainer"))
            InformationTooltip:SetHidden(false)
        end)
        control.trainer:SetHandler('OnMouseUp', function(ctrl, button, upInside)
            if not upInside or (button ~= MOUSE_BUTTON_INDEX_RIGHT and button ~= MOUSE_BUTTON_INDEX_LEFT) then return end
            local newTrainer
            for trainerIndex, trainerId in pairs(data.knownList) do
                if trainerId == data.trainer then
                    if trainerIndex < #data.knownList then
                        newTrainer = data.knownList[trainerIndex + 1]
                    else
                        newTrainer = data.knownList[1]
                    end
                    break
                end
            end
            if newTrainer and LeoTrainer.data.craftQueue[data.queueIndex] then
                LeoTrainer.data.craftQueue[data.queueIndex].trainer = newTrainer
                LeoTrainer.ui.queueScroll:RefreshData()
            end
        end)
    else
        control.trainer:SetHandler('OnMouseEnter', nil)
        control.trainer:SetHandler('OnMouseUp', nil)
    end

    control.trainee = GetControl(control, "Trainee")
    control.trainee:SetText(LeoTrainer.GetCharNameById(data.trainee) or "Anyone")

    control.researchName = GetControl(control, "Trait")
    control.researchName:SetText(data.researchName)

    control.item = GetControl(control, "Item")
    control.item:SetText(data.itemLink)
    control.item:SetHandler('OnMouseUp', function(ctrl, button, upInside)
        if upInside == false then return end
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            LeoTrainer.RemoveFromQueue(data.queueIndex)
        end
    end)

    ZO_SortFilterList.SetupRow(self, control, data)
end

function LeoTrainer.QueueList:BuildMasterList()
    self.masterList = {}
    local list = LeoTrainer.GetCraftQueue()
    if list then
        for k, v in ipairs(list) do
            local data = copy(v)
            data.queueIndex = k
            table.insert(self.masterList, data)
        end
    end
end

function LeoTrainer.QueueList:SortScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    table.sort(scrollData, self.sortFunction)
end

function LeoTrainer.QueueList:FilterScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    ZO_ClearNumericallyIndexedTable(scrollData)

    local station = GetCraftingInteractionType()
    local currentCharId = GetCurrentCharacterId()

    for i = 1, #self.masterList do
        local data = self.masterList[i]
        local canShow = true
        if station > 0 and data.craft ~= station then
            canShow = false
        end
        if station > 0 and data.trainer ~= "Anyone" and data.trainer ~= currentCharId then
            canShow = false
        end

        if data.crafted then canShow = false end

        if canShow then
            table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, data))
        end
    end
end

local function getNumOngoingResearches(research, craft)
    if not research or not research.doing or not research.doing[craft] then return 0 end
    local num = 0
    for _, researching in pairs(research.doing[craft]) do
        if researching.doneAt and researching.doneAt - GetTimeStamp() > 0 then
            num = num + 1
        end
    end
    return num
end

local function getFirstUnknownTraitCanBeTrained(craft, line, unknownTraits, trainerId)
    for _, trait in pairs(unknownTraits) do
        local knownList = LeoTrainer.knowledge[craft][line][trait]
        if trainerId == nil and #knownList > 0 then
            return trait, knownList
        elseif trainerId ~= nil then
            for _, charId in pairs(knownList) do
                if charId == trainerId then
                    return trait, knownList
                end
            end
        end
    end
    return nil, {}
end

local function selectTrainerForKnownList(knownList, preferredTrainerId)
    if preferredTrainerId and preferredTrainerId ~= "Anyone" then
        for _, knownId in pairs(knownList) do
            if knownId == preferredTrainerId then
                return knownId
            end
        end
    end
    return knownList[1] or "Anyone"
end

function LeoTrainer.ui.CreateUI()
    local traitIcons = {}
    for traitItemIndex = 1, GetNumSmithingTraitItems() do
        local traitType, _, icon = GetSmithingTraitItemInfo(traitItemIndex)
        if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE then
            traitIcons[traitType] = icon
        end
    end

    for _, craft in pairs(LeoAltholic.craftResearch) do
        local panel = WINDOW_MANAGER:GetControlByName('LeoTrainerWindowCraft' .. craft .. "Panel")
        if craft == CRAFTING_TYPE_JEWELRYCRAFTING then
            panel = WINDOW_MANAGER:GetControlByName('LeoTrainerWindowCraft6PanelCraft7Panel')
        end
        for line = 1, GetNumSmithingResearchLines(craft) do
            local lineName, lineIcon, numTraits = GetSmithingResearchLineInfo(craft, line)
            local labelLine = panel:GetNamedChild('Line' .. line)
            labelLine.tooltip = lineName
            labelLine:SetText("|t30:30:" .. lineIcon .. "|t")
            for trait = 1, numTraits do
                local traitType = GetSmithingResearchLineTraitInfo(craft, line, trait)
                local traitName = GetString('SI_ITEMTRAITTYPE', traitType)
                local i = trait
                local posY = 14 + (trait * 28)
                if craft == CRAFTING_TYPE_BLACKSMITHING and line <= 7 then
                    i = i + 10
                elseif craft == CRAFTING_TYPE_WOODWORKING and line <= 5 then
                    i = i + 10
                end
                local labelTrait = panel:GetNamedChild('Trait' .. i)
                labelTrait:SetText(traitName .. " |t28:28:" .. (traitIcons[traitType] or "") .. "|t")
                labelTrait.materialItemID = LeoTrainer.const.traitMaterials[traitType]

                local t = WINDOW_MANAGER:CreateControl('LeoTrainerWindowCraft' .. craft .. 'Line' .. line .. 'Trait' .. trait .. 'Texture', labelLine, CT_TEXTURE)
                t:SetAnchor(CENTER, labelLine, CENTER, 0, posY)
                t:SetDimensions(25, 25)
                t:SetMouseEnabled(true)
                t:SetHandler('OnMouseExit', function(self)
                    ClearTooltip(InformationTooltip)
                    InformationTooltip:SetHidden(true)
                end)
            end

            local label = WINDOW_MANAGER:CreateControl('LeoTrainerWindowCraft' .. craft .. 'Line' .. line .. 'Count', labelLine, CT_LABEL)
            label:SetAnchor(CENTER, labelLine, CENTER, 8, 300)
            label:SetDimensions(25, 25)
            label:SetFont("LeoTrainerLargeFont")
        end
    end
    LeoTrainer.ui.queueScroll = LeoTrainer.QueueList:New(LeoTrainerWindowQueuePanelQueueScroll)
    LeoTrainer.ui.queueScroll:RefreshData()

    local LeoTrainerCharDropdown = CreateControlFromVirtual('LeoTrainerCharDropdown', LeoTrainerWindow, 'LeoTrainerCharDropdown')
    LeoTrainerCharDropdown:SetDimensions(200, 35)
    LeoTrainerCharDropdown:SetAnchor(RIGHT, LeoTrainerWindowBlacksmithingButton, LEFT, -50, 4)
    LeoTrainerCharDropdown.m_comboBox:SetSortsItems(false)
    local charDropdown = ZO_ComboBox_ObjectFromContainer(LeoTrainerCharDropdown)
    charDropdown:ClearItems()

    local currentCharId = GetCurrentCharacterId()
    local defaultItem
    for _, char in pairs(LeoAltholic.ExportCharacters()) do
        local charId = LeoTrainer.GetCharacterId(char)
        local entry = charDropdown:CreateItemEntry(char.bio.name, function()
            LeoTrainer.ui.UpdateUI(charId)
        end)
        if charId == currentCharId then
            defaultItem = entry
        end
        charDropdown:AddItem(entry)
    end
    if defaultItem ~= nil then
        charDropdown:SelectItem(defaultItem)
    end
end

function LeoTrainer.ui.UpdateUI(charId)
    if charId == nil then
        charId = GetCurrentCharacterId()
    end

    LeoTrainer.research.Initialize()
    local items = LeoTrainer.research.ScanBagsUnfiltered()

    for _, craft in pairs(LeoAltholic.craftResearch) do
        local panel = WINDOW_MANAGER:GetControlByName('LeoTrainerWindowCraft' .. craft .. "Panel")
        if craft == CRAFTING_TYPE_JEWELRYCRAFTING then
            panel = WINDOW_MANAGER:GetControlByName('LeoTrainerWindowCraft6PanelCraft7Panel')
        end
        for line = 1, GetNumSmithingResearchLines(craft) do
            local lineName, _, numTraits = GetSmithingResearchLineInfo(craft, line)
            local knownTraits = 0
            for trait = 1, numTraits do
                local traitType = GetSmithingResearchLineTraitInfo(craft, line, trait)
                local traitName = GetString('SI_ITEMTRAITTYPE', traitType)

                local t = WINDOW_MANAGER:GetControlByName('LeoTrainerWindowCraft' .. craft .. 'Line' .. line .. 'Trait' .. trait .. 'Texture')

                local isKnown = #LeoTrainer.knowledge[craft][line][trait] > 0
                local isUnknown = #LeoTrainer.knowledge[craft][line][trait] == 0
                local allKnown = #LeoTrainer.missingKnowledge[craft][line][trait] == 0

                local hasItem = false
                for _, itemData in pairs(items) do
                    if itemData.craftSkill == craft and itemData.line == line and itemData.trait == trait then
                        hasItem = true
                        break
                    end
                end

                local myself = false
                for _, knowId in pairs(LeoTrainer.knowledge[craft][line][trait]) do
                    if knowId == charId then
                        myself = true
                        break
                    end
                end
                local icon
                local color
                if myself == true then
                    icon = 'esoui/art/buttons/accept_up.dds'
                    knownTraits = knownTraits + 1
                    if allKnown then
                        color = { 0, 1, 0, 1 }
                    else
                        color = { 1, 1, 0, 1 }
                    end
                else
                    icon = 'esoui/art/buttons/decline_up.dds'
                    if isUnknown then
                        color = { 1, 0, 0, 1 }
                    else
                        color = { 1, 0.7, 0, 1 }
                    end
                end
                if hasItem and not allKnown then
                    icon = 'esoui/art/buttons/pointsplus_up.dds'
                end

                t:SetColor(unpack(color))
                t:SetTexture(icon)
                t:SetHandler('OnMouseEnter', function(self)
                    InitializeTooltip(InformationTooltip, self, LEFT, 5, 0)
                    addLineTitle(InformationTooltip, lineName .. " - " .. traitName, ZO_TOOLTIP_DEFAULT_COLOR)
                    ZO_Tooltip_AddDivider(InformationTooltip)

                    addLineSubTitle(InformationTooltip, "Trainers", ZO_TOOLTIP_DEFAULT_COLOR, TEXT_ALIGN_LEFT)
                    if allKnown then
                        addLine(InformationTooltip, "All", LeoTrainer.const.colors.green)
                    elseif isKnown then
                        for _, knowId in pairs(LeoTrainer.knowledge[craft][line][trait]) do
                            addLine(InformationTooltip, LeoTrainer.GetCharNameById(knowId), LeoTrainer.const.colors.green)
                        end
                    else
                        addLine(InformationTooltip, "None", LeoTrainer.const.colors.red)
                    end

                    addLineSubTitle(InformationTooltip, "Trainees", ZO_TOOLTIP_DEFAULT_COLOR, TEXT_ALIGN_LEFT)
                    if allKnown then
                        addLine(InformationTooltip, "None", LeoTrainer.const.colors.green)
                    elseif isUnknown then
                        addLine(InformationTooltip, "All", LeoTrainer.const.colors.red)
                    else
                        for _, missingId in pairs(LeoTrainer.missingKnowledge[craft][line][trait]) do
                            addLine(InformationTooltip, LeoTrainer.GetCharNameById(missingId), LeoTrainer.const.colors.red)
                        end
                    end
                    local inBag = ""
                    local inBank = ""
                    for _, itemData in pairs(items) do
                        if itemData.craftSkill == craft and itemData.line == line and itemData.trait == trait then
                            if itemData.bagId == BAG_BANK or itemData.bagId == BAG_SUBSCRIBER_BANK then
                                inBank = inBank .. itemData.itemLink .. " "
                            elseif itemData.bagId == BAG_BACKPACK then
                                inBag = inBag .. itemData.itemLink .. " "
                            end
                        end
                    end
                    if inBag ~= "" or inBank ~= "" then
                        addLineSubTitle(InformationTooltip, "Researchable Items", ZO_TOOLTIP_DEFAULT_COLOR, TEXT_ALIGN_LEFT)
                    end
                    if inBag ~= "" then
                        addLine(InformationTooltip, GetString(SI_INVENTORY_MENU_INVENTORY) .. ": " .. inBag, LeoTrainer.const.colors.green)
                    end
                    if inBank ~= "" then
                        addLine(InformationTooltip, GetString(SI_CURRENCYLOCATION1) .. ": " .. inBank, LeoTrainer.const.colors.green)
                    end
                    if not allKnown and not isUnknown then
                        addLine(InformationTooltip, zo_iconTextFormat("esoui/art/icons/icon_lmb.dds", 26, 26, "Queue 1"))
                        addLine(InformationTooltip, zo_iconTextFormat("esoui/art/icons/icon_rmb.dds", 26, 26, "Queue All"))
                    end
                    InformationTooltip:SetHidden(false)
                end)
                if isKnown then
                    t:SetHandler('OnMouseUp', function(control, button, upInside)
                        if not upInside or (button ~= MOUSE_BUTTON_INDEX_RIGHT and button ~= MOUSE_BUTTON_INDEX_LEFT) then return end
                        if #LeoTrainer.missingKnowledge[craft][line][trait] > 0 then
                            local styleId = LeoTrainer.craft.MaxStyle(line)
                            if trait == 9 and LeoTrainer.data.trainNirnhoned == false then
                                LeoTrainer.log("Nirnhoned training is disabled in settings.")
                                return
                            end

                            local _, knownList = getFirstUnknownTraitCanBeTrained(craft, line, { trait }, nil)
                            local trainerId = selectTrainerForKnownList(knownList, LeoTrainer.settings.defaultTrainer)

                            for _, missingCharId in pairs(LeoTrainer.missingKnowledge[craft][line][trait]) do
                                local traineeId = "Anyone"
                                if button == MOUSE_BUTTON_INDEX_RIGHT then
                                    traineeId = missingCharId
                                end
                                LeoTrainer.AddToQueue({
                                    trainer = trainerId,
                                    trainee = traineeId,
                                    craft = craft,
                                    line = line,
                                    trait = trait,
                                    patternIndex = -1,
                                    materialIndex = 1,
                                    materialQuantity = -1,
                                    itemStyleId = styleId,
                                    traitIndex = traitType,
                                    useUniversalStyleItem = false,
                                    researchName = lineName .. " " .. traitName,
                                    itemLink = LeoTrainer.const.craftItems[craft][line][trait],
                                    knownList = knownList,
                                    crafted = false
                                })
                                if button == MOUSE_BUTTON_INDEX_LEFT then
                                    break
                                end
                            end
                            LeoTrainer.ui.queueScroll:RefreshData()
                        end
                    end)
                else
                    t:SetHandler('OnMouseUp', nil)
                end
            end
            local labelCount = WINDOW_MANAGER:GetControlByName('LeoTrainerWindowCraft' .. craft .. 'Line' .. line .. 'Count')
            labelCount:SetText(knownTraits)
            if knownTraits < 2 then
                labelCount:SetColor(1, 0, 0, 1)
            elseif knownTraits < 4 then
                labelCount:SetColor(1, 0.7, 0, 1)
            elseif knownTraits < 6 then
                labelCount:SetColor(1, 1, 0, 1)
            elseif knownTraits == 9 then
                labelCount:SetColor(0, 1, 0, 1)
            else
                labelCount:SetColor(1, 1, 1, 1)
            end
        end
    end
    LeoTrainer.ui.queueScroll:RefreshData()
end

function LeoTrainer.GetCraftQueue()
    return LeoTrainer.data.craftQueue or {}
end

function LeoTrainer.ClearQueue()
    LeoTrainer.data.craftQueue = {}
    LeoTrainer.LLC:cancelItem()
    LeoTrainer.ui.queueScroll:RefreshData()
end

function LeoTrainer.IsQueuedForTrainee(traineeId, craft, line, trait)
    for _, item in pairs(LeoTrainer.GetCraftQueue()) do
        if not item.crafted and item.trainee == traineeId and item.craft == craft and item.line == line and item.trait == trait then
            return true
        end
    end
    return false
end

function LeoTrainer.AddToQueue(data)
    if data.trainee ~= "Anyone" and LeoTrainer.IsQueuedForTrainee(data.trainee, data.craft, data.line, data.trait) then
        return false
    end
    table.insert(LeoTrainer.GetCraftQueue(), data)
    return true
end

function LeoTrainer.RemoveFromQueue(pos)
    local data = LeoTrainer.GetCraftQueue()[pos]
    table.remove(LeoTrainer.GetCraftQueue(), pos)
    LeoTrainer.ui.queueScroll:RefreshData()
    return data
end

function LeoTrainer.FillMySlots()
    LeoTrainer.FillSlots(nil, GetCurrentCharacterId())
end

function LeoTrainer.FillKnownSlots()
    LeoTrainer.FillSlots(GetCurrentCharacterId(), nil)
end

function LeoTrainer.FillSlots(trainerId, traineeId)
    LeoTrainer.research.Initialize()
    local lineList = LeoTrainer.GetPriorityLineList()
    local charList = LeoAltholic.ExportCharacters()

    local allItems = LeoTrainer.research.ScanBagsUnfiltered()
    local items = {}
    for _, itemData in pairs(allItems) do
        if itemData.bagId == BAG_BANK or itemData.bagId == BAG_SUBSCRIBER_BANK then
            table.insert(items, itemData)
        end
    end

    for _, char in pairs(charList) do
        local charId = LeoTrainer.GetCharacterId(char)
        local isValidTrainee = (traineeId == nil or traineeId == charId) and (trainerId == nil or trainerId ~= charId)
        if isValidTrainee then
            for _, craft in pairs(LeoAltholic.craftResearch) do
                if LeoTrainer.isTrackingSkill(charId, craft) and LeoTrainer.canFillSlotWithSkill(charId, craft) then
                    local styleId
                    local maxSlots = (char.research and char.research.done and char.research.done[craft] and char.research.done[craft].max) or 0
                    local openSlots = maxSlots - getNumOngoingResearches(char.research, craft)

                    for _ = 1, openSlots do
                        for j, lineData in ipairs(lineList[charId][craft]) do
                            if not lineData.added and not lineData.isResearching then
                                local trait, knownList = getFirstUnknownTraitCanBeTrained(craft, lineData.line, lineData.unknownTraits, trainerId)
                                if trait ~= nil and (trait ~= 9 or LeoTrainer.data.trainNirnhoned == true) then
                                    local hasItem = false
                                    for itemIndex, itemData in pairs(items) do
                                        if itemData.selected == false and itemData.craftSkill == craft and itemData.line == lineData.line and itemData.trait == trait then
                                            LeoTrainer.debug("Found existing item for research " .. itemData.itemLink)
                                            hasItem = true
                                            items[itemIndex].selected = true
                                            break
                                        end
                                    end

                                    if not hasItem and not LeoTrainer.IsQueuedForTrainee(charId, craft, lineData.line, trait) then
                                        local traitType = GetSmithingResearchLineTraitInfo(craft, lineData.line, trait)
                                        local traitName = GetString('SI_ITEMTRAITTYPE', traitType)
                                        if not styleId then styleId = LeoTrainer.craft.MaxStyle(lineData.line) end
                                        local selectedTrainerId = trainerId or selectTrainerForKnownList(knownList, LeoTrainer.settings.defaultTrainer)

                                        local data = {
                                            trainer = selectedTrainerId,
                                            trainee = charId,
                                            craft = craft,
                                            line = lineData.line,
                                            trait = trait,
                                            patternIndex = -1,
                                            materialIndex = 1,
                                            materialQuantity = -1,
                                            itemStyleId = styleId,
                                            traitIndex = traitType,
                                            useUniversalStyleItem = false,
                                            researchName = lineData.lineName .. " " .. traitName,
                                            itemLink = LeoTrainer.const.craftItems[craft][lineData.line][trait],
                                            knownList = knownList,
                                            crafted = false
                                        }
                                        LeoTrainer.AddToQueue(data)
                                    end
                                    lineList[charId][craft][j].added = true
                                    break
                                end
                            end
                        end
                    end
                    LeoTrainer.ui.queueScroll:RefreshData()
                end
            end
        end
    end
end