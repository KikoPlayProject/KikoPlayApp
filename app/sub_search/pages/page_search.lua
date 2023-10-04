search = {
    srcs = {
        require "srcs/zimuku",
        require "srcs/a4k", 
    },
    cur_search_src = nil,
    cur_search_items = {},
    cur_sub = nil,
    cur_sub_file = nil,
}

search.keyword_textline = kiko.ui.get("query_textline")
search.src_combo = kiko.ui.get("src_combo")
search.sub_list = kiko.ui.get("sub_list")
for _, src in ipairs(search.srcs) do
    search.src_combo:append(src.name)
end

search.sub_save_path_textline = kiko.ui.get("sub_save_path_textline")
search.sub_content_tree = kiko.ui.get("sub_content_tree")
search.sub_content_tree:setheader({"压缩包内路径", "大小"})
search.sub_content_tree:headerwidth("set", 1, 400)

search.onSearchSub = function(param)
    local idx = search.src_combo:getopt("current_index")
    local cur_src = search.srcs[idx]
    local keyword = string.trim(search.keyword_textline:getopt("text"))
    if #keyword == 0 then return end

    app.w:message("正在搜索...", kiko.msg.NM_PROCESS | kiko.msg.NM_DARKNESS_BACK)
    local err, items = cur_src.search(keyword)

    if err ~= nil then
        app.w:message(err, kiko.msg.NM_HIDE | kiko.msg.NM_ERROR)
        return
    end
    app.w:message(string.format("找到 %d 条结果", #items), kiko.msg.NM_HIDE)
    search.cur_search_src = idx
    search.cur_search_items = items
    search.sub_list:clear()
    local add_items = {}
    for _, item in ipairs(items) do
        table.insert(add_items, {
            ["text"] = item.title,
            ["tip"] = item.title,
            ["data"] = item.url
        })
    end
    search.sub_list:append(add_items)
end

search.updateSubInfo = function()
    if search.cur_sub == nil then return end
    local t = kiko.ui.get("sub_title_textbox")
    t:setopt("text", search.cur_sub.title)
    local d = kiko.ui.get("sub_desc_textbox")
    d:setopt("text", search.cur_sub.desc)
    local last_save_path = kiko.storage.get("sub_save_path")
    if last_save_path ~= nil then
        search.sub_save_path_textline:setopt("text", search.getUrlFileName(search.cur_sub, last_save_path))
    end
end

search.onSubItemDClick = function(param)
    if search.cur_search_items == nil or search.cur_search_src == nil then return end
    local item = param["item"]
    local idx = item["index"]
    app.w:message("获取信息...", kiko.msg.NM_PROCESS | kiko.msg.NM_DARKNESS_BACK)
    local cur_src = search.srcs[search.cur_search_src]
    local err, cur_sub = cur_src.subinfo(search.cur_search_items[idx])
    if err ~= nil then
        app.w:message(err, kiko.msg.NM_HIDE | kiko.msg.NM_ERROR)
        return
    end
    app.w:message("获取结束", kiko.msg.NM_HIDE)
    kiko.log(cur_sub)

    search.cur_sub = cur_sub
    search.updateSubInfo()
    local s_view = kiko.ui.get("page_container")
    s_view:setopt("current_index", 2)
end

search.onPageNavigate = function(param)
    local s_view = kiko.ui.get("page_container")
    s_view:setopt("current_index", param["src"]:data("idx"))
end

search.getUrlFileName = function(sub, path)
    if sub.filename ~= nil then
        return path .. "/" .. sub.filename
    else
        local pos = string.lastindexof(sub.url, "/")
        if pos == -1 then return path .. "/sub_file" end
        return path .. "/" .. string.sub(sub.url, pos+1)
    end
end

search.formatSize = function(size)
    local sz = tonumber(size)
    if sz == 0 then return "" end
    if sz < 1024 then
        return string.format("%dB", sz)
    elseif sz < 1024*1024 then
        return string.format("%.2fKB", sz / 1024)
    else 
        return string.format("%.2fMB", sz / 1024 / 1024)
    end
end

search.onSetSavePath = function(param)
    if param.src:data("path") == "cur_video" then
        local curfile = kiko.player.curfile()
        if curfile == nil then 
            app.w:message("当前无正在播放的本地文件")
            return
        end
        local info = kiko.dir.fileinfo(curfile)
        if not info.exists then return end
        search.sub_save_path_textline:setopt("text", search.getUrlFileName(search.cur_sub, info.absolutePath))
    else
        local dir = kiko.dialog.selectdir()
        if dir ~= nil then
            search.sub_save_path_textline:setopt("text", search.getUrlFileName(search.cur_sub, dir))
            kiko.storage.set("sub_save_path", dir)
        end
    end
end

search.onBrowse7zPath = function(param)
    local filename = kiko.dialog.openfile({
        title="设置7-Zip位置",
        filter="7-zip (*.exe);;all (*.*)",
        multi = false
    })
    if filename and #filename > 0 then
        kiko.storage.set("7z_path", filename)
    end
end

search.onSubListCheckStateChanged = function(param)
    local check = "true"
    if param.state == 0 then check = "false" end
    for i = 1, search.sub_content_tree:getopt("count") do
        search.sub_content_tree:item(i):set(1, "check", check)
    end
end

search.onDownloadSub = function(param)
    if search.cur_sub == nil then return end
    local save_path = string.trim(search.sub_save_path_textline:getopt("text"))
    local fileinfo = kiko.dir.fileinfo(save_path)
    if #save_path == 0 or fileinfo.isDir then
        app.w:message("未选择保存位置", kiko.msg.NM_ERROR | kiko.msg.NM_HIDE)
        return
    end
    if fileinfo.exists then
        app.w:message("文件已存在", kiko.msg.NM_ERROR | kiko.msg.NM_HIDE)
        return
    end
    local cur_src = search.srcs[search.cur_search_src]
    app.w:message("正在下载...", kiko.msg.NM_PROCESS | kiko.msg.NM_DARKNESS_BACK)
    local err = cur_src.download(search.cur_sub, save_path)
    if err ~= nil then
        app.w:message(err, kiko.msg.NM_HIDE | kiko.msg.NM_ERROR)
        return
    end
    app.w:message("下载成功", kiko.msg.NM_HIDE)
    kiko.execute(true,  "cmd", {"/c", "start", fileinfo.absolutePath})
    app.download_list.add_record(search.cur_sub.title, search.cur_sub.url, fileinfo.absolutePath, cur_src.name)
end

search.onDownloadBrowseSub = function(param)
    local exe_path = kiko.storage.get("7z_path")
    if exe_path == nil or not kiko.dir.fileinfo(exe_path).exists then
        app.w:message("请先设置7z位置", kiko.msg.NM_ERROR | kiko.msg.NM_HIDE)
        return
    end
    if search.cur_sub == nil then return end

    if #string.trim(search.sub_save_path_textline:getopt("text")) == 0 then
        app.w:message("未选择保存位置", kiko.msg.NM_ERROR | kiko.msg.NM_HIDE)
        return
    end

    local save_path = search.getUrlFileName(search.cur_sub, env.data_path)
    local fileinfo = kiko.dir.fileinfo(save_path)
    if not fileinfo.exists then
        local cur_src = search.srcs[search.cur_search_src]
        app.w:message("正在下载...", kiko.msg.NM_PROCESS | kiko.msg.NM_DARKNESS_BACK)
        local err = cur_src.download(search.cur_sub, save_path)
        if err ~= nil then
            app.w:message(err, kiko.msg.NM_HIDE | kiko.msg.NM_ERROR)
            return
        end
        app.w:message("下载成功", kiko.msg.NM_HIDE)
        table.insert(app.tmp_files, save_path)
    end
    local p = kiko.process.create()
    local data = ""
    p:onevent({
        readready = function(channel)
            if channel == 0 then
                data = data .. p:readoutput()
            end
        end
    })
    p:start(exe_path, {"l", "-ba", "-slt", save_path})
    p:waitfinish()
    data = string.encode(data, string.CODE_LOCAL, string.CODE_UTF8)
    local info_list = string.split(data, "\n")
    search.sub_content_tree:clear()
    local cur_path = nil
    local cur_size = ""
    local tree_list_data = {}
    for _, l in ipairs(info_list) do
        local pos = string.indexof(l, "=")
        if pos > 0 then
            local k = string.trim(string.sub(l, 1, pos - 1))
            local v = string.trim(string.sub(l, pos + 1))
            if k == "Path" then
                if cur_path ~= nil then
                    table.insert(tree_list_data, {{text=cur_path, check=false}, cur_size})
                end
                cur_path = v
            elseif k == "Size" then
                cur_size = search.formatSize(v)
            end
        end
    end
    if cur_path ~= nil then
        table.insert(tree_list_data, {{text=cur_path, check=false}, cur_size})
    end
    search.sub_content_tree:append(tree_list_data)
    search.cur_sub_file = save_path
    local s_view = kiko.ui.get("page_container")
    s_view:setopt("current_index", 3)
end

search.onConfirmSelect = function(param)
    local exe_path = kiko.storage.get("7z_path")
    if exe_path == nil or not kiko.dir.fileinfo(exe_path).exists then
        app.w:message("请先设置7z位置", kiko.msg.NM_ERROR | kiko.msg.NM_HIDE)
        return
    end
    if search.cur_sub_file == nil then return end
    local selected_files = {}
    for i = 1, search.sub_content_tree:getopt("count") do
        local item = search.sub_content_tree:item(i)
        if item:get(1, "check") == "true" then
            table.insert(selected_files, item:get(1, "text"))
        end
    end
    if #selected_files == 0 then 
        app.w:message("未选择文件", kiko.msg.NM_ERROR | kiko.msg.NM_HIDE)
    end
    local extract_path = string.trim(search.sub_save_path_textline:getopt("text"))
    local fileinfo = kiko.dir.fileinfo(extract_path)
    if fileinfo.isFile then
        extract_path = fileinfo.absolutePath
    end

    local p = kiko.process.create()
    local params = {"e", search.cur_sub_file, "-y", "-o" .. extract_path}
    for _, path in ipairs(selected_files) do
        table.insert(params, string.format("-i!%s", path))
    end
    app.w:message("正在提取...", kiko.msg.NM_PROCESS | kiko.msg.NM_DARKNESS_BACK)
    p:start(exe_path, params)
    p:waitfinish(30000)
    local exit_code, exit_status = p:exitstate()
    if exit_code == 0 then
        app.w:message("提取完成", kiko.msg.NM_HIDE)
        kiko.execute(true,  "cmd", {"/c", "start", extract_path})
        app.download_list.add_record(search.cur_sub.title, search.cur_sub.url, extract_path, search.srcs[search.cur_search_src].name)
    else
        app.w:message(string.format("提取失败，7z exit code：%d", exit_code), kiko.msg.NM_ERROR | kiko.msg.NM_HIDE)
    end
end

return search