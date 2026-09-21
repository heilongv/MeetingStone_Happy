U1RegisterAddon("MeetingStone", {
    title = LOCALE_zhCN and "集合石" or "集合石",
    tags = { TAG_RAID },
    icon = [[Interface\AddOns\MeetingStone\Media\Logo]],
    minimap = "LibDBIcon10_MeetingStone",
    nopic = 1,
	defaultEnable = 1,
    load="NORMAL" , --有人反饋說有問題，先這麽搞了
    desc = LOCALE_zhCN and "目前使用的集合石插件，是由nga论坛brooklynb7维护更新的版本，地址：https://nga.178.com/read.php?tid=35102502" or "目前使用的集合石插件，是由nga論壇brooklynb7維護更新的版本，地址：https://nga.178.com/read.php?tid=35102502",
});

U1RegisterAddon("MeetingStoneEX", {
    parent = "MeetingStone",
    title = LOCALE_zhCN and "集合石扩展" or "集合石擴展",
})
