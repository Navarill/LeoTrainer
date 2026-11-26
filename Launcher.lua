LeoTrainer.Launcher = ZO_Object:Subclass()

function LeoTrainer.Launcher.OnMouseEnter(control)
    InitializeTooltip(InformationTooltip, control, RIGHT, 0, 0)
    SetTooltipText(InformationTooltip, LeoTrainer.displayName)
end

function LeoTrainer.Launcher.OnMouseClicked(control)
    LeoTrainer.ui.ToggleUI()
end

function LeoTrainer.Launcher:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function LeoTrainer.Launcher:Initialize()
    self.launcher = CreateControlFromVirtual("$(parent)LeoTrainerLauncher", ZO_SmithingTopLevel, "LeoTrainer_Launcher")
    self.launcher:SetAnchor(BOTTOMRIGHT, ZO_SmithingTopLevelCreationPanel, TOPLEFT, 20, -50)
end

function LeoTrainer.Launcher:SetState(state)
    self.launcher:SetState(state)
end

function LeoTrainer.Launcher:GetControl()
    return self.launcher
end

function LeoTrainer.Launcher:SetHidden(bHidden)
    return self.launcher:SetHidden(bHidden)
end