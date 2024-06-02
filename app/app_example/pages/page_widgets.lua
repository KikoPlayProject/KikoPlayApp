widgets = {}

widgets.onPageBtnClick = function(param)
    local page = kiko.ui.get("wpage")
    page:setopt("current_index", param["src"]:data("idx"))
end

widgets.onFlashBtnClick = function(param)
    kiko.flash()
end

widgets.onBtnClick = function(param)
    app.w:message("Button点击")
end

widgets.onTipBtnClick = function(param)
    kiko.gtip({
        message="提示测试",
        --title="test",
        --timeout=5000,
        --group="aa",
        --showclose=true
        --bg=0xf0000000
    })
end

widgets.onSliderValChanged = function(param)
    local progerss = kiko.ui.get("progress")
    progerss:setopt("value", param.value)
end

widgets.onTextChanged = function(param)
    local lb = kiko.ui.get("input_tip")
    lb:setopt("title", param.text)
end
widgets.onComboChanged = function(param)
    local lb = kiko.ui.get("combo_tip")
    lb:setopt("title", "当前选择：" .. tostring(param["index"]) .. ": " .. param["text"])
end

widgets.timer = kiko.timer.create(200)
widgets.timer:ontimeout(function() 
    local p = kiko.ui.get("t_progress")
    local v = p:getopt("value")
    p:setopt("value", (v+10)%100)
end)
widgets.timer:start()

local tb = kiko.ui.get("textbox")
tb:append([[
<p>多行文本内容测试，封装<strong>QPlainTextEdit</strong>，支持显示<span style="color:#3498db">简单HTML</span></p>
<h3>项目列表</h3>
<ul>
	<li><span style="color:#f1c40f">Item1</span></li>
	<li>Item2</li>
	<li><a href="http://www.kikoplay.fun">Item3</a></li>
</ul>
]], true)

local lb = kiko.ui.get("lb_test")
lb:setopt("title", [[
    <p>Label和多行文本框测试<p>
    <li><a href="http://www.kikoplay.fun">支持多行及简单的HTML</a></li>
    <h3>编号列表</h3>
    <ol>
        <li><em>Item1</em></li>
        <li><u>Item2</u></li>
        <li><s>Item3</s></li>
    </ol>
]])

local img_lb = kiko.ui.get("img_lb")
local img = kiko.ui.createimg(env.app_path .. "/img/kikoplay.png")
img_lb:setimg(img:scale(120, 120, 1))

widgets.onDialogClick = function(param)
    local dtype = param["src"]:data("dtype")
    local path_info_box = kiko.ui.get("path_info_box")
    if dtype == "openfile" then
        local filename = kiko.dialog.openfile({
            title="选择文件",
            path=env.app_path,
            filter="Images (*.jpg *png);;all (*.*)",
            multi = false
        })
        local _, json = kiko.table2json(kiko.dir.fileinfo(filename))
        path_info_box:setopt("text", json)
    elseif dtype == "savefile" then
        local filename = kiko.dialog.savefile({
            title="保存文件",
            path=env.app_path .. "/test.txt",
            filter="Text (*.txt)",
        })
        local _, json = kiko.table2json(kiko.dir.fileinfo(filename))
        path_info_box:setopt("text", json)
    elseif dtype == "selectdir" then
        local dir = kiko.dialog.selectdir({
            path=env.app_path
        })
        local _, json = kiko.table2json(kiko.dir.fileinfo(dir))
        path_info_box:setopt("text", json)
    elseif dtype == "tip" then
        local status, text = kiko.dialog.dialog({
            title="提示对话框",
            tip="这是提示内容。。。。"
        })
    elseif dtype == "input" then
        local status, text = kiko.dialog.dialog({
            title="输入对话框",
            tip="随便输点什么",
            text=""
        })
    elseif dtype == "input_with_img" then
        local img = io.open(env.app_path .. "/img/kikoplay.png", "rb")
        local img_data = img:read("a")
        local status, text = kiko.dialog.dialog({
            title="带有图片的输入对话框",
            tip="随便输点什么",
            text="",
            image=img_data
        })
    end
end

widgets.onListItemDoubleClick = function(param)
    local lb = kiko.ui.get("list_tip")
    lb:setopt("title", "简单列表：" .. param.item.text)
end

widgets.onListItemChanged = function(param)
    local lb = kiko.ui.get("list_tip")
    lb:setopt("title", "简单列表item变化：" .. param.item.text)
end

widgets.onListViewDoubleClick = function(param)
    local lb = kiko.ui.get("listview_tip")
    lb:setopt("title", "带有图标的列表：" .. param.item.text)
end

widgets.onListAddBtnClick = function(param)
    local add_type = param["src"]:data("add_type")
    if add_type == "simp" then
        local simp_list = kiko.ui.get("simp_list")
        local size = simp_list:getopt("count")
        simp_list:append("Item " .. tostring(size + 1))
        simp_list:scrollto(size);
    else
        local comp_list = kiko.ui.get("comp_list")
        local idx = comp_list:append("")
        local view = comp_list:setview(idx, string.format([[
            <hview> 
                <vview content_margin="0,0,0,0" view-depend:trailing-stretch="1">
                    <label title="这是标题 %d" /> 
                    <label title="Test View description......." />
                </vview> 
                <button id="btn" title="Button Test" />
             </hview>
            ]], idx))
        local btn = view:getchild("btn")
        btn:onevent("click", function(param) 
            local lb = kiko.ui.get("clist_tip")
            lb:setopt("title", "复杂列表：" .. tostring(idx))
        end)
        comp_list:scrollto(idx);
    end
end

widgets.onScrollEdge = function(param)
    local loadmore = kiko.ui.get("check_listview"):getopt("checked")
    if not loadmore or not param["bottom"] then
        return 
    end
    local listview = param["src"]
    local idx = listview:getopt("count")
    local items = {}
    for i = 1, 8 do
        table.insert(items, {
            ["text"] = "Item " .. tostring(i + idx), 
            ["icon"] = env.app_path .. string.format("/img/post%d.png", i),
        })
    end
    listview:append(items)
end

widgets.onAddTreeItem = function(param)
    local tree = kiko.ui.get("tree")
    local sels = tree:selection()
    if #sels == 0 then
        local newItem = tree:append({"00:00", "Test", string.format("Test User %d", tree:getopt("count"))})
        newItem:scrollto()
    else
        local item = sels[1]
        item:set(0, "collapse", false)
        local newItem = item:append({"00:00", "Test", string.format("Test User %d", item:get(0, "child_size"))})
        newItem:scrollto()
    end
end

widgets.onRemoveTreeItem = function(param)
    local tree = kiko.ui.get("tree")
    local sels = tree:selection()
    if #sels == 0 then return end
    local item = sels[1]
    local p = item:parent()
    if p == nil then
        tree:remove(item)
    else
        p:remove(item)
    end
end

widgets.onHideTreeHeader = function(param)
    local tree = kiko.ui.get("tree")
    tree:setopt("header_visible", param["state"]~=2)
end

widgets.onTreeItemDClick = function(param)
    local lb = kiko.ui.get("tree_item_tip")
    local item = param["item"]
    lb:setopt("title", string.format("time: %s, child: %d, data: %s", item:get(1, "text"), item:get(1, "child_size"), item:get(1, "data")))
    if type(item:get(1, "data")) == "function" then
        item:get(1, "data")()
    end
end

widgets.onTreeItemChanged = function(param)
    local lb = kiko.ui.get("tree_item_tip")
    local item = param["item"]
    lb:setopt("title", string.format("item内容变化：%s", item:get(param["col"], "text")))
end

local simp_list = kiko.ui.get("simp_list")
simp_list:append({
    {["text"] = "Item 1"},
    {["text"] = "Item 2", ["fg"]=0xff0000},
    {["text"] = "Item 3", ["fg"]=0x00ff00},
    {["text"] = "Item 4"},
    {["text"] = "Item 5", ["fg"]=0x0000ff},
    "Item 6",
    {["text"] = "Item 7, 可编辑", ["edit"] = true }
})

local listview = kiko.ui.get("listview")
listview:append({
    {["text"] = "Item 1", ["icon"] = env.app_path .. "/img/post1.png"},
    {["text"] = "Item 2", ["fg"]=0xff0000, ["icon"] = env.app_path .. "/img/post2.png"},
    {["text"] = "Item 3", ["fg"]=0x00ff00, ["icon"] = env.app_path .. "/img/post3.png"},
    {["text"] = "Item 4", ["icon"] = env.app_path .. "/img/post4.png"},
    {["text"] = "Item 5", ["fg"]=0x0000ff, ["icon"] = env.app_path .. "/img/post5.png"},
    {["text"] = "Item 6", ["icon"] = env.app_path .. "/img/post6.png"},
    {["text"] = "Item 7", ["icon"] = env.app_path .. "/img/post7.png"},
    {["text"] = "Item 8", ["icon"] = env.app_path .. "/img/post8.png"},
})

local tree = kiko.ui.get("tree")
tree:setheader({"时间", "内容", "用户"})
tree:append({"00:00", "KikoPlay TreeTest", "Kikyou"})
local items = tree:append({
    {"00:00", "KikoPlay TreeTest", "Kikyou"},
    {{["text"]="00:01", ["bg"]=0xffff00, ["data"]="dt1"}, {["text"]="Hhhhhhhh", ["fg"]=0x0000ff, ["icon"]=env.app_path .. "/img/app.png" }, "Kikyou2"},
    {{["text"]="这里可以编辑", ["edit"]=true}, {["text"]="Hhhhhhhh", ["fg"]=0x0000ff, ["icon"]=env.app_path .. "/img/app.png" }},
})
items[2]:append({
    {{["text"]="00:01", ["fg"]=0xff0000, ["data"]="dt2"}, "child 1", "Kikyou2-1"},
    {{["text"]="00:01", ["data"]=function() app.w:message("tree item") end}, "child 2", "Kikyou2-2"},
})

local player = kiko.ui.get("player")
player:command({"set", "volume", "10"})
local pos_slider = kiko.ui.get("pos_slider")
widgets.onPlayerOpenFile = function(param)
    local filename = kiko.dialog.openfile({
        title="选择文件",
        path=env.app_path,
        filter="all (*.*)",
        multi = false
    })
    if filename ~= nil then
        player:command({"loadfile", filename})
    end
end

widgets.onPlayerPlayPause = function(param)
    player:command({"cycle", "pause"})
end

widgets.onPlayerStop = function(param)
    player:command({"stop"})
end

widgets.onPlayerDurationChanged = function(param)
    local duration = param["duration"] * 1000  -- ms
    pos_slider:setopt("max", duration)
end

widgets.onPlayerPosChanged = function(param)
    local pos = param["pos"] * 1000  -- ms
    pos_slider:setopt("value", pos)
end

widgets.onPosSliderMoved = function(param)
    local pos = param["value"] / 1000.0
    player:command({"seek", pos, "absolute"})
end

widgets.onVolumeChanged = function(param)
    player:command({"set", "volume", string.format("%d", param["value"])})
end

return widgets