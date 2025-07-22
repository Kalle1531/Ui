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

-- Utility functions
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

-- Tooltip system
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
    
    -- Fade in animation
    TooltipFrame.BackgroundTransparency = 1
    tooltipText.TextTransparency = 1
    
    TweenObject(TooltipFrame, {BackgroundTransparency = 0.1}, 0.2)
    TweenObject(tooltipText, {TextTransparency = 0}, 0.2)
end

local function HideTooltip()
    if not TooltipFrame then return end
    
    local tooltipText = TooltipFrame:FindFirstChild("Text")
    
    -- Fade out animation
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
    -- Find the interactive element within the component
    local interactiveElement = element
    
    -- Check if the element has mouse events, if not find a child that does
    local hasMouseEvents = pcall(function() return element.MouseEnter end)
    
    if not hasMouseEvents then
        -- Look for interactive children (TextButton, ImageButton, etc.)
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

-- Helper function to create component wrapper with WithTooltip method
local function CreateComponentWrapper(element)
    return {
        Element = element,
        WithTooltip = function(self, tooltipText)
            AddTooltipToElement(element, tooltipText)
            return self
        end
    }
end

-- Window class
local Window = {}
Window.__index = Window

function Window:CreateTab(name)
    local Tab = {}
    Tab.__index = Tab
    
    -- Create tab button
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
    
    -- Create tab content frame
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
    
    -- Layout for tab content
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    layout.Parent = tabContent
    
    -- Auto-resize canvas
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tabContent.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end)
    
    -- Tab switching logic
    tabButton.MouseButton1Click:Connect(function()
        self:SwitchTab(name)
    end)
    
    -- Hover effects
    tabButton.MouseEnter:Connect(function()
        TweenObject(tabButton, {BackgroundColor3 = self.Theme.PrimaryColor}, 0.2)
    end)
    
    tabButton.MouseLeave:Connect(function()
        if self.ActiveTab ~= name then
            TweenObject(tabButton, {BackgroundColor3 = self.Theme.SecondaryColor}, 0.2)
        end
    end)
    
    -- Store tab data
    self.Tabs[name] = {
        Button = tabButton,
        Content = tabContent,
        ElementCount = 0
    }
    
    -- Set as active if first tab
    if #self.TabOrder == 0 then
        self:SwitchTab(name)
    end
    
    table.insert(self.TabOrder, name)
    
    -- Tab methods
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
        
        -- Button effects
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
        dropdownButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        dropdownButton.BorderSizePixel = 0
        dropdownButton.Text = options[1] or "Select..."
        dropdownButton.TextColor3 = self.Theme.TextColor
        dropdownButton.Font = self.Theme.Font
        dropdownButton.TextSize = 12
        dropdownButton.Parent = dropdownFrame
        
        CreateCorner(self.Theme.CornerRadius):Clone().Parent = dropdownButton
        
        local dropdownList = Instance.new("Frame")
        dropdownList.Size = UDim2.new(0.5, -20, 0, #options * 25)
        dropdownList.Position = UDim2.new(0.5, 5, 1, 5)
        dropdownList.BackgroundColor3 = self.Theme.BackgroundColor
        dropdownList.BorderSizePixel = 0
        dropdownList.Visible = false
        dropdownList.ZIndex = 10
        dropdownList.Parent = dropdownFrame
        
        CreateCorner(self.Theme.CornerRadius):Clone().Parent = dropdownList
        CreateStroke(self.Theme.AccentColor, 1):Clone().Parent = dropdownList
        
        local listLayout = Instance.new("UIListLayout")
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Parent = dropdownList
        
        local selectedValue = options[1]
        
        for i, option in ipairs(options) do
            local optionButton = Instance.new("TextButton")
            optionButton.Size = UDim2.new(1, 0, 0, 25)
            optionButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            optionButton.BorderSizePixel = 0
            optionButton.Text = option
            optionButton.TextColor3 = self.Theme.TextColor
            optionButton.Font = self.Theme.Font
            optionButton.TextSize = 12
            optionButton.LayoutOrder = i
            optionButton.Parent = dropdownList
            
            optionButton.MouseEnter:Connect(function()
                TweenObject(optionButton, {BackgroundColor3 = self.Theme.PrimaryColor}, 0.2)
            end)
            
            optionButton.MouseLeave:Connect(function()
                TweenObject(optionButton, {BackgroundColor3 = Color3.fromRGB(45, 45, 45)}, 0.2)
            end)
            
            optionButton.MouseButton1Click:Connect(function()
                selectedValue = option
                dropdownButton.Text = option
                dropdownList.Visible = false
                if callback then callback(option) end
            end)
        end
        
        dropdownButton.MouseButton1Click:Connect(function()
            dropdownList.Visible = not dropdownList.Visible
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
            
            -- Close button
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
            
            -- RGB Sliders
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

-- Library main functions
function Library:CreateWindow(config)
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
    
    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    -- Description (if provided)
    local descriptionHeight = 0
    if config.Description then
        local description = Instance.new("TextLabel")
        description.Size = UDim2.new(1, -20, 0, 25)
        description.Position = UDim2.new(0, 10, 0, 45)
        description.BackgroundTransparency = 1
        description.Text = config.Description
        description.TextColor3 = Color3.fromRGB(200, 200, 200)
        description.Font = window.Theme.Font
        description.TextSize = 12
        description.TextXAlignment = Enum.TextXAlignment.Left
        description.Parent = mainFrame
        
        descriptionHeight = 30
    end
    
    -- Tab container
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(1, -20, 0, 35)
    tabContainer.Position = UDim2.new(0, 10, 0, 45 + descriptionHeight)
    tabContainer.BackgroundTransparency = 1
    tabContainer.Parent = mainFrame
    
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Padding = UDim.new(0, 5)
    tabLayout.Parent = tabContainer
    
    -- Content frame
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -20, 1, -(90 + descriptionHeight))
    contentFrame.Position = UDim2.new(0, 10, 0, 85 + descriptionHeight)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame
    
    -- Store window properties
    window.ScreenGui = screenGui
    window.MainFrame = mainFrame
    window.TabContainer = tabContainer
    window.ContentFrame = contentFrame
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



-- Add ToggleUI method to Library
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
