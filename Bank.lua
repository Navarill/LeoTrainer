LeoTrainer = LeoTrainer or {}
LeoTrainer.bank = LeoTrainer.bank or {}
local Bank = LeoTrainer.bank

local EVENT_NAMESPACE = "LeoTrainer_BankDeposit"
local MAX_RETRIES = 2
local FALLBACK_TIMEOUT_MS = 750

local depositQueue = {}
local reservedSlots = {}
local currentIndex = 0
local attemptToken = 0
local retryCount = 0
local isDepositing = false

local function MoveItemToBank(sourceBag, sourceSlot, targetBag, targetSlot, stackCount)
    if IsProtectedFunction("RequestMoveItem") then
        return CallSecureProtected("RequestMoveItem", sourceBag, sourceSlot, targetBag, targetSlot, stackCount)
    else
        RequestMoveItem(sourceBag, sourceSlot, targetBag, targetSlot, stackCount)
        return true
    end
end

local function CleanupDeposit()
    isDepositing = false
    depositQueue = {}
    reservedSlots = {}
    currentIndex = 0
    attemptToken = attemptToken + 1
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
end

local function FindNextFreeBankSlot()
    local bagsToCheck = { BAG_BANK }
    if IsESOPlusSubscriber() then
        bagsToCheck[#bagsToCheck + 1] = BAG_SUBSCRIBER_BANK
    end

    for _, targetBag in ipairs(bagsToCheck) do
        local bagSize = GetBagSize(targetBag)
        for slot = 0, bagSize - 1 do
            local key = targetBag .. ":" .. slot
            if not reservedSlots[key] and GetItemId(targetBag, slot) == 0 then
                reservedSlots[key] = true
                return targetBag, slot
            end
        end
    end

    return nil, nil
end

local ProcessNextDeposit

local function OnSlotUpdated(_, bagId, slotIndex)
    if not isDepositing then return end
    local entry = depositQueue[currentIndex]
    if not entry or bagId ~= entry.sourceBag or slotIndex ~= entry.sourceSlot then return end

    if GetItemId(entry.sourceBag, entry.sourceSlot) == 0 then
        LeoTrainer.log("Depositing " .. (entry.itemLink or "item"))
        attemptToken = attemptToken + 1
        retryCount = 0
        currentIndex = currentIndex + 1
        ProcessNextDeposit()
    end
end

ProcessNextDeposit = function()
    local entry = depositQueue[currentIndex]
    if not entry then
        CleanupDeposit()
        return
    end

    if GetItemId(entry.sourceBag, entry.sourceSlot) == 0 then
        retryCount = 0
        currentIndex = currentIndex + 1
        ProcessNextDeposit()
        return
    end

    local targetBag, targetSlot = FindNextFreeBankSlot()
    if not targetBag or not targetSlot then
        CleanupDeposit()
        return
    end

    entry.targetBag = targetBag
    entry.targetSlot = targetSlot
    attemptToken = attemptToken + 1
    local currentToken = attemptToken

    MoveItemToBank(entry.sourceBag, entry.sourceSlot, targetBag, targetSlot, entry.stackCount)

    zo_callLater(function()
        if not isDepositing or attemptToken ~= currentToken then return end

        reservedSlots[targetBag .. ":" .. targetSlot] = nil
        retryCount = retryCount + 1

        if retryCount <= MAX_RETRIES then
            ProcessNextDeposit()
        else
            retryCount = 0
            currentIndex = currentIndex + 1
            ProcessNextDeposit()
        end
    end, FALLBACK_TIMEOUT_MS)
end

function Bank.StartDepositQueue(itemsToDeposit)
    CleanupDeposit()
    if not itemsToDeposit or #itemsToDeposit == 0 then return end

    depositQueue = itemsToDeposit
    currentIndex = 1
    retryCount = 0
    isDepositing = true

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdated)
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)

    ProcessNextDeposit()
end

local function IsTraitNeededByAnyCharacter(craftSkill, line, trait)
    if not LeoTrainer.missingKnowledge then
        if LeoTrainer.research and LeoTrainer.research.Initialize then
            LeoTrainer.research.Initialize()
        else
            return false
        end
    end

    local missing = LeoTrainer.missingKnowledge[craftSkill]
        and LeoTrainer.missingKnowledge[craftSkill][line]
        and LeoTrainer.missingKnowledge[craftSkill][line][trait]

    return missing ~= nil and #missing > 0
end

function Bank.OnOpenBank(_, bankBag)
    if bankBag ~= BAG_BANK then
        return
    end

    if not LeoTrainer.settings or not LeoTrainer.settings.bank or not LeoTrainer.settings.bank.autoDeposit then
        return
    end

    if not LeoTrainer.research then return end

    local items = {}
    local bagSize = GetBagSize(BAG_BACKPACK)

    for slotIndex = 0, bagSize - 1 do
        if GetItemId(BAG_BACKPACK, slotIndex) ~= 0 then
            local itemLink = GetItemLink(BAG_BACKPACK, slotIndex, LINK_STYLE_BRACKETS)
            local craftSkill, line, trait = LeoTrainer.research.GetResearchData(itemLink)

            if craftSkill and LeoTrainer.research.CanItemBeResearched(BAG_BACKPACK, slotIndex, itemLink, craftSkill) then
                if IsTraitNeededByAnyCharacter(craftSkill, line, trait) then
                    local _, stackCount = GetItemInfo(BAG_BACKPACK, slotIndex)
                    items[#items + 1] = {
                        sourceBag = BAG_BACKPACK,
                        sourceSlot = slotIndex,
                        stackCount = stackCount or 1,
                        itemLink = itemLink,
                    }
                end
            end
        end
    end

    if #items > 0 then
        Bank.StartDepositQueue(items)
    end
end

function Bank.OnCloseBank()
    CleanupDeposit()
end

function Bank.Initialize()
    EVENT_MANAGER:RegisterForEvent("LeoTrainer_Bank", EVENT_OPEN_BANK, Bank.OnOpenBank)
    EVENT_MANAGER:RegisterForEvent("LeoTrainer_Bank", EVENT_CLOSE_BANK, Bank.OnCloseBank)
end