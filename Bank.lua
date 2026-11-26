local Bank = {}
LeoTrainer.bank = Bank

local depositQueue = {}
local isDepositing = false
local EVENT_NAMESPACE = "LeoTrainerBank"

local function FindNextFreeBankSlot()
    local bankSlot = FindFirstEmptySlotInBag(BAG_BANK)
    if bankSlot then
        return BAG_BANK, bankSlot
    end

    if IsESOPlusSubscriber() then
        local subSlot = FindFirstEmptySlotInBag(BAG_SUBSCRIBER_BANK)
        if subSlot then
            return BAG_SUBSCRIBER_BANK, subSlot
        end
    end

    return nil, nil
end

local function StopDepositQueue()
    depositQueue = {}
    isDepositing = false
    EVENT_MANAGER:UnregisterForUpdate(EVENT_NAMESPACE .. "DepositTick")
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
end

local ProcessNextDeposit

local function OnBankSlotUpdated(_, bagId, slotId)
    if bagId ~= BAG_BANK and bagId ~= BAG_SUBSCRIBER_BANK then
        return
    end
    EVENT_MANAGER:UnregisterForUpdate(EVENT_NAMESPACE .. "DepositTick")
    zo_callLater(ProcessNextDeposit, 50)
end

ProcessNextDeposit = function()
    if #depositQueue == 0 then
        StopDepositQueue()
        return
    end

    local destBag, destSlot = FindNextFreeBankSlot()
    if not destBag or not destSlot then
        LeoTrainer.log("Bank is full, stopping auto-deposit.")
        StopDepositQueue()
        return
    end

    local entry = table.remove(depositQueue, 1)
    if not entry then
        return
    end

    local itemId = GetItemId(entry.sourceBag, entry.sourceSlot)
    if itemId == 0 then
        ProcessNextDeposit()
        return
    end

    local itemLink = GetItemLink(entry.sourceBag, entry.sourceSlot, LINK_STYLE_BRACKETS)
    LeoTrainer.log("Depositing " .. itemLink)

    -- Fallback timer in case a move is blocked and never fires a slot update
    EVENT_MANAGER:RegisterForUpdate(EVENT_NAMESPACE .. "DepositTick", 600, ProcessNextDeposit)

    if IsProtectedFunction("RequestMoveItem") then
        CallSecureProtected("RequestMoveItem", entry.sourceBag, entry.sourceSlot, destBag, destSlot, entry.stackCount)
    else
        RequestMoveItem(entry.sourceBag, entry.sourceSlot, destBag, destSlot, entry.stackCount)
    end
end

function Bank.StartDepositQueue(items)
    if not items or #items == 0 then return end

    for _, item in ipairs(items) do
        depositQueue[#depositQueue + 1] = item
    end

    if not isDepositing then
        isDepositing = true
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnBankSlotUpdated)
        ProcessNextDeposit()
    end
end

local function ScanAndQueueBackpack()
    if not LeoTrainer.research then return end

    local items = {}
    local bagSize = GetBagSize(BAG_BACKPACK)

    for slotIndex = 0, bagSize - 1 do
        if GetItemId(BAG_BACKPACK, slotIndex) ~= 0 then
            local itemLink = GetItemLink(BAG_BACKPACK, slotIndex, LINK_STYLE_BRACKETS)
            local craftSkill = LeoTrainer.research.GetResearchData(itemLink)

            if craftSkill and LeoTrainer.research.CanItemBeResearched(BAG_BACKPACK, slotIndex, itemLink, craftSkill) then
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

    if #items > 0 then
        Bank.StartDepositQueue(items)
    end
end

function Bank.OnOpenBank(_, bankBag)
    if bankBag ~= BAG_BANK then
        return
    end

    if not LeoTrainer.settings or not LeoTrainer.settings.bank or not LeoTrainer.settings.bank.autoDeposit then
        return
    end

    -- Brief delay lets PA Banking and FCOIS finish their bank-open hooks first
    zo_callLater(ScanAndQueueBackpack, 300)
end

function Bank.OnCloseBank()
    StopDepositQueue()
end

function Bank.Initialize()
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_OPEN_BANK, Bank.OnOpenBank)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_CLOSE_BANK, Bank.OnCloseBank)
end