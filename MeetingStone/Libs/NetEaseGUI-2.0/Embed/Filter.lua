
local GUI = LibStub('NetEaseGUI-2.0')
local View = GUI:NewEmbed('Filter', 1)
if not View then
    return
end

function View:RegisterFilter(method)
    if type(method) == 'function' then
        self.filter = method
        self:InvalidateFilter()
    end
end

function View:UnregisterFilter()
    self.filter = nil
    self:InvalidateFilter()
end

-- 过滤结果按条目缓存: 判过的条目只有自己变了(版本号变了)才重跑
function View:InvalidateFilter()
    if self.filterPass then
        wipe(self.filterPass)
        wipe(self.filterRev)
    end
end

function View:SetFilterText(filterText, ...)
    if not filterText or filterText == '' or filterText == SEARCH then
        filterText = nil
    end
    self.filterText = filterText
    self.filterArgs = {...}
    self.filterArgCount = select('#', ...)

    self:InvalidateFilter()
    self:UpdateFilter()
    self:Refresh()
end

function View:GetFilterText()
    return self.filterText
end

function View:GetFilterArgs()
    if self.filterArgCount > 0 then
        return unpack(self.filterArgs, 1, self.filterArgCount)
    end
end

function View:HasFilterArgs()
    return self.filterText or (self.filterArgCount and self.filterArgCount > 0)
end

function View:UpdateFilter()
    local filter = self.filter
    if not filter or not self:HasFilterArgs() or not self.itemList then
        self.filterList = nil
        return
    end

    self.filterList = wipe(self.filterList or {})

    local passCache, revCache = self.filterPass, self.filterRev
    if not passCache then
        passCache = setmetatable({}, {__mode = 'k'})
        revCache = setmetatable({}, {__mode = 'k'})
        self.filterPass, self.filterRev = passCache, revCache
    end

    local filterText = self:GetFilterText()

    for i = 1 + self:GetExcludeCount(), #self.itemList do
        local item = self.itemList[i]
        local getter = item.GetRevision
        local revision = getter and getter(item)

        if revision then
            -- 有版本号的条目走缓存; 没版本号的(外部数据表之类)照旧每次都判
            if revCache[item] ~= revision then
                revCache[item] = revision
                -- GetFilterArgs()可能返回多个值, 必须留在最后一个实参位展开
                passCache[item] = filter(item, filterText, self:GetFilterArgs()) and true or false
            end
            if passCache[item] then
                tinsert(self.filterList, item)
            end
        elseif filter(item, filterText, self:GetFilterArgs()) then
            tinsert(self.filterList, item)
        end
    end
end
