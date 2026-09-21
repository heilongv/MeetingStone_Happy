# MeetingStone_Happy（开心版集合石）

魔兽世界集合石插件，整合包自用维护版。仓库根目录就是两个能直接用的插件目录：

- `MeetingStone\` — 主插件
- `MeetingStoneEX\` — 扩展（老农粉丝图标、神秘备注、忽略列表、额外过滤）

## 来源与许可

- 原版作者：DengSir（tdaddon@163.com）；开心版上游：<https://gitee.com/xmmmmm/meeting-stone_-happy>（master分支，WTFPL）
- 本仓库是**整合包（LNui）里在用的那一版**加上我们自己的修复，不是上游的镜像，也不代表上游。
- **许可：GPLv3**（全文在`LICENSE`）。可以自由使用、修改、再发布；但**改了再发布必须同样开源**，不能闭源拿去卖。
- 上游那份WTFPL原文留在`LICENSE-WTFPL.txt`。WTFPL本身不带任何条件，所以**从上游拿到的那部分代码，别人仍可按WTFPL使用**（比本仓库的GPLv3更宽松），这点拦不住；留着原文只是把声明保留下来。
- 插件里内嵌的`NetEase*`库和`Media\`素材来自网易当年的集合石项目，版权归原权利方，随插件一起分发。

## 安装

把`MeetingStone\`和`MeetingStoneEX\`两个目录丢进`World of Warcraft\_retail_\Interface\AddOns\`即可。
客户端`Interface`：120100（12.1）。

## 依赖

toc里写的是`## Dependencies: !!!Libs`——这套版本是跟着整合包走的：Ace3、LibDataBroker、LibDBIcon、LibWindow、NetEase*、LibShowUIPanel这些库都由整合包的`!!!Libs`提供。
不装整合包单独用的话要自己补这些库，否则`LibStub`拿不到库会一路报错。

## 和上游的差别

- 内嵌的Ace*全套已删掉，改用整合包的`!!!Libs`（toc里那条Dependencies就是这么来的）
- 换了自己的`Media\`，多了`CfgMeetingStone.lua`（整合包启动器的注册文件，不由toc加载）
- 带12.1客户端的适配修补，以及本地加的东西（老农粉丝识别、`MeetingStoneEX`的忽略列表修复等）

**同步上游更新必须逐文件merge**，不能整目录覆盖——本地改动分散在若干文件里，覆盖就丢。
