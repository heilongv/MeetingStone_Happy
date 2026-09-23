BuildEnv(...)

local BrowsePanel = Addon:GetModule('BrowsePanel')
local MainPanel = Addon:GetModule('MainPanel')
local Profile = Addon:GetModule('Profile')

IgnoreListPanel = Addon:NewModule(CreateFrame('Frame', nil, MainPanel), 'IgnoreListPanel', 'AceEvent-3.0', 'AceTimer-3.0', 'AceSerializer-3.0',
                              'AceBucket-3.0')


function IgnoreListPanel:OnInitialize()
    GUI:Embed(self, 'Tab')
    MainPanel:RegisterPanel('屏蔽玩家列表', self, {after = '设置'})

    local IgnoreList = GUI:GetClass('DataGridView'):New(self)

    IgnoreList:SetAllPoints(self)
    IgnoreList:SetItemHighlightWithoutChecked(true)
    IgnoreList:SetItemHeight(32)
    IgnoreList:SetItemSpacing(1)
    IgnoreList:SetItemClass(Addon:GetClass('BrowseItem'))
    IgnoreList:SetSelectMode('RADIO')
    IgnoreList:SetScrollStep(9)
    IgnoreList:InitHeader({
        {
            key = '@',
            text = '@',
            width = 30,
            enableMouse = true,
            class = Addon:GetClass('CheckBox'),
            formatHandler = function(grid,activity)
                grid:SetHeight(30)
                grid.Check:SetSize(32, 32)
                grid.Check:SetPoint('CENTER')
                grid.Check:SetChecked(activity.selected)
                grid:SetCallback('OnChanged', function ( data )
                    if activity then
                        activity.selected = data.Check:GetChecked()
                    end
                end)
            end,
        }, {
        --     key = 'Title',
        --     text = '屏蔽的活动标题',
        --     style = 'LEFT',
        --     width = 225,
        --     showHandler = function(activity)
        --         if #activity.titles > 1 then
        --             return activity.titles[1]..'..等'..#activity.titles..'条', NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b
        --         else
        --             return activity.titles[1], NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b
        --         end
        --     end,
        -- }, {
            key = 'Leader',
            text = '屏蔽的队长',
            style = 'LEFT',
            width = 200,
            showHandler = function(activity)
                return activity.leader, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b
            end,
        },
        {
            key = 'Time',
            text = '屏蔽时间',
            width = 200,
            showHandler = function(activity)
                return activity.time
            end,
        },
        {
            key = 'Dep',
            text = '备注',
            width = 350,
            showHandler = function(activity)
                return activity.dep
            end,
        },
    })
    IgnoreList:SetHeaderPoint('BOTTOMLEFT', IgnoreList, 'TOPLEFT', -2, 2)
    self.IgnoreList = IgnoreList

    -- 行是临时的: 存档里只有名字/时间/原因三条平行数组, 勾选状态也就没必要写进存档
    self.rows = {}
    self.rowByName = {}
    self.revision = -1

    local RemoveIgnore = CreateFrame('Button', nil, self, 'UIPanelButtonTemplate')
    do
        RemoveIgnore:SetSize(120, 22)
        RemoveIgnore:SetPoint('BOTTOM', MainPanel, 'BOTTOM', 0, 4)
        RemoveIgnore:SetText('移除勾选玩家')
        RemoveIgnore:SetScript('OnClick', function()
            local del = {}
            for i = 1, #self.rows do
                local row = self.rows[i]
                if row.selected then
                    del[row.leader] = true
                end
            end
            if not next(del) then
                return
            end

            Profile:DelBlocks(del)
            -- 名单变了, 重造行(删掉的人不会再有行, 缓存顺手也就干净了)
            self:UpdateRows()
            BrowsePanel.IgnoreWithTitle = {}
        end)
    end


    local ClearIgnore
    ClearIgnore = CreateFrame('Button', nil, self) do
        ClearIgnore:SetNormalFontObject('GameFontNormalSmall')
        ClearIgnore:SetHighlightFontObject('GameFontHighlightSmall')
        ClearIgnore:SetSize(70, 22)
        ClearIgnore:SetPoint('BOTTOMLEFT', MainPanel, 30, 3)
        ClearIgnore:SetText('全选/取消全选')
        ClearIgnore:RegisterForClicks('anyUp')
        ClearIgnore:SetScript('OnClick', function()
            for i = 1, #self.rows do
                local row = self.rows[i]
                row.selected = not row.selected
            end
            self.IgnoreList:Refresh()
        end)
    end

    self:SetScript('OnShow', self.OnShow)
    self:UpdateRows()
end

-- 名单变了才重造行; 没变就别动, 勾上的东西还能留着
function IgnoreListPanel:UpdateRows()
    local revision = Profile:GetBlockRevision()
    if self.revision == revision then
        return
    end
    self.revision = revision

    local old = self.rowByName
    local rows, rowByName = {}, {}
    for i = 1, Profile:GetBlockNum() do
        local leader = Profile:GetBlockLeader(i)
        local row = old[leader]
        if row then
            row.time = Profile:GetBlockTimeText(i)
            row.dep = Profile:GetBlockDep(i)
        else
            row = {
                leader = leader,
                time = Profile:GetBlockTimeText(i),
                dep = Profile:GetBlockDep(i),
            }
        end
        rows[i] = row
        rowByName[leader] = row
    end

    self.rows = rows
    self.rowByName = rowByName
    self.IgnoreList:SetItemList(rows)
end

function IgnoreListPanel:OnShow()
    self:UpdateRows()
end
