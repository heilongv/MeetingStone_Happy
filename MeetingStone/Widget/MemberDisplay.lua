
BuildEnv(...)

MemberDisplay = Addon:NewClass('MemberDisplay', GUI:GetClass('DataGridViewGridItem'))

function MemberDisplay:Constructor()
    local DataDisplay = CreateFrame('Frame', nil, self, 'LFGListGroupDataDisplayTemplate') do
        DataDisplay:SetPoint('CENTER')
        DataDisplay.RoleCount.DamagerCount:SetWidth(20)
        DataDisplay.RoleCount.HealerCount:SetWidth(18)
        DataDisplay.RoleCount.TankCount:SetWidth(18)
        DataDisplay.PlayerCount.Count:SetWidth(20)
    end

    self.DataDisplay = DataDisplay
end

local function LFGListGroupDataDisplay_Update(self, activityID, displayData, disabled)
    local activityInfo = GetActivityInfo(activityID);
       if(not activityInfo) then
           return;
       end
    if activityInfo.categoryID == 121 then
        -- 不修改共享缓存表：用只读代理表覆盖 displayType，其余字段回退读取原表
        activityInfo = setmetatable({ displayType = Enum.LFGListDisplayType.RoleEnumerate }, { __index = activityInfo })
    end      
    --2022-11-17
    if activityInfo.displayType == Enum.LFGListDisplayType.RoleCount or activityInfo.displayType == Enum.LFGListDisplayType.HideAll then
        self.RoleCount:Show()
        self.Enumerate:Hide()
        self.PlayerCount:Hide()
        LFGListGroupDataDisplayRoleCount_Update(self.RoleCount, displayData, disabled)
    elseif activityInfo.displayType == Enum.LFGListDisplayType.RoleEnumerate then
        self.RoleCount:Hide()
        self.Enumerate:Show()
        self.PlayerCount:Hide()
        LFGListGroupDataDisplayEnumerate_Update(self.Enumerate, activityInfo.maxNumPlayers, displayData, disabled, LFG_LIST_GROUP_DATA_ROLE_ORDER)
    elseif activityInfo.displayType == Enum.LFGListDisplayType.ClassEnumerate then
        self.RoleCount:Hide()
        self.Enumerate:Show()
        self.PlayerCount:Hide()
        LFGListGroupDataDisplayEnumerate_Update(self.Enumerate, activityInfo.maxNumPlayers, displayData, disabled, LFG_LIST_GROUP_DATA_CLASS_ORDER)
    elseif activityInfo.displayType == Enum.LFGListDisplayType.PlayerCount then
        self.RoleCount:Hide()
        self.Enumerate:Hide()
        self.PlayerCount:Show()
        LFGListGroupDataDisplayPlayerCount_Update(self.PlayerCount, displayData, disabled)
    else
        self.RoleCount:Hide()
        self.Enumerate:Hide()
        self.PlayerCount:Hide()
    end
end

function MemberDisplay:SetActivity(activity)
    self.resultID = activity:GetID()
    local displayData = activity:GetMemberCounts()
    if displayData then
        LFGListGroupDataDisplay_Update(self.DataDisplay, activity:GetActivityID(), displayData, activity:IsDelisted() or activity:IsApplicationFinished())
        self.DataDisplay:Show()
    else
        self.DataDisplay:Hide()
    end
end

