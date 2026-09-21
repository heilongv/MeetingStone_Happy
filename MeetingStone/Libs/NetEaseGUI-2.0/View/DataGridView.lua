
local WIDGET, VERSION = 'DataGridView', 2

local GUI = LibStub('NetEaseGUI-2.0')
local DataGridView = GUI:NewClass(WIDGET, GUI:GetClass('ListView'), VERSION)
if not DataGridView then
    return
end

function DataGridView:Constructor()
    self.sortButtons = {}
    self.sortCache = setmetatable({}, {
        __mode = 'k',
        __index = function(o, k)
            local value = self:MakeSortValue(k)
            o[k] = value
            return value
        end,
    })
    -- 排序键的版本号: 条目自己报了版本号且没变, 这次排序就不用重算它的键
    self.sortRevCache = setmetatable({}, {__mode = 'k'})
    self:SetCallback('OnItemCreated', self.OnItemCreated)
    self:SetCallback('OnItemFormatted', self.OnItemFormatted)
end

function DataGridView:InvalidateSortKeys()
    wipe(self.sortCache)
    wipe(self.sortRevCache)
end

function DataGridView:MakeSortValue(object)
    local value, base
    if type(object) == 'table' and object.BaseSortHandler then
        base = object:BaseSortHandler()
    end
    if self.sortHandler then
        value = self.sortHandler(object)
    end
    if not base then
        return value
    else
        if type(value) == 'number' then
            if value < 0 then
                return format('%044.4f', value) .. base
            else
                return format('%045.4f', value) .. base
            end
        else
            value = strsub(tostring(value), 1, 50)
            -- 主排序值补到定宽再用第二排序键兜底; 原先这里填的是value自己(笔误), 会做出六百多字节的键
            return value .. strrep(' ', 50 - #value) .. base
        end
    end
end

function DataGridView:OnItemCreated(button)
    local x = 0
    for i, v in ipairs(self.sortButtons) do
        local Grid
        if v.class then
            Grid = v.class:New(button)
        else
            Grid = GUI:GetClass('DataGridViewGridItem'):New(button, v.style)
        end

        Grid:EnableMouse(v.enableMouse)
        Grid:SetPoint('TOPLEFT', x, 0)
        Grid:SetPoint('BOTTOMLEFT', x, 0)
        Grid:SetFrameLevel(button:GetFrameLevel()+1)
        Grid.key = v.key

        if i == #self.sortButtons then
            Grid:SetPoint('TOPRIGHT')
        else
            Grid:SetWidth(v.width)
        end
        x = v.width + x - 1

        button[v.key] = Grid

        self:Fire('OnGridCreated', Grid, v.key)
    end
end

function DataGridView:OnItemFormatted(button, data)
    for i, v in ipairs(self.sortButtons) do
        local grid = button[v.key]
        if grid and data then
            if v.showHandler then
                local text, r, g, b, icon, left, right, top, bottom, width, height = v.showHandler(data)

                grid:SetText(text)
                grid:GetFontString():SetTextColor(r or 1, g or 1, b or 1)
                grid:SetIcon(icon, left, right, top, bottom, width, height)
            end
            if v.textHandler then
                local text, r, g, b = v.textHandler(data)
                grid:SetText(text)
                grid:GetFontString():SetTextColor(r or 1, g or 1, b or 1)
            end
            if v.iconHandler then
                grid:SetIcon(v.iconHandler(data))
            end
            if v.atlasHandler then
                grid:SetIconAtlas(v.atlasHandler(data))
            end
            if  v.formatHandler then
                v.formatHandler(grid, data)
            end
        end
    end
end

function DataGridView:SetHeaderPoint(...)
    if not self.sortButtons[1] then
        error('message', 2)
    end
    self.sortButtons[1]:SetPoint(...)
end

function DataGridView:AddHeader(args)
    -- if type(key) ~= 'string' then
    --     error(([[bad argument #1 to 'AddHeader' (string expected, got %s)]]):format(type(key)), 2)
    -- end
    -- if type(text) ~= 'string' then
    --     error(([[bad argument #2 to 'AddHeader' (string expected, got %s)]]):format(type(text)), 2)
    -- end
    -- if type(width) ~= 'number' then
    --     error(([[bad argument #3 to 'AddHeader' (number expected, got %s)]]):format(type(width)), 2)
    -- end
    -- if not (type(showHandler) == 'function' or type(showHandler) == 'nil') then
    --     error(([[bad argument #5 to 'AddHeader' (function/nil expected, got %s)]]):format(type(showHandler)), 2)
    -- end
    -- if not (type(formatHandler) == 'function' or type(formatHandler) == 'nil') then
    --     error(([[bad argument #6 to 'AddHeader' (function/nil expected, got %s)]]):format(type(formatHandler)), 2)
    -- end
    -- if not (type(textHandler) == 'function' or type(textHandler) == 'nil') then
    --     error(([[bad argument #6 to 'AddHeader' (function/nil expected, got %s)]]):format(type(textHandler)), 2)
    -- end
    -- if not (type(iconHandler) == 'function' or type(iconHandler) == 'nil') then
    --     error(([[bad argument #6 to 'AddHeader' (function/nil expected, got %s)]]):format(type(iconHandler)), 2)
    -- end
    -- if not (type(atlasHandler) == 'function' or type(atlasHandler) == 'nil') then
    --     error(([[bad argument #6 to 'AddHeader' (function/nil expected, got %s)]]):format(type(atlasHandler)), 2)
    -- end
    
    local Button = GUI:GetClass('SortButton'):New(self)
    Button:SetSize(args.width, 19)
    Button:SetText(args.text)
    Button.key = args.key
    Button.width = args.width
    Button.style = args.style
    Button.class = args.class
    Button.enableMouse = args.enableMouse
    Button.sortHandler = args.sortHandler
    Button.showHandler = args.showHandler
    Button.formatHandler = args.formatHandler
    Button.textHandler = args.textHandler
    Button.iconHandler = args.iconHandler
    Button.atlasHandler = args.atlasHandler

    if #self.sortButtons > 0 then
        Button:SetPoint('LEFT', self.sortButtons[#self.sortButtons], 'RIGHT', -1, 0)
    end
    tinsert(self.sortButtons, Button)
end

function DataGridView:InitHeader(data)
    for i, v in ipairs(data) do
        self:AddHeader(v)
    end
end

function DataGridView:SetSortHandler(sortHandler, desc)
    if sortHandler ~= self.sortHandler then
        self.sortDesc = desc
        self:InvalidateSortKeys()
    else
        self.sortDesc = not self.sortDesc
    end
    self.sortHandler = sortHandler
    self:Refresh()
end

function DataGridView:GetSortHandler()
    return self.sortHandler
end

function DataGridView:GetSortDesc()
    return self.sortDesc
end

function DataGridView:Update()
    for i, button in ipairs(self.sortButtons) do
        if button.sortHandler and button.sortHandler == self.sortHandler then
            button:SetArrowStyle(self.sortDesc and 'UP' or 'DOWN')
        else
            button:SetArrowStyle('NONE')
        end
    end
    self:Sort()
    self:SuperCall('Update')
end

function DataGridView:Sort()
    if not self.sortHandler then
        return
    end

    local itemList = self:GetItemList()
    if type(itemList) ~= 'table' then
        return
    end

    -- 重算排序键: 报了版本号且没变的条目跳过, 没版本号的照旧每次都算
    local cache, revCache = self.sortCache, self.sortRevCache
    for i = 1, #itemList do
        local item = itemList[i]
        local getter = type(item) == 'table' and item.GetRevision
        local revision = getter and getter(item)
        if revision then
            if revCache[item] ~= revision then
                revCache[item] = revision
                cache[item] = self:MakeSortValue(item)
            end
        else
            cache[item] = self:MakeSortValue(item)
        end
    end

    if self.sortDesc then
        sort(itemList, function(a, b)
            return cache[a] > cache[b]
        end)
    else
        sort(itemList, function(a, b)
            return cache[a] < cache[b]
        end)
    end
end

function DataGridView:SetItemList(itemList)
    self:SuperCall('SetItemList', itemList)
    self:InvalidateSortKeys()
    self:Refresh()
end
