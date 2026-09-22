
local WIDGET, VERSION = 'ListView', 3

local GUI = LibStub('NetEaseGUI-2.0')
local ListView = GUI:NewClass(WIDGET, 'ScrollFrame', VERSION, 'Refresh', 'View', 'Scroll', 'Select', 'Filter')
if not ListView then
    return
end

local floor, max, min = math.floor, math.max, math.min

function ListView:Constructor()
    self.buttons = {}
    self:SetScrollChild(CreateFrame('Frame', nil, self))

    self:SetScript('OnSizeChanged', self.OnSizeChanged)
    self:SetScript('OnScrollRangeChanged', self.Refresh)
    self:SetScript('OnShow', self.Refresh)

    self:SetSelectMode('NONE')
end

function ListView:OnSizeChanged()
    self.maxCount = nil
    self:UpdateLayout()
    self:Refresh()
end

function ListView:Update()
    self:UpdateFilter()
    self:UpdateScrollBar()
    self:UpdateItems()
    self:UpdateScrollRange()
end

function ListView:UpdateScrollRange()
    local range = self:GetVerticalScrollRange()
    self:SetVerticalScroll(0)
    if self:GetReverse() then
        self:SetVerticalScroll(self:AtTop() and -range or 0)
    else
        self:SetVerticalScroll(self:AtBottom() and range or 0)
    end
end

function ListView:UpdateLayout()
    local child = self:GetScrollChild()
    local width, height = self:GetSize()

    child:ClearAllPoints()
    child:SetPoint('TOPLEFT')
    child:SetSize(width - self:GetScrollBarFixedWidth(), height)
end

function ListView:UpdateItems()
    if self.itemBoundRows then
        return self:UpdateItemsBound()
    end

    local offset = self:GetOffset()
    local itemCount = self:GetItemCount()
    local maxCount = self:GetMaxCount()
    local itemHeight = self:GetItemHeight()
    local realCount

    if itemCount > maxCount then
        if self:GetReverse() then
            if not self:AtTop() then
                offset = offset - 1
            end
        else
            if self:AtBottom() then
                offset = offset - 1
            end
        end
        realCount = maxCount + 1
    else
        realCount = itemCount
    end

    local isSingularAdapter = self:GetSingularAdapter()
    local groupHandle = self:GetGroupHandle()
    local prevItemGroupData, startButton, endButton
    local singularLine = true

    for i = 1, realCount do
        local index = self:GetReverse() and offset + realCount - i or offset + i - 1
        local button = self:GetButton(i)
        button:SetID(index)
        button:SetHeight(itemHeight)
        button:SetChecked(self:IsSelected(index))
        button:Show()

        if groupHandle then
            local item = self:GetItem(index)
            local itemGroupData = groupHandle(item)

            startButton = startButton or button
            endButton = endButton or button
            prevItemGroupData = prevItemGroupData or itemGroupData

            if itemGroupData == prevItemGroupData then
                button:Group(nil, nil, startButton)
                endButton = button
            else
                startButton:Group(singularLine, endButton)
                startButton:FireFormat()

                startButton = button
                endButton = button
                singularLine = not singularLine
            end

            prevItemGroupData = itemGroupData

            if i == realCount then
                startButton:Group(singularLine, endButton)
                startButton:FireFormat()
            end
        elseif isSingularAdapter then
            button:Group(i % 2 == 0)
        end

        button:FireFormat()
    end

    for i = realCount + 1, #self.buttons do
        self:GetButton(i):Hide()
    end
end

function ListView:UpdateItemPosition(i)
    local button = self:GetButton(i)
    button:ClearAllPoints()
    local itemSpacing = self:GetItemSpacing()

    if self:GetReverse() then
        if i == 1 then
            button:SetPoint('BOTTOMLEFT')
            button:SetPoint('BOTTOMRIGHT')
        else
            button:SetPoint('BOTTOMLEFT', self:GetButton(i-1), 'TOPLEFT', 0, itemSpacing)
            button:SetPoint('BOTTOMRIGHT', self:GetButton(i-1), 'TOPRIGHT', 0, itemSpacing)
        end
    else
        if i == 1 then
            button:SetPoint('TOPLEFT')
            button:SetPoint('TOPRIGHT')
        else
            button:SetPoint('TOPLEFT', self:GetButton(i-1), 'BOTTOMLEFT', 0, -itemSpacing)
            button:SetPoint('TOPRIGHT', self:GetButton(i-1), 'BOTTOMRIGHT', 0, -itemSpacing)
        end
    end
end

function ListView:UpdatePosition()
    for i in ipairs(self.buttons) do
        button:UpdateItemPosition(i)
    end
end

function ListView:SetReverse(reverse)
    self.reverse = reverse
    self:UpdatePosition()
end

function ListView:GetReverse()
    return self.reverse
end

function ListView:GetMaxCount()
    if not self.maxCount then
        local itemHeight = self:GetItemHeight()
        local itemSpacing = self:GetItemSpacing()
        local height = self:GetScrollChild():GetHeight()

        self.maxCount = floor((height + itemSpacing) / (itemHeight + itemSpacing))
    end
    return self.maxCount
end

function ListView:Clear()
    local list = self:GetItemList()
    if not list then
        return
    end
    wipe(list)

    self:Refresh()
end

-- 默认那套是"固定槽位换标签": 滚动一格, 可见的十来行全部换数据全部重画。
-- 打开这个开关后每行跟着自己那条数据走, 窗口移动时只有真正新进视野的行需要重画, 其余只是挪位置。
-- 只支持没设 groupHandle / singularAdapter 的列表(带分组的那套还要处理组边界, 先不掺和)。
function ListView:SetItemBoundRows(flag)
    if flag and (self:GetGroupHandle() or self:GetSingularAdapter()) then
        return
    end
    self.itemBoundRows = flag or nil
    if flag then
        self.itemRowMap = self.itemRowMap or setmetatable({}, {__mode = 'k'})
        self.itemRowPool = self.itemRowPool or {}
    end
end

function ListView:IsItemBoundRows()
    return self.itemBoundRows
end

-- 拿一条数据对应的行: 有就复用, 没有就从空转的行里挑一个, 实在没有才新建
function ListView:AcquireBoundRow(item)
    local map = self.itemRowMap
    local row = map[item]
    if row then
        return row
    end

    local pool = self.itemRowPool
    for i = 1, #pool do
        local spare = pool[i]
        if not spare.boundItem then
            spare.boundItem = item
            spare.boundRevision = nil
            map[item] = spare
            return spare
        end
    end

    local parent = self:GetScrollChild()
    local itemClass = self:GetItemClass()
    local itemNew = itemClass.Create or itemClass.New
    row = itemNew(itemClass, parent, self.highlightWithoutChecked)

    row:Hide()
    row:SetOwner(self)
    row:SetFrameLevel(parent:GetFrameLevel() + 1)
    row.boundItem = item
    pool[#pool + 1] = row
    map[item] = row
    self:Fire('OnItemCreated', row, #pool)
    return row
end

-- 行离开视野: 解开绑定当备用, 免得池子随着滚动方向越涨越大
function ListView:ReleaseBoundRow(row)
    local item = row.boundItem
    if item then
        self.itemRowMap[item] = nil
        row.boundItem = nil
        row.boundRevision = nil
    end
    row:Hide()
end

function ListView:UpdateItemsBound()
    local offset = self:GetOffset()
    local itemCount = self:GetItemCount()
    local maxCount = self:GetMaxCount()
    local itemHeight = self:GetItemHeight()
    local itemSpacing = self:GetItemSpacing()
    local realCount

    if itemCount > maxCount then
        if self:GetReverse() then
            if not self:AtTop() then
                offset = offset - 1
            end
        else
            if self:AtBottom() then
                offset = offset - 1
            end
        end
        realCount = maxCount + 1
    else
        realCount = itemCount
    end

    local child = self:GetScrollChild()
    local step = itemHeight + itemSpacing
    local pool = self.itemRowPool
    local buttons = self.buttons
    local frameId = (self.boundFrameId or 0) + 1
    self.boundFrameId = frameId

    for i = 1, realCount do
        local index = self:GetReverse() and offset + realCount - i or offset + i - 1
        local item = self:GetItem(index)
        if item then
            local row = self:AcquireBoundRow(item)
            row.boundFrame = frameId
            buttons[i] = row
            row:SetID(index)
            row:SetHeight(itemHeight)
            row:SetChecked(self:IsSelected(index))

            row:ClearAllPoints()
            row:SetPoint('TOPLEFT', child, 'TOPLEFT', 0, -(i - 1) * step)
            row:SetPoint('TOPRIGHT', child, 'TOPRIGHT', 0, -(i - 1) * step)
            row:Show()

            local getter = item.GetRevision
            local revision = getter and getter(item)
            if row.boundRevision ~= revision or row.boundIndex ~= index then
                row.boundRevision = revision
                row.boundIndex = index
                row:FireFormat()
            end
        else
            buttons[i] = nil
        end
    end

    for i = realCount + 1, #buttons do
        buttons[i] = nil
    end

    -- 本轮没进窗口的行放回池子
    for i = 1, #pool do
        local row = pool[i]
        if row.boundItem and row.boundFrame ~= frameId then
            self:ReleaseBoundRow(row)
        end
    end
end
