require "srcs/m3u_src"

app = {}

app.srcs = {
    make_m3u_src("TV直播源(IPV6)", "https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/ipv6.m3u"),
    make_m3u_src("Radio直播源", "https://raw.githubusercontent.com/fanmingming/live/main/radio/m3u/index.m3u"),
    require "srcs/lanjing", 
}

app.loaded = function(param)
    local extra_srcs = kiko.storage.get("extra_m3u_srcs") or {}  -- {{name=xx, url=xx}}
    for _, src in pairs(extra_srcs) do
        table.insert(app.srcs, make_m3u_src(src.name, src.url))
    end
    app.live_trees = {}
    app.src_combo = kiko.ui.get("src_combo")
    for _, src in ipairs(app.srcs) do
        app.src_combo:append(src.name)
    end
    local tree_s_view = kiko.ui.get("s_view")
    for i = 1, #app.srcs do
        local t = tree_s_view:addchild(string.format("<tree id=\"tree%d\" header_visible=\"false\" event:item_double_click=\"onTreeItemDClick\"  />", i))
        table.insert(app.live_trees, t)
    end
    -------------------------
    app.src_tree = kiko.ui.get("src_tree")
    app.src_tree:setheader({"名称", "地址"})
    local src_tree_items = {}
    for _, src in ipairs(extra_srcs) do
        table.insert(src_tree_items, { src.name, src.url })
    end
    if #src_tree_items > 0 then
        app.src_tree:append(src_tree_items)
    end
    --------------------------
    local w = param["window"]
    app.w = w
    w:setstyle(env.app_path .. "/style.qss")
    local window_config = kiko.storage.get("window_config") or {}
    if window_config.w ~= nil then
        w:setopt("w", window_config.w)
    end
    if window_config.h ~= nil then
        w:setopt("h", window_config.h)
    end
    if window_config.pinned ~= nil then
        w:setopt("pinned", window_config.pinned)
    end
    w:show()
end

app.close = function(param)
    local window_config = {
        w = app.w:getopt("w"),
        h = app.w:getopt("h"),
        pinned = app.w:getopt("pinned"),
    }
    kiko.storage.set("window_config", window_config)
    return true
end

app.setLiveTree = function(root, lives)
    local item_count = 0
    local cur_level_items = {}
    for _, group in ipairs(lives) do
        if group[2]["url"] ~= nil then
            table.insert(cur_level_items, { {["text"] = group[1], ["data"] = group[2]["url"]} })
            item_count = item_count + 1
        else
            table.insert(cur_level_items, { {["text"] = group[1]} })
        end
    end
    if #cur_level_items == 0 then return 0 end
    local tree_items = root:append(cur_level_items)
    if type(tree_items) ~= "table" then
        tree_items = {tree_items}
    end
    for i, group in ipairs(lives) do
        if group[2]["url"] == nil then
            item_count = item_count + app.setLiveTree(tree_items[i], group[2])
        end
    end
    return item_count
end

app.onRefreshClick = function(param)
    local idx = app.src_combo:getopt("current_index")
    local cur_src = app.srcs[idx]
    local live_tree = app.live_trees[idx]
    if cur_src == nil then return end
    local btn = param["src"]
    btn:setopt("title", "正在刷新...")
    btn:setopt("enable", false)
    app.src_combo:setopt("enable", false)
    cur_src.refresh(function(err, lives)
        if err ~= nil then
            app.w:message(err, kiko.msg.NM_HIDE | kiko.msg.NM_ERROR)
        else
            live_tree:clear()
            local c = app.setLiveTree(live_tree, lives)
            app.w:message(string.format("添加了%d个源", c), kiko.msg.NM_HIDE)
        end
        btn:setopt("title", "刷新")
        btn:setopt("enable", true)
        app.src_combo:setopt("enable", true)
    end)
end

app.onSrcChanged = function(param)
    local idx = param["index"]
    local cur_src = app.srcs[idx]
    local live_tree = app.live_trees[idx]
    if cur_src == nil then return end
    local sview = kiko.ui.get("s_view")
    sview:setopt("current_index", idx)
    if #cur_src.data == 0 then
        local btn = kiko.ui.get("refresh_btn")
        btn:click()
    else
        if live_tree:getopt("count") == 0 then
            app.setLiveTree(live_tree, cur_src.data)
        end
    end
end

app.onTreeItemDClick = function(param)
    local item = param["item"]
    local url = item:get(1, "data")
    if url == nil then return end
    kiko.log("item: ", url)
    kiko.player.setmedia(url)
    app.w:raise()
end

app.onPageNavigate = function(param)
    local s_view = kiko.ui.get("m_sview")
    s_view:setopt("current_index", param["src"]:data("idx"))
end

app.onAddSrc = function(param)
    local n = string.trim(kiko.ui.get("src_name_text"):getopt("text"))
    local u = string.trim(kiko.ui.get("src_url_text"):getopt("text"))
    if #n == 0 or #u == 0 then
        app.w:message("名称或m3u地址不能为空", kiko.msg.NM_HIDE | kiko.msg.NM_ERROR)
        return
    end
    local extra_srcs = kiko.storage.get("extra_m3u_srcs") or {}
    table.insert(extra_srcs, {name=n, url=u})
    kiko.storage.set("extra_m3u_srcs", extra_srcs)
    app.src_tree:append({n, u})
end

app.onMenuClick = function(param)
    if param.id == "m_copy_url" then
        local sels = app.src_tree:selection()
        if #sels == 0 then return end
        local item = sels[1]
        kiko.clipboard.settext(item:get(2, "text"))
    elseif param.id == "m_remove" then
        local sels = app.src_tree:selection()
        if #sels == 0 then return end
        local item = sels[1]
        local idx = app.src_tree:indexof(item)
        local extra_srcs = kiko.storage.get("extra_m3u_srcs") or {}
        table.remove(extra_srcs, idx)
        kiko.storage.set("extra_m3u_srcs", extra_srcs)
        kiko.storage.set(item:get(2, "text"), nil)
        app.src_tree:remove(item)
    end
end