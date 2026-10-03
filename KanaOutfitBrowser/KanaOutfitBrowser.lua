KanaOutfitBrowser = KanaOutfitBrowser or {}
local KOB = KanaOutfitBrowser

local ADDON_NAME = "KanaOutfitBrowser"
local SAVED_VARIABLES_VERSION = 1

KOB.Controller = KOB.Controller or {}
local Controller = KOB.Controller
Controller.__index = Controller

local function firstDiagnostic(diagnostics)
    if type(diagnostics) ~= "table" or #diagnostics == 0 then
        return nil
    end
    return table.concat(diagnostics, "\n")
end

local function makeRuntimeDependencies(accountPrefs, characterPrefs)
    return {
        accountPrefs = accountPrefs,
        characterPrefs = characterPrefs,
        catalogBuild = function()
            return KOB.Catalog.Build()
        end,
        modelNew = function(variants, account, character)
            return KOB.Model.New(variants, account, character)
        end,
        previewNew = function(callback)
            return KOB.Preview.New(callback)
        end,
        uiNew = function(controller)
            return KOB.UI.New(controller)
        end,
        defer = function(callback)
            zo_callLater(callback, 250)
        end,
    }
end

function Controller.New(dependencies)
    local self = setmetatable({}, Controller)
    self.dependencies = dependencies
    self.accountPrefs = dependencies.accountPrefs
    self.characterPrefs = dependencies.characterPrefs
    self.ui = dependencies.ui
    self.model = nil
    self.preview = nil
    self.status = "unavailable"
    self.statusText = ""
    self.diagnostics = {}
    self.open = false
    self.sceneShown = false
    self.previewActive = false
    self.previewOpenAttempted = false
    self.previewUnavailableReason = nil
    self.lastPreviewKey = nil
    self.generation = 0
    self.catalogDirty = false
    self.refreshScheduled = false
    return self
end

function Controller:SetStatus(status, text)
    self.status = status
    self.statusText = text or ""
    if self.ui and self.ui.SetStatus then
        self.ui:SetStatus(self.status, self.statusText)
    end
end

function Controller:BuildModel()
    local variants, diagnostics = self.dependencies.catalogBuild()
    self.diagnostics = diagnostics or {}
    self.accountPrefs.catalogDiagnostics = KOB.Catalog and KOB.Catalog.lastDiagnostics or self.diagnostics
    self.model = self.dependencies.modelNew(variants or {}, self.accountPrefs, self.characterPrefs)
    self.model:Open()
    self.catalogDirty = false

    if not self.model:GetSelected() then
        self:SetStatus("empty", firstDiagnostic(self.diagnostics) or "Нет доступных комплектов брони")
    elseif #self.diagnostics > 0 then
        self:SetStatus("loading", firstDiagnostic(self.diagnostics))
    else
        self:SetStatus("loading", "Подготовка предпросмотра…")
    end
end

function Controller:UpdateCatalogStatus()
    if self.model:GetSelected() and self.previewUnavailableReason then
        self:SetStatus("unavailable", self.previewUnavailableReason)
    elseif not self.model:GetSelected() then
        self:SetStatus("empty", firstDiagnostic(self.diagnostics) or "Нет доступных комплектов брони")
    elseif #self.diagnostics > 0 then
        self:SetStatus("loading", firstDiagnostic(self.diagnostics))
    else
        self:SetStatus("loading", "Подготовка предпросмотра…")
    end
end

function Controller:StartOpen(fromScene)
    if self.open then
        return false
    end

    self.open = true
    self.sceneShown = false
    self.previewActive = false
    self.previewOpenAttempted = false
    self.previewUnavailableReason = nil
    self.lastPreviewKey = nil
    self.refreshScheduled = false
    self.generation = self.generation + 1
    local generation = self.generation

    local catalogOk, catalogError = pcall(self.BuildModel, self)
    if not catalogOk then
        self.open = false
        self.generation = self.generation + 1
        self:SetStatus("error", "Ошибка каталога: " .. tostring(catalogError))
        if d then
            d("KanaOutfitBrowser: " .. self.statusText)
        end
        return false
    end
    self.preview = self.dependencies.previewNew(function(status, text)
        if not self.open or self.generation ~= generation then
            return
        end
        self:SetStatus(status, text)
        if self.ui then
            self.ui:Refresh()
        end
    end)

    if not self.ui then
        self.ui = self.dependencies.uiNew(self)
    end
    if self.ui.BindPreviewControls then
        self.ui:BindPreviewControls()
    end
    self.ui:Refresh()
    if not fromScene then
        self.ui:Show()
    end
    return true
end

function Controller:Open(fromScene)
    local ok, result = pcall(self.StartOpen, self, fromScene)
    if ok then
        return result
    end

    -- Keep the original error and allow a later open to retry. A failed UI
    -- constructor must never leave Toggle treating a missing UI as visible.
    self.open = false
    self.sceneShown = false
    self.previewActive = false
    self.previewOpenAttempted = false
    self.previewUnavailableReason = nil
    self.lastPreviewKey = nil
    self.refreshScheduled = false
    self.generation = self.generation + 1
    if self.preview then
        pcall(self.preview.Close, self.preview)
    end
    self:SetStatus("error", "Ошибка открытия примерочной: " .. tostring(result))
    if d then
        d("KanaOutfitBrowser: " .. self.statusText)
    end
    return false
end

function Controller:OnSceneShown()
    if not self.open or self.sceneShown then
        return
    end
    self.sceneShown = true

    if not self:EnsurePreviewActive() then
        return
    end
    self:ApplySelection(true)
end

function Controller:EnsurePreviewActive()
    if self.previewActive then
        return true
    end
    if not self.open or not self.sceneShown or self.previewOpenAttempted then
        return false
    end
    if not self.model or not self.model:GetSelected() then
        return false
    end

    self.previewOpenAttempted = true
    local success, reason = self.preview:Open()
    if not success then
        self.previewActive = false
        self.previewUnavailableReason = reason or "Предпросмотр сейчас недоступен"
        self:SetStatus("unavailable", self.previewUnavailableReason)
        return false
    end

    self.previewActive = true
    return true
end

function Controller:ApplySelection(force)
    local selected = self.model and self.model:GetSelected()
    local selectedKey = selected and selected.key or nil
    if selected and not self.previewActive then
        self:EnsurePreviewActive()
    end
    if not self.previewActive then
        return false
    end
    if not force and selectedKey == self.lastPreviewKey then
        return false
    end

    self.lastPreviewKey = selectedKey
    self.preview:Select(selected)
    if not selected then
        self:SetStatus("empty", firstDiagnostic(self.diagnostics) or "Нет доступных комплектов брони")
    end
    return true
end

function Controller:OnModelChanged(forcePreview)
    if self.ui then
        self.ui:Refresh()
    end
    return self:ApplySelection(forcePreview == true)
end

function Controller:Select(key)
    if self.model and self.model:Select(key) then
        self:OnModelChanged(false)
        return true
    end
    return false
end

function Controller:SelectRow(row)
    if self.model and self.model:SelectRow(row) then
        self:OnModelChanged(false)
        return true
    end
    return false
end

function Controller:MoveHorizontal(delta)
    if self.model and self.model:MoveHorizontal(delta) then
        self:OnModelChanged(false)
        return true
    end
    return false
end

function Controller:MoveVertical(delta)
    if self.model and self.model:MoveVertical(delta) then
        self:OnModelChanged(false)
        return true
    end
    return false
end

function Controller:ToggleFavorite()
    if self.model and self.model:ToggleFavorite() then
        self:OnModelChanged(false)
        return true
    end
    return false
end

function Controller:ToggleHidden()
    if self.model and self.model:ToggleHidden() then
        self:OnModelChanged(false)
        return true
    end
    return false
end

function Controller:SetShowHidden(showHidden)
    if self.model and self.model:SetShowHidden(showHidden) then
        self:OnModelChanged(false)
        return true
    end
    return false
end

function Controller:RefreshCatalog()
    if not self.open then
        self.catalogDirty = true
        return false
    end
    local catalogOk, variants, diagnostics = pcall(self.dependencies.catalogBuild)
    if not catalogOk then
        self.catalogDirty = false
        self:SetStatus("error", "Ошибка обновления каталога: " .. tostring(variants))
        if self.ui then
            self.ui:Refresh()
        end
        return false
    end
    self.diagnostics = diagnostics or {}
    self.accountPrefs.catalogDiagnostics = KOB.Catalog and KOB.Catalog.lastDiagnostics or self.diagnostics
    self.model:RefreshCatalog(variants or {})
    self.catalogDirty = false
    self:UpdateCatalogStatus()
    self:OnModelChanged(true)
    return true
end

function Controller:QueueCatalogRefresh()
    self.catalogDirty = true
    if not self.open or self.refreshScheduled then
        return
    end

    self.refreshScheduled = true
    local generation = self.generation
    self.dependencies.defer(function()
        if not self.open or self.generation ~= generation then
            return
        end
        self.refreshScheduled = false
        if self.catalogDirty then
            self:RefreshCatalog()
        end
    end)
end

function Controller:Close()
    if not self.open then
        return false
    end

    self.open = false
    self.sceneShown = false
    self.previewActive = false
    self.previewOpenAttempted = false
    self.previewUnavailableReason = nil
    self.catalogDirty = false
    self.refreshScheduled = false
    self.lastPreviewKey = nil
    self.generation = self.generation + 1
    if self.preview then
        self.preview:Close()
    end
    return true
end

function Controller:Toggle()
    if self.open then
        self.ui:Hide()
    else
        self:Open()
    end
end

local function initialize()
    local accountDefaults = {
        schemaVersion = SAVED_VARIABLES_VERSION,
        favorites = {},
        hidden = {},
    }
    local characterDefaults = {
        schemaVersion = SAVED_VARIABLES_VERSION,
        selectedKey = nil,
        preferredWeight = 1,
        showHidden = false,
    }

    local worldProfile = GetWorldName()
    local accountPrefs = ZO_SavedVars:NewAccountWide("KanaOutfitBrowserSavedVariables", SAVED_VARIABLES_VERSION, nil, accountDefaults, worldProfile)
    local characterPrefs = ZO_SavedVars:NewCharacterIdSettings("KanaOutfitBrowserCharacterSavedVariables", SAVED_VARIABLES_VERSION, nil, characterDefaults, worldProfile)
    KOB.controller = Controller.New(makeRuntimeDependencies(accountPrefs, characterPrefs))
    -- Collections needs a registered scene before the user clicks its tab.
    -- Construct controls now; build the catalog and start preview only on entry.
    KOB.controller.ui = KOB.UI.New(KOB.controller)
    local registered, reason = KOB.Collections.Register(KOB.controller.ui.scene)
    if not registered and d then
        d("KanaOutfitBrowser: " .. reason)
    end

    SLASH_COMMANDS["/kanaoutfits"] = function()
        KOB.controller:Toggle()
    end

    if ZO_COLLECTIBLE_DATA_MANAGER and ZO_COLLECTIBLE_DATA_MANAGER.RegisterCallback then
        local function onCatalogChanged()
            KOB.controller:QueueCatalogRefresh()
        end
        ZO_COLLECTIBLE_DATA_MANAGER:RegisterCallback("OnCollectionUpdated", onCatalogChanged)
        ZO_COLLECTIBLE_DATA_MANAGER:RegisterCallback("OnCollectibleUpdated", onCatalogChanged)
    end
end

function KOB.Toggle()
    if KOB.controller then
        KOB.controller:Toggle()
    end
end

if ZO_CreateStringId then
    ZO_CreateStringId("SI_BINDING_NAME_KANA_OUTFIT_BROWSER_TOGGLE", "Открыть примерочную комплектов")
end

if EVENT_MANAGER and EVENT_ADD_ON_LOADED then
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, loadedAddonName)
        if loadedAddonName ~= ADDON_NAME then
            return
        end
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
        initialize()
    end)
end
