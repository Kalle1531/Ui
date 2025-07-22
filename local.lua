local Library = {}
Library.__index = Library

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

-- Local player
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Default theme
local DefaultTheme = {
    PrimaryColor = Color3.fromRGB(0, 162, 255),
    SecondaryColor = Color3.fromRGB(45, 45, 45),
    BackgroundColor = Color3.fromRGB(30, 30, 30),
    TextColor = Color3.fromRGB(255, 255, 255),
    AccentColor = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.Gotham,
    CornerRadius = 6,
    BorderSize = 1
}

local KeySystem = {
    Enabled = false,
    ValidKeys = {},
    AdminKeys = {},
    AuthenticatedUsers = {},
    LockedTabs = {},
    LockedFeatures = {},
    AuthenticationRequired = true,
    MaxAttempts = 3,
    CurrentAttempts = 0,
    OnAuthSuccess = nil,
    OnAuthFailed = nil,
    OnMaxAttemptsReached = nil
}

-- Key System Functions
function KeySystem:Initialize(config)
    if not config then return end
    
    self.Enabled = config.Enabled or false
    self.ValidKeys = config.ValidKeys or {}
    self.AdminKeys = config.AdminKeys or {}
    self.MaxAttempts = config.MaxAttempts or 3
    self.AuthenticationRequired = config.AuthenticationRequired ~= false
    
    -- Callbacks
    self.OnAuthSuccess = config.OnAuthSuccess
    self.OnAuthFailed = config.OnAuthFailed
    self.OnMaxAttemptsReached = config.OnMaxAttemptsReached
    
    -- Reset attempts
    self.CurrentAttempts = 0
    
    print("[KeySystem] Initialized with", #self.ValidKeys, "valid keys and", #self.AdminKeys, "admin keys")
end

function KeySystem:AddValidKey(key)
    if not key or key == "" then return false end
    
    for _, existingKey in pairs(self.ValidKeys) do
        if existingKey == key then
            return false
        end
    end
    
    table.insert(self.ValidKeys, key)
    print("[KeySystem] Added valid key:", key)
    return true
end

function KeySystem:RemoveValidKey(key)
    for i, existingKey in pairs(self.ValidKeys) do
        if existingKey == key then
            table.remove(self.ValidKeys, i)
            print("[KeySystem] Removed valid key:", key)
            return true
        end
    end
    return false
end

function KeySystem:AddAdminKey(key)
    if not key or key == "" then return false end
    
    for _, existingKey in pairs(self.AdminKeys) do
        if existingKey == key then
            return false
        end
    end
    
    table.insert(self.AdminKeys, key)
    print("[KeySystem] Added admin key:", key)
    return true
end

function KeySystem:ValidateKey(key)
    if not self.Enabled then return true end
    
    for _, validKey in pairs(self.ValidKeys) do
        if validKey == key then
            return true, "valid"
        end
    end
    
    for _, adminKey in pairs(self.AdminKeys) do
        if adminKey == key then
            return true, "admin"
        end
    end
    
    return false, "invalid"
end

function KeySystem:AuthenticateUser(key)
    local isValid, keyType = self:ValidateKey(key)
    
    if isValid then
        self.AuthenticatedUsers[LocalPlayer.UserId] = {
            keyType = keyType,
            timestamp = tick(),
            key = key
        }
        
        self.CurrentAttempts = 0
        
        if self.OnAuthSuccess then
            self.OnAuthSuccess(keyType)
        end
        
        return true, keyType
    else
        self.CurrentAttempts = self.CurrentAttempts + 1
        
        if self.OnAuthFailed then
            self.OnAuthFailed(self.CurrentAttempts, self.MaxAttempts)
        end
        
        if self.CurrentAttempts >= self.MaxAttempts then
            if self.OnMaxAttemptsReached then
                self.OnMaxAttemptsReached()
            end
        end
        
        return false, "invalid"
    end
end

function KeySystem:IsUserAuthenticated()
    if not self.Enabled then return true end
    return self.AuthenticatedUsers[LocalPlayer.UserId] ~= nil
end

function KeySystem:IsUserAdmin()
    if not self.Enabled then return false end
    local userAuth = self.AuthenticatedUsers[LocalPlayer.UserId]
    return userAuth and userAuth.keyType == "admin"
end

function KeySystem:LockTab(tabName)
    self.LockedTabs[tabName] = true
    print("[KeySystem] Locked tab:", tabName)
end

function KeySystem:UnlockTab(tabName)
    self.LockedTabs[tabName] = nil
    print("[KeySystem] Unlocked tab:", tabName)
end

function KeySystem:IsTabLocked(tabName)
    if not self.Enabled then return false end
    return self.LockedTabs[tabName] == true
end

function KeySystem:LockFeature(featureName)
    self.LockedFeatures[featureName] = true
    print("[KeySystem] Locked feature:", featureName)
end

function KeySystem:UnlockFeature(featureName)
    self.LockedFeatures[featureName] = nil
    print("[KeySystem] Unlocked feature:", featureName)
end

function KeySystem:IsFeatureLocked(featureName)
    if not self.Enabled then return false end
    return self.LockedFeatures[featureName] == true
end

function KeySystem:GetUserInfo()
    if not self.Enabled then return nil end
    return self.AuthenticatedUsers[LocalPlayer.UserId]
end

function KeySystem:Logout()
    self.AuthenticatedUsers[LocalPlayer.UserId] = nil
    self.CurrentAttempts = 0
    print("[KeySystem] User logged out")
end

function KeySystem:GetStats()
    return {
        Enabled = self.Enabled,
        ValidKeysCount = #self.ValidKeys,
        AdminKeysCount = #self.AdminKeys,
        AuthenticatedUsers = self.AuthenticatedUsers,
        LockedTabs = self.LockedTabs,
        LockedFeatures = self.LockedFeatures,
        CurrentAttempts = self.CurrentAttempts,
        MaxAttempts = self.MaxAttempts
    }
end

local AuthUI = {
    CurrentAuthGui = nil,
    IsAuthenticating = false
}

function AuthUI:CreateAuthenticationPrompt(onSuccess, onFailed, onMaxAttempts)
    if self.IsAuthenticating then return end
    self.IsAuthenticating = true
    
    local authGui = Instance.new("ScreenGui")
    authGui.Name = "AuthenticationPrompt"
    authGui.ResetOnSpawn = false
    authGui.DisplayOrder = 1000
    authGui.Parent = PlayerGui
    
    self.CurrentAuthGui = authGui
    
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.Parent = authGui
    
    local authFrame = Instance.new("Frame")
    authFrame.Size = UDim2.new(0, 400, 0, 250)
    authFrame.Position = UDim2.new(0.5, -200, 0.5, -125)
    authFrame.BackgroundColor3 = DefaultTheme.BackgroundColor
    authFrame.BorderSizePixel = 0
    authFrame.Parent = authGui
    
    CreateCorner(DefaultTheme.CornerRadius):Clone().Parent = authFrame
    CreateStroke(DefaultTheme.PrimaryColor, 2):Clone().Parent = authFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 40)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "🔐 Authentication Required"
    title.TextColor3 = DefaultTheme.TextColor
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = authFrame

    local description = Instance.new("TextLabel")
    description.Size = UDim2.new(1, -20, 0, 30)
    description.Position = UDim2.new(0, 10, 0, 55)
    description.BackgroundTransparency = 1
    description.Text = "Please enter your access key to continue"
    description.TextColor3 = Color3.fromRGB(200, 200, 200)
    description.Font = DefaultTheme.Font
    description.TextSize = 14
    description.TextXAlignment = Enum.TextXAlignment.Center
    description.Parent = authFrame

    local keyInput = Instance.new("TextBox")
    keyInput.Size = UDim2.new(1, -40, 0, 35)
    keyInput.Position = UDim2.new(0, 20, 0, 100)
    keyInput.BackgroundColor3 = DefaultTheme.SecondaryColor
    keyInput.BorderSizePixel = 0
    keyInput.Text = ""
    keyInput.PlaceholderText = "Enter your key here..."
    keyInput.TextColor3 = DefaultTheme.TextColor
    keyInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    keyInput.Font = DefaultTheme.Font
    keyInput.TextSize = 14
    keyInput.ClearTextOnFocus = false
    keyInput.Parent = authFrame
    
    CreateCorner(DefaultTheme.CornerRadius):Clone().Parent = keyInput

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -20, 0, 20)
    statusLabel.Position = UDim2.new(0, 10, 0, 145)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = ""
    statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    statusLabel.Font = DefaultTheme.Font
    statusLabel.TextSize = 12
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.Parent = authFrame

    local buttonsFrame = Instance.new("Frame")
    buttonsFrame.Size = UDim2.new(1, -20, 0, 35)
    buttonsFrame.Position = UDim2.new(0, 10, 1, -50)
    buttonsFrame.BackgroundTransparency = 1
    buttonsFrame.Parent = authFrame
    
    -- Submit button
    local submitButton = Instance.new("TextButton")
    submitButton.Size = UDim2.new(0.48, 0, 1, 0)
    submitButton.Position = UDim2.new(0, 0, 0, 0)
    submitButton.BackgroundColor3 = DefaultTheme.PrimaryColor
    submitButton.BorderSizePixel = 0
    submitButton.Text = "Submit"
    submitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    submitButton.Font = Enum.Font.GothamBold
    submitButton.TextSize = 14
    submitButton.Parent = buttonsFrame
    
    CreateCorner(DefaultTheme.CornerRadius):Clone().Parent = submitButton
    
    -- Cancel button
    local cancelButton = Instance.new("TextButton")
    cancelButton.Size = UDim2.new(0.48, 0, 1, 0)
    cancelButton.Position = UDim2.new(0.52, 0, 0, 0)
    cancelButton.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
    cancelButton.BorderSizePixel = 0
    cancelButton.Text = "Cancel"
    cancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    cancelButton.Font = Enum.Font.GothamBold
    cancelButton.TextSize = 14
    cancelButton.Parent = buttonsFrame
    
    CreateCorner(DefaultTheme.CornerRadius):Clone().Parent = cancelButton
    
    -- Attempts counter
    local attemptsLabel = Instance.new("TextLabel")
    attemptsLabel.Size = UDim2.new(1, -20, 0, 15)
    attemptsLabel.Position = UDim2.new(0, 10, 1, -20)
    attemptsLabel.BackgroundTransparency = 1
    attemptsLabel.Text = "Attempts: " .. KeySystem.CurrentAttempts .. "/" .. KeySystem.MaxAttempts
    attemptsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    attemptsLabel.Font = DefaultTheme.Font
    attemptsLabel.TextSize = 10
    attemptsLabel.TextXAlignment = Enum.TextXAlignment.Center
    attemptsLabel.Parent = authFrame
    
    -- Animation
    authFrame.Position = UDim2.new(0.5, -200, 0.5, -200)
    TweenObject(authFrame, {Position = UDim2.new(0.5, -200, 0.5, -125)}, 0.5, Enum.EasingStyle.Back)
    
    -- Focus on input
    keyInput:CaptureFocus()
    
    -- Submit function
    local function submitKey()
        local key = keyInput.Text
        if key == "" then
            statusLabel.Text = "Please enter a key"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        local success, keyType = KeySystem:AuthenticateUser(key)
        
        if success then
            statusLabel.Text = "✓ Authentication successful!"
            statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            
            if onSuccess then onSuccess(keyType) end
            
            -- Close with animation
            TweenObject(authFrame, {Position = UDim2.new(0.5, -200, 0.5, -200)}, 0.3)
            wait(0.5)
            self:CloseAuthenticationPrompt()
        else
            statusLabel.Text = "✗ Invalid key! (" .. KeySystem.CurrentAttempts .. "/" .. KeySystem.MaxAttempts .. ")"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            attemptsLabel.Text = "Attempts: " .. KeySystem.CurrentAttempts .. "/" .. KeySystem.MaxAttempts
            
            -- Shake animation
            TweenObject(authFrame, {Position = UDim2.new(0.5, -190, 0.5, -125)}, 0.1)
            wait(0.1)
            TweenObject(authFrame, {Position = UDim2.new(0.5, -210, 0.5, -125)}, 0.1)
            wait(0.1)
            TweenObject(authFrame, {Position = UDim2.new(0.5, -200, 0.5, -125)}, 0.1)
            
            keyInput.Text = ""
            keyInput:CaptureFocus()
            
            if onFailed then onFailed(KeySystem.CurrentAttempts, KeySystem.MaxAttempts) end
            
            if KeySystem.CurrentAttempts >= KeySystem.MaxAttempts then
                statusLabel.Text = "✗ Maximum attempts reached!"
                submitButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                submitButton.Active = false
                keyInput.Active = false
                
                if onMaxAttempts then onMaxAttempts() end
                
                wait(2)
                self:CloseAuthenticationPrompt()
            end
        end
    end
    
    -- Event connections
    submitButton.MouseButton1Click:Connect(submitKey)
    keyInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then submitKey() end
    end)
    
    cancelButton.MouseButton1Click:Connect(function()
        self:CloseAuthenticationPrompt()
        if onFailed then onFailed(KeySystem.CurrentAttempts, KeySystem.MaxAttempts) end
    end)
    
    -- Button hover effects
    submitButton.MouseEnter:Connect(function()
        if submitButton.Active then
            TweenObject(submitButton, {BackgroundColor3 = Color3.fromRGB(DefaultTheme.PrimaryColor.R * 255 * 0.8, DefaultTheme.PrimaryColor.G * 255 * 0.8, DefaultTheme.PrimaryColor.B * 255 * 0.8)}, 0.2)
        end
    end)
    
    submitButton.MouseLeave:Connect(function()
        if submitButton.Active then
            TweenObject(submitButton, {BackgroundColor3 = DefaultTheme.PrimaryColor}, 0.2)
        end
    end)
    
    cancelButton.MouseEnter:Connect(function()
        TweenObject(cancelButton, {BackgroundColor3 = Color3.fromRGB(200, 60, 60)}, 0.2)
    end)
    
    cancelButton.MouseLeave:Connect(function()
        TweenObject(cancelButton, {BackgroundColor3 = Color3.fromRGB(255, 85, 85)}, 0.2)
    end)
end

function AuthUI:CloseAuthenticationPrompt()
    if self.CurrentAuthGui then
        self.CurrentAuthGui:Destroy()
        self.CurrentAuthGui = nil
    end
    self.IsAuthenticating = false
end

function AuthUI:IsAuthenticating()
    return self.IsAuthenticating
end

local function CreateCorner(radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or DefaultTheme.CornerRadius)
    return corner
end

local function CreateStroke(color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or DefaultTheme.AccentColor
    stroke.Thickness = thickness or DefaultTheme.BorderSize
    return stroke
end

local function TweenObject(object, properties, duration, easingStyle, easingDirection)
    local tween = TweenService:Create(
        object,
        TweenInfo.new(duration or 0.3, easingStyle or Enum.EasingStyle.Quad, easingDirection or Enum.EasingDirection.Out),
        properties
    )
    tween:Play()
    return tween
end

local TooltipGui = nil
local TooltipFrame = nil

local function CreateTooltipSystem()
    if TooltipGui then return end
    
    TooltipGui = Instance.new("ScreenGui")
    TooltipGui.Name = "TooltipSystem"
    TooltipGui.ResetOnSpawn = false
    TooltipGui.DisplayOrder = 999
    TooltipGui.Parent = PlayerGui
    
    TooltipFrame = Instance.new("Frame")
    TooltipFrame.Name = "Tooltip"
    TooltipFrame.Size = UDim2.new(0, 200, 0, 30)
    TooltipFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    TooltipFrame.BorderSizePixel = 0
    TooltipFrame.Visible = false
    TooltipFrame.ZIndex = 1000
    TooltipFrame.Parent = TooltipGui
    
    CreateCorner(4):Clone().Parent = TooltipFrame
    CreateStroke(Color3.fromRGB(100, 100, 100), 1):Clone().Parent = TooltipFrame
    
    local tooltipText = Instance.new("TextLabel")
    tooltipText.Name = "Text"
    tooltipText.Size = UDim2.new(1, -10, 1, 0)
    tooltipText.Position = UDim2.new(0, 5, 0, 0)
    tooltipText.BackgroundTransparency = 1
    tooltipText.Text = ""
    tooltipText.TextColor3 = Color3.fromRGB(255, 255, 255)
    tooltipText.Font = Enum.Font.Gotham
    tooltipText.TextSize = 12
    tooltipText.TextXAlignment = Enum.TextXAlignment.Left
    tooltipText.TextWrapped = true
    tooltipText.Parent = TooltipFrame
end

local function ShowTooltip(text, targetFrame)
    CreateTooltipSystem()
    
    local tooltipText = TooltipFrame:FindFirstChild("Text")
    tooltipText.Text = text
    
    -- Calculate text size
    local textService = game:GetService("TextService")
    local textSize = textService:GetTextSize(
        text,
        12,
        Enum.Font.Gotham,
        Vector2.new(300, math.huge)
    )
    
    -- Adjust tooltip size
    TooltipFrame.Size = UDim2.new(0, math.max(textSize.X + 15, 100), 0, math.max(textSize.Y + 10, 25))
    
    -- Position tooltip near mouse
    local mouse = UserInputService:GetMouseLocation()
    local screenSize = workspace.CurrentCamera.ViewportSize
    
    local xPos = mouse.X + 10
    local yPos = mouse.Y - TooltipFrame.AbsoluteSize.Y - 10
    
    -- Keep tooltip on screen
    if xPos + TooltipFrame.AbsoluteSize.X > screenSize.X then
        xPos = mouse.X - TooltipFrame.AbsoluteSize.X - 10
    end
    if yPos < 0 then
        yPos = mouse.Y + 10
    end
    
    TooltipFrame.Position = UDim2.new(0, xPos, 0, yPos)
    TooltipFrame.Visible = true
    
    TooltipFrame.BackgroundTransparency = 1
    tooltipText.TextTransparency = 1
    
    TweenObject(TooltipFrame, {BackgroundTransparency = 0.1}, 0.2)
    TweenObject(tooltipText, {TextTransparency = 0}, 0.2)
end

local function HideTooltip()
    if not TooltipFrame then return end
    
    local tooltipText = TooltipFrame:FindFirstChild("Text")
    
    TweenObject(TooltipFrame, {BackgroundTransparency = 1}, 0.15)
    TweenObject(tooltipText, {TextTransparency = 1}, 0.15)
    
    spawn(function()
        wait(0.15)
        if TooltipFrame then
            TooltipFrame.Visible = false
        end
    end)
end

local function AddTooltipToElement(element, tooltipText)
    local interactiveElement = element
    
    local hasMouseEvents = pcall(function() return element.MouseEnter end)
    
    if not hasMouseEvents then
        for _, child in pairs(element:GetDescendants()) do
            if child:IsA("TextButton") or child:IsA("ImageButton") or child:IsA("TextBox") then
                interactiveElement = child
                break
            end
        end
        
        -- If still no interactive element found, make the main element interactive
        if not pcall(function() return interactiveElement.MouseEnter end) then
            -- Create an invisible button overlay for tooltip detection
            local overlay = Instance.new("TextButton")
            overlay.Size = UDim2.new(1, 0, 1, 0)
            overlay.BackgroundTransparency = 1
            overlay.Text = ""
            overlay.ZIndex = element.ZIndex + 1
            overlay.Parent = element
            interactiveElement = overlay
        end
    end
    
    local connections = {}
    
    -- Mouse enter
    connections[#connections + 1] = interactiveElement.MouseEnter:Connect(function()
        ShowTooltip(tooltipText, element)
    end)
    
    -- Mouse leave
    connections[#connections + 1] = interactiveElement.MouseLeave:Connect(function()
        HideTooltip()
    end)
    
    -- Store connections for cleanup
    if not element:GetAttribute("TooltipConnections") then
        element:SetAttribute("TooltipConnections", true)
        element.AncestryChanged:Connect(function()
            if not element.Parent then
                for _, connection in pairs(connections) do
                    connection:Disconnect()
                end
            end
        end)
    end
    
    return element
end

local function CreateComponentWrapper(element, featureName)
    local wrapper = {
        Element = element,
        FeatureName = featureName,
        WithTooltip = function(self, tooltipText)
            AddTooltipToElement(element, tooltipText)
            return self
        end,
        LockFeature = function(self)
            if self.FeatureName then
                KeySystem:LockFeature(self.FeatureName)
                if element:IsA("TextButton") or element:IsA("ImageButton") then
                    element.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    element.TextColor3 = Color3.fromRGB(120, 120, 120)
                elseif element:IsA("Frame") then
                    element.BackgroundTransparency = 0.5
                    for _, child in pairs(element:GetDescendants()) do
                        if child:IsA("TextLabel") or child:IsA("TextButton") then
                            child.TextTransparency = 0.5
                        end
                    end
                end
            end
            return self
        end,
        UnlockFeature = function(self)
            if self.FeatureName then
                KeySystem:UnlockFeature(self.FeatureName)
                if element:IsA("TextButton") or element:IsA("ImageButton") then
                    element.BackgroundColor3 = DefaultTheme.SecondaryColor
                    element.TextColor3 = DefaultTheme.TextColor
                elseif element:IsA("Frame") then
                    element.BackgroundTransparency = 0
                    for _, child in pairs(element:GetDescendants()) do
                        if child:IsA("TextLabel") or child:IsA("TextButton") then
                            child.TextTransparency = 0
                        end
                    end
                end
            end
            return self
        end,
        IsLocked = function(self)
            return self.FeatureName and KeySystem:IsFeatureLocked(self.FeatureName)
        end
    }

    if element:IsA("TextButton") or element:IsA("ImageButton") then
        local originalCallback = nil

        local connections = getconnections and getconnections(element.MouseButton1Click) or {}
        if #connections > 0 then
            originalCallback = connections[1].Function
        end

        element.MouseButton1Click:Connect(function()
            if featureName and KeySystem:IsFeatureLocked(featureName) and not KeySystem:IsUserAuthenticated() then
                Library:ShowAuthenticationPrompt(
                    function(keyType)
                        Library:Notify({
                            Title = "Feature Unlocked",
                            Text = "You now have access to this feature.",
                            Duration = 3
                        })
                        if originalCallback then originalCallback() end
                    end,
                    function(attempts, maxAttempts)
                        Library:Notify({
                            Title = "Access Denied",
                            Text = "Invalid key for this feature.",
                            Duration = 3
                        })
                    end,
                    function()
                        Library:Notify({
                            Title = "Access Blocked",
                            Text = "Maximum attempts reached.",
                            Duration = 5
                        })
                    end
                )
                return
            end
        end)
    end
    
    return wrapper
end

local Window = {}
Window.__index = Window

function Window:CreateTab(name)
    local Tab = {}
    Tab.__index = Tab
    
    local tabButton = Instance.new("TextButton")
    tabButton.Name = name
    tabButton.Size = UDim2.new(0, 120, 0, 30)
    tabButton.BackgroundColor3 = self.Theme.SecondaryColor
    tabButton.BorderSizePixel = 0
    tabButton.Text = name
    tabButton.TextColor3 = self.Theme.TextColor
    tabButton.Font = self.Theme.Font
    tabButton.TextSize = 14
    tabButton.Parent = self.TabContainer
    
    CreateCorner(self.Theme.CornerRadius):Clone().Parent = tabButton
    
    local tabContent = Instance.new("ScrollingFrame")
    tabContent.Name = name .. "Content"
    tabContent.Size = UDim2.new(1, 0, 1, 0)
    tabContent.Position = UDim2.new(0, 0, 0, 0)
    tabContent.BackgroundTransparency = 1
    tabContent.BorderSizePixel = 0
    tabContent.ScrollBarThickness = 6
    tabContent.ScrollBarImageColor3 = self.Theme.PrimaryColor
    tabContent.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabContent.Visible = false
    tabContent.Parent = self.ContentFrame
    
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    layout.Parent = tabContent
    
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tabContent.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end)
    
    tabButton.MouseButton1Click:Connect(function()
        if KeySystem:IsTabLocked(name) and not KeySystem:IsUserAuthenticated() then
            Library:ShowAuthenticationPrompt(
                function(keyType)
                    Library:Notify({
                        Title = "Access Granted",
                        Text = "Welcome! You now have " .. keyType .. " access.",
                        Duration = 3
                    })
                    self:SwitchTab(name)
                end,
                function(attempts, maxAttempts)
                    Library:Notify({
                        Title = "Access Denied",
                        Text = "Invalid key. Attempts: " .. attempts .. "/" .. maxAttempts,
                        Duration = 3
                    })
                end,
                function()
                    Library:Notify({
                        Title = "Access Blocked",
                        Text = "Maximum attempts reached. Access denied.",
                        Duration = 5
                    })
                end
            )
        else
            self:SwitchTab(name)
        end
    end)
    
    tabButton.MouseEnter:Connect(function()
        TweenObject(tabButton, {BackgroundColor3 = self.Theme.PrimaryColor}, 0.2)
    end)
    
    tabButton.MouseLeave:Connect(function()
        if self.ActiveTab ~= name then
            TweenObject(tabButton, {BackgroundColor3 = self.Theme.SecondaryColor}, 0.2)
        end
    end)
    
    self.Tabs[name] = {
        Button = tabButton,
        Content = tabContent,
        ElementCount = 0
    }
    
    if #self.TabOrder == 0 then
        self:SwitchTab(name)
    end
    
    table.insert(self.TabOrder, name)
    
    function Tab:CreateButton(text, callback)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -10, 0, 35)
        button.BackgroundColor3 = self.Theme.SecondaryColor
        button.BorderSizePixel = 0
        button.Text = text
        button.TextColor3 = self.Theme.TextColor
        button.Font = self.Theme.Font
        button.TextSize = 14
        button.LayoutOrder = self.Tabs[name].ElementCount
        button.Parent = tabContent
        
        CreateCorner(self.Theme.CornerRadius):Clone().Parent = button
        
        button.MouseEnter:Connect(function()
            TweenObject(button, {BackgroundColor3 = self.Theme.PrimaryColor}, 0.2)
        end)
        
        button.MouseLeave:Connect(function()
            TweenObject(button, {BackgroundColor3 = self.Theme.SecondaryColor}, 0.2)
        end)
        
        button.MouseButton1Click:Connect(function()
            TweenObject(button, {Size = UDim2.new(1, -15, 0, 30)}, 0.1)
            wait(0.1)
            TweenObject(button, {Size = UDim2.new(1, -10, 0, 35)}, 0.1)
            if callback then callback() end
        end)
        
        self.Tabs[name].ElementCount = self.Tabs[name].ElementCount + 1
        return CreateComponentWrapper(button)
    end
    
    function Tab:CreateToggle(text, default, callback)
        local toggleFrame = Instance.new("Frame")
        toggleFrame.Size = UDim2.new(1, -10, 0, 35)
        toggleFrame.BackgroundColor3 = self.Theme.SecondaryColor
        toggleFrame.BorderSizePixel = 0
        toggleFrame.LayoutOrder = self.Tabs[name].ElementCount
        toggleFrame.Parent = tabContent
        
        CreateCorner(self.Theme.CornerRadius):Clone().Parent = toggleFrame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -50, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = self.Theme.TextColor
        label.Font = self.Theme.Font
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = toggleFrame
        
        local toggleButton = Instance.new("TextButton")
        toggleButton.Size = UDim2.new(0, 30, 0, 20)
        toggleButton.Position = UDim2.new(1, -40, 0.5, -10)
        toggleButton.BackgroundColor3 = default and self.Theme.PrimaryColor or Color3.fromRGB(60, 60, 60)
        toggleButton.BorderSizePixel = 0
        toggleButton.Text = ""
        toggleButton.Parent = toggleFrame
        
        CreateCorner(10):Clone().Parent = toggleButton
        
        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(0, 16, 0, 16)
        indicator.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        indicator.BorderSizePixel = 0
        indicator.Parent = toggleButton
        
        CreateCorner(8):Clone().Parent = indicator
        
        local state = default
        
        toggleButton.MouseButton1Click:Connect(function()
            state = not state
            
            TweenObject(toggleButton, {
                BackgroundColor3 = state and self.Theme.PrimaryColor or Color3.fromRGB(60, 60, 60)
            }, 0.2)
            
            TweenObject(indicator, {
                Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            }, 0.2)
            
            if callback then callback(state) end
        end)
        
        self.Tabs[name].ElementCount = self.Tabs[name].ElementCount + 1
        return CreateComponentWrapper(toggleFrame)
    end
    
    function Tab:CreateSlider(text, min, max, default, callback)
        local sliderFrame = Instance.new("Frame")
        sliderFrame.Size = UDim2.new(1, -10, 0, 50)
        sliderFrame.BackgroundColor3 = self.Theme.SecondaryColor
        sliderFrame.BorderSizePixel = 0
        sliderFrame.LayoutOrder = self.Tabs[name].ElementCount
        sliderFrame.Parent = tabContent
        
        CreateCorner(self.Theme.CornerRadius):Clone().Parent = sliderFrame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -60, 0, 20)
        label.Position = UDim2.new(0, 10, 0, 5)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = self.Theme.TextColor
        label.Font = self.Theme.Font
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = sliderFrame
        
        local valueLabel = Instance.new("TextLabel")
        valueLabel.Size = UDim2.new(0, 50, 0, 20)
        valueLabel.Position = UDim2.new(1, -55, 0, 5)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = tostring(default)
        valueLabel.TextColor3 = self.Theme.PrimaryColor
        valueLabel.Font = self.Theme.Font
        valueLabel.TextSize = 14
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.Parent = sliderFrame
        
        local sliderTrack = Instance.new("Frame")
        sliderTrack.Size = UDim2.new(1, -20, 0, 4)
        sliderTrack.Position = UDim2.new(0, 10, 1, -15)
        sliderTrack.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        sliderTrack.BorderSizePixel = 0
        sliderTrack.Parent = sliderFrame
        
        CreateCorner(2):Clone().Parent = sliderTrack
        
        local sliderFill = Instance.new("Frame")
        sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        sliderFill.BackgroundColor3 = self.Theme.PrimaryColor
        sliderFill.BorderSizePixel = 0
        sliderFill.Parent = sliderTrack
        
        CreateCorner(2):Clone().Parent = sliderFill
        
        local sliderButton = Instance.new("TextButton")
        sliderButton.Size = UDim2.new(0, 12, 0, 12)
        sliderButton.Position = UDim2.new((default - min) / (max - min), -6, 0.5, -6)
        sliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        sliderButton.BorderSizePixel = 0
        sliderButton.Text = ""
        sliderButton.Parent = sliderTrack
        
        CreateCorner(6):Clone().Parent = sliderButton
        
        local value = default
        local dragging = false
        
        sliderButton.MouseButton1Down:Connect(function()
            dragging = true
        end)
        
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local mouse = UserInputService:GetMouseLocation()
                local trackPos = sliderTrack.AbsolutePosition.X
                local trackSize = sliderTrack.AbsoluteSize.X
                local relativePos = math.clamp((mouse.X - trackPos) / trackSize, 0, 1)
                
                value = math.floor(min + (max - min) * relativePos)
                valueLabel.Text = tostring(value)
                
                TweenObject(sliderButton, {Position = UDim2.new(relativePos, -6, 0.5, -6)}, 0.1)
                TweenObject(sliderFill, {Size = UDim2.new(relativePos, 0, 1, 0)}, 0.1)
                
                if callback then callback(value) end
            end
        end)
        
        self.Tabs[name].ElementCount = self.Tabs[name].ElementCount + 1
        return CreateComponentWrapper(sliderFrame)
    end
    
    function Tab:CreateDropdown(text, options, callback)
        local dropdownFrame = Instance.new("Frame")
        dropdownFrame.Size = UDim2.new(1, -10, 0, 35)
        dropdownFrame.BackgroundColor3 = self.Theme.SecondaryColor
        dropdownFrame.BorderSizePixel = 0
        dropdownFrame.LayoutOrder = self.Tabs[name].ElementCount
        dropdownFrame.Parent = tabContent
        
        CreateCorner(self.Theme.CornerRadius):Clone().Parent = dropdownFrame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.5, -10, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = self.Theme.TextColor
        label.Font = self.Theme.Font
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = dropdownFrame
        
        local dropdownButton = Instance.new("TextButton")
        dropdownButton.Size = UDim2.new(0.5, -20, 0, 25)
        dropdownButton.Position = UDim2.new(0.5, 5, 0, 5)
        dropdownButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        dropdownButton.BorderSizePixel = 0
        dropdownButton.Text = tostring(options[1] or "Select...")
        dropdownButton.TextColor3 = Color3.fromRGB(255, 255, 255) -- Ensure white text
        dropdownButton.TextTransparency = 0 -- Ensure text is visible
        dropdownButton.Font = self.Theme.Font
        dropdownButton.TextSize = 12
        dropdownButton.TextScaled = false
        dropdownButton.Parent = dropdownFrame
        
        CreateCorner(self.Theme.CornerRadius):Clone().Parent = dropdownButton
        
        local dropdownList = Instance.new("ScrollingFrame")
        dropdownList.Size = UDim2.new(0, 150, 0, math.min(#options * 25, 150)) -- Max height 150px
        dropdownList.BackgroundColor3 = self.Theme.BackgroundColor
        dropdownList.BorderSizePixel = 0
        dropdownList.Visible = false
        dropdownList.ZIndex = 1000
        dropdownList.ScrollBarThickness = 6
        dropdownList.ScrollBarImageColor3 = self.Theme.PrimaryColor
        dropdownList.CanvasSize = UDim2.new(0, 0, 0, #options * 25)
        dropdownList.Parent = self.ScreenGui
        
        CreateCorner(self.Theme.CornerRadius):Clone().Parent = dropdownList
        CreateStroke(self.Theme.AccentColor, 1):Clone().Parent = dropdownList
        
        local listLayout = Instance.new("UIListLayout")
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.FillDirection = Enum.FillDirection.Vertical
        listLayout.Padding = UDim.new(0, 0)
        listLayout.Parent = dropdownList
        
        local selectedValue = options[1]
        
        for i, option in ipairs(options) do
            local optionButton = Instance.new("TextButton")
            optionButton.Size = UDim2.new(1, -6, 0, 25) -- Account for scrollbar
            optionButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
            optionButton.BackgroundTransparency = 0 -- Ensure fully opaque
            optionButton.BorderSizePixel = 0
            optionButton.Text = option
            optionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            optionButton.TextTransparency = 0 -- Ensure text is fully visible
            optionButton.Font = self.Theme.Font
            optionButton.TextSize = 14
            optionButton.TextScaled = false
            optionButton.LayoutOrder = i
            optionButton.Parent = dropdownList
            
            -- Add corner radius
            CreateCorner(4):Clone().Parent = optionButton
            
            -- Add border for better visibility
            local stroke = CreateStroke(Color3.fromRGB(100, 100, 100), 1)
            stroke.Parent = optionButton
            
            optionButton.MouseEnter:Connect(function()
                TweenObject(optionButton, {BackgroundColor3 = self.Theme.PrimaryColor}, 0.2)
            end)
            
            optionButton.MouseLeave:Connect(function()
                TweenObject(optionButton, {BackgroundColor3 = Color3.fromRGB(70, 70, 70)}, 0.2)
            end)
            
            optionButton.MouseButton1Click:Connect(function()
                selectedValue = option
                dropdownButton.Text = tostring(option)
                dropdownList.Visible = false
                if callback then callback(option) end
            end)
        end
        
        dropdownButton.MouseButton1Click:Connect(function()
            if dropdownList.Visible then
                dropdownList.Visible = false
            else
                -- Position dropdown list below the button
                local buttonPos = dropdownButton.AbsolutePosition
                local buttonSize = dropdownButton.AbsoluteSize
                dropdownList.Position = UDim2.new(0, buttonPos.X, 0, buttonPos.Y + buttonSize.Y + 2)
                dropdownList.Size = UDim2.new(0, math.max(buttonSize.X, 150), 0, math.min(#options * 25, 150))
                dropdownList.CanvasSize = UDim2.new(0, 0, 0, #options * 25)
                dropdownList.Visible = true
            end
        end)
        
        -- Close dropdown when clicking elsewhere
        local clickConnection
        dropdownList:GetPropertyChangedSignal("Visible"):Connect(function()
            if dropdownList.Visible then
                clickConnection = UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local mousePos = UserInputService:GetMouseLocation()
                        local listPos = dropdownList.AbsolutePosition
                        local listSize = dropdownList.AbsoluteSize
                        local buttonPos = dropdownButton.AbsolutePosition
                        local buttonSize = dropdownButton.AbsoluteSize
                        
                        -- Check if click is outside dropdown list and button
                        if not (mousePos.X >= listPos.X and mousePos.X <= listPos.X + listSize.X and
                               mousePos.Y >= listPos.Y and mousePos.Y <= listPos.Y + listSize.Y) and
                           not (mousePos.X >= buttonPos.X and mousePos.X <= buttonPos.X + buttonSize.X and
                               mousePos.Y >= buttonPos.Y and mousePos.Y <= buttonPos.Y + buttonSize.Y) then
                            dropdownList.Visible = false
                        end
                    end
                end)
            else
                if clickConnection then
                    clickConnection:Disconnect()
                    clickConnection = nil
                end
            end
        end)
        
        self.Tabs[name].ElementCount = self.Tabs[name].ElementCount + 1
        return CreateComponentWrapper(dropdownFrame)
    end
    
    function Tab:CreateTextbox(text, placeholder, callback)
        local textboxFrame = Instance.new("Frame")
        textboxFrame.Size = UDim2.new(1, -10, 0, 35)
        textboxFrame.BackgroundColor3 = self.Theme.SecondaryColor
        textboxFrame.BorderSizePixel = 0
        textboxFrame.LayoutOrder = self.Tabs[name].ElementCount
        textboxFrame.Parent = tabContent
        
        CreateCorner(self.Theme.CornerRadius):Clone().Parent = textboxFrame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.4, -10, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = self.Theme.TextColor
        label.Font = self.Theme.Font
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = textboxFrame
        
        local textbox = Instance.new("TextBox")
        textbox.Size = UDim2.new(0.6, -20, 0, 25)
        textbox.Position = UDim2.new(0.4, 5, 0, 5)
        textbox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        textbox.BorderSizePixel = 0
        textbox.Text = ""
        textbox.PlaceholderText = placeholder or "Enter text..."
        textbox.TextColor3 = self.Theme.TextColor
        textbox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
        textbox.Font = self.Theme.Font
        textbox.TextSize = 12
        textbox.ClearTextOnFocus = false
        textbox.Parent = textboxFrame
        
        CreateCorner(self.Theme.CornerRadius):Clone().Parent = textbox
        
        textbox.FocusLost:Connect(function(enterPressed)
            if enterPressed and callback then
                callback(textbox.Text)
            end
        end)
        
        self.Tabs[name].ElementCount = self.Tabs[name].ElementCount + 1
        return CreateComponentWrapper(textboxFrame)
    end
    
    function Tab:CreateKeybind(text, defaultKey, callback)
        local keybindFrame = Instance.new("Frame")
        keybindFrame.Size = UDim2.new(1, -10, 0, 35)
        keybindFrame.BackgroundColor3 = self.Theme.SecondaryColor
        keybindFrame.BorderSizePixel = 0
        keybindFrame.LayoutOrder = self.Tabs[name].ElementCount
        keybindFrame.Parent = tabContent
        
        CreateCorner(self.Theme.CornerRadius):Clone().Parent = keybindFrame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.6, -10, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = self.Theme.TextColor
        label.Font = self.Theme.Font
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = keybindFrame
        
        local keybindButton = Instance.new("TextButton")
        keybindButton.Size = UDim2.new(0.4, -20, 0, 25)
        keybindButton.Position = UDim2.new(0.6, 5, 0, 5)
        keybindButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        keybindButton.BorderSizePixel = 0
        keybindButton.Text = defaultKey.Name or "None"
        keybindButton.TextColor3 = self.Theme.TextColor
        keybindButton.Font = self.Theme.Font
        keybindButton.TextSize = 12
        keybindButton.Parent = keybindFrame
        
        CreateCorner(self.Theme.CornerRadius):Clone().Parent = keybindButton
        
        local currentKey = defaultKey
        local listening = false
        
        keybindButton.MouseButton1Click:Connect(function()
            if not listening then
                listening = true
                keybindButton.Text = "Press a key..."
                keybindButton.BackgroundColor3 = self.Theme.PrimaryColor
            end
        end)
        
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if listening and not gameProcessed then
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    currentKey = input.KeyCode
                    keybindButton.Text = input.KeyCode.Name
                    keybindButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    listening = false
                end
            elseif input.KeyCode == currentKey and not gameProcessed then
                if callback then callback() end
            end
        end)
        
        self.Tabs[name].ElementCount = self.Tabs[name].ElementCount + 1
        return CreateComponentWrapper(keybindFrame)
    end
    
    -- Add color picker functionality
    function Tab:CreateColorPicker(text, defaultColor, callback)
        local colorFrame = Instance.new("Frame")
        colorFrame.Size = UDim2.new(1, -10, 0, 35)
        colorFrame.BackgroundColor3 = self.Theme.SecondaryColor
        colorFrame.BorderSizePixel = 0
        colorFrame.LayoutOrder = self.Tabs[name].ElementCount
        colorFrame.Parent = tabContent
        
        CreateCorner(self.Theme.CornerRadius):Clone().Parent = colorFrame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.7, -10, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = self.Theme.TextColor
        label.Font = self.Theme.Font
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = colorFrame
        
        local colorPreview = Instance.new("Frame")
        colorPreview.Size = UDim2.new(0, 25, 0, 25)
        colorPreview.Position = UDim2.new(1, -35, 0, 5)
        colorPreview.BackgroundColor3 = defaultColor or Color3.fromRGB(255, 255, 255)
        colorPreview.BorderSizePixel = 0
        colorPreview.Parent = colorFrame
        
        CreateCorner(self.Theme.CornerRadius):Clone().Parent = colorPreview
        CreateStroke(self.Theme.AccentColor, 1):Clone().Parent = colorPreview
        
        local colorButton = Instance.new("TextButton")
        colorButton.Size = UDim2.new(1, 0, 1, 0)
        colorButton.BackgroundTransparency = 1
        colorButton.Text = ""
        colorButton.Parent = colorPreview
        
        local currentColor = defaultColor or Color3.fromRGB(255, 255, 255)
        
        colorButton.MouseButton1Click:Connect(function()
            -- Create color picker window
            local colorPickerGui = Instance.new("ScreenGui")
            colorPickerGui.Name = "ColorPicker"
            colorPickerGui.ResetOnSpawn = false
            colorPickerGui.Parent = PlayerGui
            
            local colorPickerFrame = Instance.new("Frame")
            colorPickerFrame.Size = UDim2.new(0, 250, 0, 200)
            colorPickerFrame.Position = UDim2.new(0.5, -125, 0.5, -100)
            colorPickerFrame.BackgroundColor3 = self.Theme.BackgroundColor
            colorPickerFrame.BorderSizePixel = 0
            colorPickerFrame.Parent = colorPickerGui
            
            CreateCorner(self.Theme.CornerRadius):Clone().Parent = colorPickerFrame
            CreateStroke(self.Theme.AccentColor, 2):Clone().Parent = colorPickerFrame
            
            -- Title
            local pickerTitle = Instance.new("TextLabel")
            pickerTitle.Size = UDim2.new(1, -30, 0, 30)
            pickerTitle.Position = UDim2.new(0, 10, 0, 5)
            pickerTitle.BackgroundTransparency = 1
            pickerTitle.Text = "Color Picker"
            pickerTitle.TextColor3 = self.Theme.TextColor
            pickerTitle.Font = Enum.Font.GothamBold
            pickerTitle.TextSize = 16
            pickerTitle.TextXAlignment = Enum.TextXAlignment.Left
            pickerTitle.Parent = colorPickerFrame
            
            local pickerClose = Instance.new("TextButton")
            pickerClose.Size = UDim2.new(0, 20, 0, 20)
            pickerClose.Position = UDim2.new(1, -25, 0, 5)
            pickerClose.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
            pickerClose.BorderSizePixel = 0
            pickerClose.Text = "×"
            pickerClose.TextColor3 = Color3.fromRGB(255, 255, 255)
            pickerClose.Font = Enum.Font.GothamBold
            pickerClose.TextSize = 12
            pickerClose.Parent = colorPickerFrame
            
            CreateCorner(10):Clone().Parent = pickerClose
            
            local function createRGBSlider(colorName, colorIndex, yPos)
                local sliderFrame = Instance.new("Frame")
                sliderFrame.Size = UDim2.new(1, -20, 0, 30)
                sliderFrame.Position = UDim2.new(0, 10, 0, yPos)
                sliderFrame.BackgroundTransparency = 1
                sliderFrame.Parent = colorPickerFrame
                
                local sliderLabel = Instance.new("TextLabel")
                sliderLabel.Size = UDim2.new(0, 20, 1, 0)
                sliderLabel.BackgroundTransparency = 1
                sliderLabel.Text = colorName
                sliderLabel.TextColor3 = self.Theme.TextColor
                sliderLabel.Font = self.Theme.Font
                sliderLabel.TextSize = 12
                sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
                sliderLabel.Parent = sliderFrame
                
                local sliderTrack = Instance.new("Frame")
                sliderTrack.Size = UDim2.new(1, -80, 0, 4)
                sliderTrack.Position = UDim2.new(0, 25, 0.5, -2)
                sliderTrack.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                sliderTrack.BorderSizePixel = 0
                sliderTrack.Parent = sliderFrame
                
                CreateCorner(2):Clone().Parent = sliderTrack
                
                local sliderFill = Instance.new("Frame")
                sliderFill.Size = UDim2.new(currentColor[colorIndex], 0, 1, 0)
                sliderFill.BackgroundColor3 = colorIndex == "R" and Color3.fromRGB(255, 0, 0) or 
                                            colorIndex == "G" and Color3.fromRGB(0, 255, 0) or 
                                            Color3.fromRGB(0, 0, 255)
                sliderFill.BorderSizePixel = 0
                sliderFill.Parent = sliderTrack
                
                CreateCorner(2):Clone().Parent = sliderFill
                
                local sliderButton = Instance.new("TextButton")
                sliderButton.Size = UDim2.new(0, 12, 0, 12)
                sliderButton.Position = UDim2.new(currentColor[colorIndex], -6, 0.5, -6)
                sliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                sliderButton.BorderSizePixel = 0
                sliderButton.Text = ""
                sliderButton.Parent = sliderTrack
                
                CreateCorner(6):Clone().Parent = sliderButton
                
                local valueLabel = Instance.new("TextLabel")
                valueLabel.Size = UDim2.new(0, 40, 1, 0)
                valueLabel.Position = UDim2.new(1, -45, 0, 0)
                valueLabel.BackgroundTransparency = 1
                valueLabel.Text = tostring(math.floor(currentColor[colorIndex] * 255))
                valueLabel.TextColor3 = self.Theme.TextColor
                valueLabel.Font = self.Theme.Font
                valueLabel.TextSize = 12
                valueLabel.TextXAlignment = Enum.TextXAlignment.Right
                valueLabel.Parent = sliderFrame
                
                local dragging = false
                
                sliderButton.MouseButton1Down:Connect(function()
                    dragging = true
                end)
                
                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)
                
                UserInputService.InputChanged:Connect(function(input)
                    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                        local mouse = UserInputService:GetMouseLocation()
                        local trackPos = sliderTrack.AbsolutePosition.X
                        local trackSize = sliderTrack.AbsoluteSize.X
                        local relativePos = math.clamp((mouse.X - trackPos) / trackSize, 0, 1)
                        
                        local newValue = relativePos
                        if colorIndex == "R" then
                            currentColor = Color3.new(newValue, currentColor.G, currentColor.B)
                        elseif colorIndex == "G" then
                            currentColor = Color3.new(currentColor.R, newValue, currentColor.B)
                        else
                            currentColor = Color3.new(currentColor.R, currentColor.G, newValue)
                        end
                        
                        valueLabel.Text = tostring(math.floor(newValue * 255))
                        colorPreview.BackgroundColor3 = currentColor
                        
                        TweenObject(sliderButton, {Position = UDim2.new(relativePos, -6, 0.5, -6)}, 0.1)
                        TweenObject(sliderFill, {Size = UDim2.new(relativePos, 0, 1, 0)}, 0.1)
                    end
                end)
            end
            
            createRGBSlider("R", "R", 40)
            createRGBSlider("G", "G", 75)
            createRGBSlider("B", "B", 110)
            
            -- Apply button
            local applyButton = Instance.new("TextButton")
            applyButton.Size = UDim2.new(0, 60, 0, 25)
            applyButton.Position = UDim2.new(0.5, -30, 1, -35)
            applyButton.BackgroundColor3 = self.Theme.PrimaryColor
            applyButton.BorderSizePixel = 0
            applyButton.Text = "Apply"
            applyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            applyButton.Font = self.Theme.Font
            applyButton.TextSize = 12
            applyButton.Parent = colorPickerFrame
            
            CreateCorner(self.Theme.CornerRadius):Clone().Parent = applyButton
            
            applyButton.MouseButton1Click:Connect(function()
                if callback then callback(currentColor) end
                colorPickerGui:Destroy()
            end)
            
            pickerClose.MouseButton1Click:Connect(function()
                colorPickerGui:Destroy()
            end)
        end)
        
        self.Tabs[name].ElementCount = self.Tabs[name].ElementCount + 1
        return CreateComponentWrapper(colorFrame)
    end
    
    setmetatable(Tab, {__index = self})
    return Tab
end

function Window:SwitchTab(tabName)
    -- Hide all tabs
    for name, tab in pairs(self.Tabs) do
        tab.Content.Visible = false
        TweenObject(tab.Button, {BackgroundColor3 = self.Theme.SecondaryColor}, 0.2)
    end
    
    -- Show selected tab
    if self.Tabs[tabName] then
        self.Tabs[tabName].Content.Visible = true
        TweenObject(self.Tabs[tabName].Button, {BackgroundColor3 = self.Theme.PrimaryColor}, 0.2)
        self.ActiveTab = tabName
    end
end

-- Notification system
function Library:Notify(config)
    local notificationGui = Instance.new("ScreenGui")
    notificationGui.Name = "NotificationGui"
    notificationGui.ResetOnSpawn = false
    notificationGui.Parent = PlayerGui
    
    local notification = Instance.new("Frame")
    notification.Size = UDim2.new(0, 300, 0, 80)
    notification.Position = UDim2.new(1, -320, 0, 20)
    notification.BackgroundColor3 = DefaultTheme.BackgroundColor
    notification.BorderSizePixel = 0
    notification.Parent = notificationGui
    
    CreateCorner(DefaultTheme.CornerRadius):Clone().Parent = notification
    CreateStroke(DefaultTheme.PrimaryColor, 2):Clone().Parent = notification
    
    -- Icon (optional)
    if config.Icon then
        local icon = Instance.new("ImageLabel")
        icon.Size = UDim2.new(0, 24, 0, 24)
        icon.Position = UDim2.new(0, 10, 0, 10)
        icon.BackgroundTransparency = 1
        icon.Image = config.Icon
        icon.Parent = notification
    end
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, config.Icon and -50 or -20, 0, 25)
    title.Position = UDim2.new(0, config.Icon and 40 or 10, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = config.Title or "Notification"
    title.TextColor3 = DefaultTheme.TextColor
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = notification
    
    -- Text
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, config.Icon and -50 or -20, 0, 25)
    text.Position = UDim2.new(0, config.Icon and 40 or 10, 0, 30)
    text.BackgroundTransparency = 1
    text.Text = config.Text or ""
    text.TextColor3 = Color3.fromRGB(200, 200, 200)
    text.Font = DefaultTheme.Font
    text.TextSize = 12
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextWrapped = true
    text.Parent = notification
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 20, 0, 20)
    closeButton.Position = UDim2.new(1, -25, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
    closeButton.BorderSizePixel = 0
    closeButton.Text = "×"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 14
    closeButton.Parent = notification
    
    CreateCorner(10):Clone().Parent = closeButton
    
    -- Slide in animation
    notification.Position = UDim2.new(1, 20, 0, 20)
    TweenObject(notification, {Position = UDim2.new(1, -320, 0, 20)}, 0.5, Enum.EasingStyle.Back)
    
    -- Auto-close after duration
    local duration = config.Duration or 5
    
    local function closeNotification()
        TweenObject(notification, {Position = UDim2.new(1, 20, 0, 20)}, 0.3)
        wait(0.3)
        notificationGui:Destroy()
    end
    
    closeButton.MouseButton1Click:Connect(closeNotification)
    
    spawn(function()
        wait(duration)
        if notificationGui.Parent then
            closeNotification()
        end
    end)
end

-- Library Key System Integration
function Library:InitializeKeySystem(config)
    KeySystem:Initialize(config)
    return self
end

function Library:ShowAuthenticationPrompt(onSuccess, onFailed, onMaxAttempts)
    if not KeySystem.Enabled then
        if onSuccess then onSuccess("bypass") end
        return
    end
    
    if KeySystem:IsUserAuthenticated() then
        if onSuccess then onSuccess(KeySystem:GetUserInfo().keyType) end
        return
    end
    
    AuthUI:CreateAuthenticationPrompt(onSuccess, onFailed, onMaxAttempts)
end

function Library:AddValidKey(key)
    return KeySystem:AddValidKey(key)
end

function Library:RemoveValidKey(key)
    return KeySystem:RemoveValidKey(key)
end

function Library:AddAdminKey(key)
    return KeySystem:AddAdminKey(key)
end

function Library:IsUserAuthenticated()
    return KeySystem:IsUserAuthenticated()
end

function Library:IsUserAdmin()
    return KeySystem:IsUserAdmin()
end

function Library:GetUserInfo()
    return KeySystem:GetUserInfo()
end

function Library:LockTab(tabName)
    KeySystem:LockTab(tabName)
end

function Library:UnlockTab(tabName)
    KeySystem:UnlockTab(tabName)
end

function Library:LockFeature(featureName)
    KeySystem:LockFeature(featureName)
end

function Library:UnlockFeature(featureName)
    KeySystem:UnlockFeature(featureName)
end

function Library:LogoutUser()
    KeySystem:Logout()
end

function Library:GetKeySystemStats()
    return KeySystem:GetStats()
end

-- Internal function to create the actual window
local function createWindowInternal(config)
    local window = setmetatable({}, Window)
    
    -- Apply theme
    window.Theme = {}
    for key, value in pairs(DefaultTheme) do
        window.Theme[key] = (config.Theme and config.Theme[key]) or value
    end
    
    -- Create main ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UILibrary"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = PlayerGui
    
    -- Main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 500, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
    mainFrame.BackgroundColor3 = window.Theme.BackgroundColor
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui
    
    CreateCorner(window.Theme.CornerRadius):Clone().Parent = mainFrame
    CreateStroke(window.Theme.AccentColor, window.Theme.BorderSize):Clone().Parent = mainFrame
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = window.Theme.SecondaryColor
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    CreateCorner(window.Theme.CornerRadius):Clone().Parent = titleBar
    
    -- Title text
    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -80, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = config.Title or "UI Library"
    titleText.TextColor3 = window.Theme.TextColor
    titleText.Font = window.Theme.Font
    titleText.TextSize = 16
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
    closeButton.BorderSizePixel = 0
    closeButton.Text = "×"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 18
    closeButton.Parent = titleBar
    
    CreateCorner(window.Theme.CornerRadius):Clone().Parent = closeButton
    
    -- Close button functionality
    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    -- Tab container
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(1, 0, 0, 35)
    tabContainer.Position = UDim2.new(0, 0, 0, 40)
    tabContainer.BackgroundColor3 = window.Theme.SecondaryColor
    tabContainer.BorderSizePixel = 0
    tabContainer.Parent = mainFrame
    
    -- Tab list layout
    local tabListLayout = Instance.new("UIListLayout")
    tabListLayout.FillDirection = Enum.FillDirection.Horizontal
    tabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabListLayout.Padding = UDim.new(0, 2)
    tabListLayout.Parent = tabContainer
    
    -- Content container
    local contentContainer = Instance.new("Frame")
    contentContainer.Name = "ContentContainer"
    contentContainer.Size = UDim2.new(1, -20, 1, -85)
    contentContainer.Position = UDim2.new(0, 10, 0, 75)
    contentContainer.BackgroundTransparency = 1
    contentContainer.Parent = mainFrame
    
    -- Initialize window properties
    window.ScreenGui = screenGui
    window.MainFrame = mainFrame
    window.TabContainer = tabContainer
    window.ContentFrame = contentContainer
    window.Tabs = {}
    window.TabOrder = {}
    window.ActiveTab = nil
    
    -- Window methods
    function window:ToggleUI()
        local visible = not screenGui.Enabled
        screenGui.Enabled = visible
        return visible
    end
    
    function window:Destroy()
        screenGui:Destroy()
    end
    
    return window
end

-- Library main functions
function Library:CreateWindow(config)
    -- Handle key system configuration
    if config.KeySystem then
        local keySettings = config.KeySettings or {}
        
        -- Initialize key system with settings
        KeySystem:Initialize({
            Enabled = true,
            ValidKeys = keySettings.Key or {"Hello"},
            AdminKeys = {},
            MaxAttempts = 3,
            AuthenticationRequired = true
        })
        
        -- Variable to store the real window after authentication
        local realWindow = nil
        local isAuthenticated = false
        
        -- Function to create window after authentication
        local function createRealWindow()
            realWindow = createWindowInternal(config)
            isAuthenticated = true
            return realWindow
        end
        
        -- Show key authentication screen
        local function showKeyScreen()
            local keyGui = Instance.new("ScreenGui")
            keyGui.Name = "KeySystemAuth"
            keyGui.ResetOnSpawn = false
            keyGui.DisplayOrder = 1001
            keyGui.Parent = PlayerGui
            
            -- Background
            local background = Instance.new("Frame")
            background.Size = UDim2.new(1, 0, 1, 0)
            background.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            background.BorderSizePixel = 0
            background.Parent = keyGui
            
            -- Main frame
            local mainFrame = Instance.new("Frame")
            mainFrame.Size = UDim2.new(0, 450, 0, 300)
            mainFrame.Position = UDim2.new(0.5, -225, 0.5, -150)
            mainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            mainFrame.BorderSizePixel = 0
            mainFrame.Parent = keyGui
            
            CreateCorner(8):Clone().Parent = mainFrame
            CreateStroke(Color3.fromRGB(60, 60, 60), 1):Clone().Parent = mainFrame
            
            -- Title
            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, -40, 0, 40)
            title.Position = UDim2.new(0, 20, 0, 20)
            title.BackgroundTransparency = 1
            title.Text = keySettings.Title or config.Title or "Key System"
            title.TextColor3 = Color3.fromRGB(255, 255, 255)
            title.Font = Enum.Font.GothamBold
            title.TextSize = 20
            title.TextXAlignment = Enum.TextXAlignment.Center
            title.Parent = mainFrame
            
            -- Subtitle
            local subtitle = Instance.new("TextLabel")
            subtitle.Size = UDim2.new(1, -40, 0, 25)
            subtitle.Position = UDim2.new(0, 20, 0, 65)
            subtitle.BackgroundTransparency = 1
            subtitle.Text = keySettings.Subtitle or "Key System"
            subtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
            subtitle.Font = Enum.Font.Gotham
            subtitle.TextSize = 14
            subtitle.TextXAlignment = Enum.TextXAlignment.Center
            subtitle.Parent = mainFrame
            
            -- Note
            local note = Instance.new("TextLabel")
            note.Size = UDim2.new(1, -40, 0, 40)
            note.Position = UDim2.new(0, 20, 0, 100)
            note.BackgroundTransparency = 1
            note.Text = keySettings.Note or "No method of obtaining the key is provided"
            note.TextColor3 = Color3.fromRGB(150, 150, 150)
            note.Font = Enum.Font.Gotham
            note.TextSize = 12
            note.TextXAlignment = Enum.TextXAlignment.Center
            note.TextWrapped = true
            note.Parent = mainFrame
            
            -- Key input
            local keyInput = Instance.new("TextBox")
            keyInput.Size = UDim2.new(1, -60, 0, 40)
            keyInput.Position = UDim2.new(0, 30, 0, 160)
            keyInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            keyInput.BorderSizePixel = 0
            keyInput.Text = ""
            keyInput.PlaceholderText = "Enter your key here..."
            keyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
            keyInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
            keyInput.Font = Enum.Font.Gotham
            keyInput.TextSize = 14
            keyInput.ClearTextOnFocus = false
            keyInput.Parent = mainFrame
            
            CreateCorner(6):Clone().Parent = keyInput
            
            -- Check key button
            local checkButton = Instance.new("TextButton")
            checkButton.Size = UDim2.new(0, 120, 0, 35)
            checkButton.Position = UDim2.new(0.5, -60, 0, 220)
            checkButton.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
            checkButton.BorderSizePixel = 0
            checkButton.Text = "Check Key"
            checkButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            checkButton.Font = Enum.Font.GothamBold
            checkButton.TextSize = 14
            checkButton.Parent = mainFrame
            
            CreateCorner(6):Clone().Parent = checkButton
            
            -- Status label
            local statusLabel = Instance.new("TextLabel")
            statusLabel.Size = UDim2.new(1, -40, 0, 20)
            statusLabel.Position = UDim2.new(0, 20, 0, 270)
            statusLabel.BackgroundTransparency = 1
            statusLabel.Text = ""
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            statusLabel.Font = Enum.Font.Gotham
            statusLabel.TextSize = 12
            statusLabel.TextXAlignment = Enum.TextXAlignment.Center
            statusLabel.Parent = mainFrame
            
            -- Animation
            mainFrame.Position = UDim2.new(0.5, -225, 0.5, -200)
            TweenObject(mainFrame, {Position = UDim2.new(0.5, -225, 0.5, -150)}, 0.5, Enum.EasingStyle.Back)
            
            -- Focus input
            keyInput:CaptureFocus()
            
            -- Check key function
            local function checkKey()
                local enteredKey = keyInput.Text
                if enteredKey == "" then
                    statusLabel.Text = "Please enter a key"
                    statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                    return
                end
                
                local isValid = false
                for _, validKey in pairs(keySettings.Key or {"Hello"}) do
                    if validKey == enteredKey then
                        isValid = true
                        break
                    end
                end
                
                if isValid then
                    statusLabel.Text = "Authentication successful!"
                    statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                    
                    -- Save key if enabled
                    if keySettings.SaveKey then
                        local fileName = keySettings.FileName or "Key"
                        print("[KeySystem] Key saved as:", fileName)
                    end
                    
                    -- Authenticate user
                    KeySystem:AuthenticateUser(enteredKey)
                    
                    wait(1)
                    TweenObject(mainFrame, {Position = UDim2.new(0.5, -225, 0.5, -200)}, 0.3)
                    wait(0.3)
                    keyGui:Destroy()
                    
                    -- Create the real window now that user is authenticated
                    createRealWindow()
                    
                    print("[KeySystem] Authentication successful! Main UI loaded.")
                else
                    statusLabel.Text = "Invalid key! Please try again."
                    statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                    
                    TweenObject(mainFrame, {Position = UDim2.new(0.5, -215, 0.5, -150)}, 0.1)
                    wait(0.1)
                    TweenObject(mainFrame, {Position = UDim2.new(0.5, -235, 0.5, -150)}, 0.1)
                    wait(0.1)
                    TweenObject(mainFrame, {Position = UDim2.new(0.5, -225, 0.5, -150)}, 0.1)
                    
                    keyInput.Text = ""
                    keyInput:CaptureFocus()
                end
            end
            
            checkButton.MouseButton1Click:Connect(checkKey)
            keyInput.FocusLost:Connect(function(enterPressed)
                if enterPressed then checkKey() end
            end)
            
            checkButton.MouseEnter:Connect(function()
                TweenObject(checkButton, {BackgroundColor3 = Color3.fromRGB(0, 140, 220)}, 0.2)
            end)
            
            checkButton.MouseLeave:Connect(function()
                TweenObject(checkButton, {BackgroundColor3 = Color3.fromRGB(0, 162, 255)}, 0.2)
            end)
        end
        
        showKeyScreen()
        
        -- Wait until authentication is complete
        while not isAuthenticated do
            wait(0.1)
        end
        
        return realWindow
    else
        return createWindowInternal(config)
    end
end

function Library:ToggleUI()
    for _, gui in pairs(PlayerGui:GetChildren()) do
        if gui.Name == "UILibrary" then
            gui.Enabled = not gui.Enabled
            return gui.Enabled
        end
    end
    return false
end

return Library
