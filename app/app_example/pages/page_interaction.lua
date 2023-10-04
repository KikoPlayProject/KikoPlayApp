interaction = {}

interaction.onPageBtnClick = function(param)
    local page = kiko.ui.get("ipage")
    page:setopt("current_index", param["src"]:data("idx"))
end

interaction.onPlayBtnClick = function(param)
    local formats = {"*.mp4","*.mkv","*.avi","*.flv","*.wmv","*.webm","*.vob","*.mts","*.ts","*.m2ts","*.mov","*.rm","*.rmvb","*.asf","*.m4v","*.mpg","*.mp2","*.mpeg","*.mpe","*.mpv","*.m2v","*.m4v","*.3gp","*.f4v"}
    local filename = kiko.dialog.openfile({
        title="选择视频文件",
        filter=string.format("Video Files(%s);;All Files(*)", table.concat(formats, " ")),
        multi = false
    })
    if #filename > 0 then
        kiko.player.setmedia(filename)
    end
end

interaction.onCurFileBtnClick = function(param)
    local cur_file = kiko.player.curfile()
    if cur_file == nil then
        cur_file = ""
    end
    local tip = kiko.ui.get("cur_file_tip")
    tip:setopt("title", cur_file)
    tip:setopt("tooltip", cur_file)
end

interaction.onGetPropBtnClick = function(param)
    local property = kiko.ui.get("player_property"):getopt("text")
    local err, content = kiko.player.property(property)
    local res_content = ""
    if err < 0 then
        res_content = "error: " .. tostring(err)
    else
        if type(content) == "table" then
            local _, json = kiko.table2json(content)
            res_content = json
        else
            res_content = tostring(content)
        end
    end
    kiko.ui.get("player_property_content"):setopt("text", res_content)
end

interaction.onSetCommandBtnClick = function(param)
    local command = kiko.ui.get("set_player_command"):getopt("text")
    command = string.split(command, " ")
    local ret = kiko.player.command(command)
end

interaction.onPlayListBtnClick = function(param)
    local dtype = param["src"]:data("dtype")
    if dtype == "add_item" then
        local item_title = string.trim(kiko.ui.get("item_title"):getopt("text"))
        if #item_title == 0 then
            app.w:message("名称不能为空", kiko.msg.NM_HIDE | kiko.msg.NM_ERROR)
            return
        end
        local item_type_idx = kiko.ui.get("item_type"):getopt("current_index")
        local item_type_mapping = {kiko.playlist.ITEM_COLLECTION, kiko.playlist.ITEM_LOCAL_FILE, kiko.playlist.ITEM_WEB_URL}
        local item_type = item_type_mapping[item_type_idx]
        local bgm_collection = kiko.ui.get("bgm_collection"):getopt("checked")
        local item_positon = string.trim(kiko.ui.get("item_position"):getopt("text"))
        local item_path = string.trim(kiko.ui.get("item_path"):getopt("text"))
        local anime_title = string.trim(kiko.ui.get("item_anime"):getopt("text"))
        local pool = string.trim(kiko.ui.get("item_pool_id"):getopt("text"))
        kiko.playlist.add({
            title=item_title,
            src_type=item_type,
            bgm_collection=bgm_collection,
            position=item_positon,
            path=item_path,
            anime_title=anime_title,
            pool=pool
        })
    elseif dtype == "cur_item" then
        local cur_item_info = kiko.ui.get("cur_item_info")
        local cur_item = kiko.playlist.curitem()
        local _, json = kiko.table2json(cur_item)
        cur_item_info:setopt("text", json)
    end
end

interaction.onPoolBtnClick = function(param)
    local dtype = param["src"]:data("dtype")
    local anime_title = string.trim(kiko.ui.get("anime_title"):getopt("text"))
    local ep_title = string.trim(kiko.ui.get("ep_name"):getopt("text"))
    local ep_index = tonumber(kiko.ui.get("ep_index"):getopt("text"))
    local ep_type_mapping = {
        kiko.anime.EP_TYPE_EP,
        kiko.anime.EP_TYPE_SP,
        kiko.anime.EP_TYPE_OP,
        kiko.anime.EP_TYPE_ED,
        kiko.anime.EP_TYPE_TRAILER,
        kiko.anime.EP_TYPE_MAD,
        kiko.anime.EP_TYPE_OTHER,
    }
    local ep_type = ep_type_mapping[kiko.ui.get("ep_item_type"):getopt("current_index")]
    if dtype == "get" then
        local pool = kiko.danmu.getpool({
            anime=anime_title,
            ep_index=ep_index,
            ep_type=ep_type
        })
        if pool == nil then
            app.w:message("弹幕池不存在", kiko.msg.NM_HIDE | kiko.msg.NM_ERROR)
            return
        end
        local _, json = kiko.table2json(pool)
        kiko.ui.get("pool_info"):setopt("text", json)
    elseif dtype == "add" then
        local pool_id = kiko.danmu.addpool({
            anime=anime_title,
            ep_index=ep_index,
            ep_type=ep_type,
            ep_name=ep_title,
        })
        if pool_id == nil then
            app.w:message("添加失败", kiko.msg.NM_HIDE | kiko.msg.NM_ERROR)
            return
        end
        kiko.ui.get("pool_info"):setopt("text", string.format("添加成功，id: %s", pool_id))
    end
end

interaction.onLaunchBtnClick = function(param)
    kiko.danmu.launch({
        { text=kiko.ui.get("danmu_content"):getopt("text"), time=100, },
        { text="测试弹幕2", time=100, color=0xff0000},
    })
end

local tree = kiko.ui.get("danmu_tree")
tree:setheader({"时间", "内容", "用户"})

interaction.onGetDanmuBtnClick = function(param)
    local pool_id = string.trim(kiko.ui.get("pool_id"):getopt("text"))
    app.w:message("获取中...", kiko.msg.NM_PROCESS | kiko.msg.NM_DARKNESS_BACK)
    local danmu_info = kiko.danmu.getdanmu(pool_id)
    if danmu_info == nil then
        app.w:message("获取失败", kiko.msg.NM_HIDE | kiko.msg.NM_ERROR)
        return
    end
    local tree = kiko.ui.get("danmu_tree")
    tree:clear()
    local items = {}
    for _, d in ipairs(danmu_info["comment"]) do
        local m = math.floor(d[1] / 60)
        local s = math.floor(d[1] - m*60)
        local color = d[3]
        if color == 0xffffff then
            color = 0x000000
        end
        table.insert(items,{
            string.format("%02d:%02d", m, s),
            {["text"]=d[5], ["fg"]=color},
            d[6]
        })
    end
    tree:append(items)
    app.w:message(string.format("获取完成，有 %d 条弹幕", #danmu_info["comment"]) , kiko.msg.NM_HIDE)
end

interaction.onAddSrcBtnClick = function(param)
    local pool_id = string.trim(kiko.ui.get("pool_id"):getopt("text"))
    if kiko.danmu.getpool(pool_id) == nil then return end
    local status, text = kiko.dialog.dialog({
        title="添加弹幕",
        tip="随便输点什么，一行就是一条弹幕",
        text="测试弹幕1\n测试弹幕2\n测试弹幕3"
    })
    if status == "reject" then return end
    local dms = string.split(text, "\n", true)
    if #dms == 0 then return end
    kiko.log(dms)
    local comments = {}
    for _, dm in ipairs(dms) do
        table.insert(comments, {
            text=dm, time=0
        })
    end
    local srcId = kiko.danmu.addsrc(pool_id, {
        source={
            name="测试弹幕源",
            scriptId="app.test",
            scriptData="t"
        },
        comment=comments,
        save=true
    })
    if srcId == nil then
        app.w:message("添加失败", kiko.msg.NM_HIDE | kiko.msg.NM_ERROR)
    else
        app.w:message("添加成功，id: " .. tostring(srcId), kiko.msg.NM_HIDE)
    end
end

interaction.onGetAnimeBtnClick = function(param)
    local dtype = param["src"]:data("dtype")
    local anime_title = string.trim(kiko.ui.get("anime_name"):getopt("text"))
    if dtype == "info" then
        local anime = kiko.library.getanime(anime_title)
        local _, json = kiko.table2json(anime)
        kiko.ui.get("anime_info"):setopt("text", json)
    elseif dtype == "tag" then
        local tags = kiko.library.gettag(anime_title)
        local _, json = kiko.table2json(tags)
        kiko.ui.get("anime_info"):setopt("text", json)
    end
end

interaction.onAddAnimeBtnClick = function(param)
    local dtype = param["src"]:data("dtype")
    local anime_title = string.trim(kiko.ui.get("n_anime_title"):getopt("text"))
    local air_date = string.trim(kiko.ui.get("air_date"):getopt("text"))
    local ep_count = tonumber(kiko.ui.get("ep_count"):getopt("text"))
    local anime_url = string.trim(kiko.ui.get("anime_url"):getopt("text"))
    local anime_staff = string.trim(kiko.ui.get("anime_staff"):getopt("text"))
    local anime_desc = string.trim(kiko.ui.get("anime_desc"):getopt("text"))
    local anime_tags = string.split(kiko.ui.get("anime_tags"):getopt("text"), ",", true)
    if dtype == "info" then
        local anime = {
            name = anime_title,
            airDate = air_date,
            desc = anime_desc,
            url = anime_url,
            epCount = ep_count,
            staff = anime_staff,
            coverUrl = "file:" .. env.app_path .. "/img/post1.png",
        }
        kiko.library.addanime(anime)
    elseif dtype == "tag" then
        local count = kiko.library.addtag(anime_title, anime_tags)
    end
end

interaction.onBrowseSavePathBtnClick = function(param)
    local dir = kiko.dialog.selectdir()
    kiko.ui.get("save_path"):setopt("text", dir)
end

interaction.onAddTaskBtnClick = function(param)
    local dtype = param["src"]:data("dtype")
    local save_path = string.trim(kiko.ui.get("save_path"):getopt("text"))
    local default_path = kiko.ui.get("default_path"):getopt("checked")
    if default_path then
        save_path = ""
    end
    local skip_magnet_confirm = kiko.ui.get("skip_magnet_confirm"):getopt("checked")
    local skip_confirm = kiko.ui.get("skip_confirm"):getopt("checked")
    if dtype == "url" then
        local download_urls = string.split(kiko.ui.get("download_url"):getopt("text"), "\n", true) 
        local has_err, err = kiko.download.addurl({
            url=download_urls,
            save_dir = save_path,
            skip_magnet_confirm=skip_magnet_confirm,
            skip_confirm=skip_confirm,
        })
    elseif dtype == "torrent" then
        local filename = kiko.dialog.openfile({
            title="选择种子文件",
            filter="Torrent File (*.torrent)",
            multi = false
        })
        if #filename > 0 then
            filename = string.encode(filename, string.CODE_UTF8, string.CODE_LOCAL)
            local torrent_file = io.open(filename, "rb")
            local data = torrent_file:read("a")
            kiko.download.addtorrent(data, save_path)
        end
    end
end

local event_list = kiko.ui.get("event_list")
event_list:append({
    {["text"] = "播放状态变化",   ["data"] = kiko.event.EVENT_PLAYER_STATE_CHANGED, ["check"]=false},
    {["text"] = "播放文件变换",   ["data"] = kiko.event.EVENT_PLAYER_FILE_CHANGED, ["check"]=false},
    {["text"] = "动画加入资料库", ["data"] = kiko.event.EVENT_LIBRARY_ANIME_ADDED, ["check"]=false},
    {["text"] = "资料库动画更新",  ["data"] = kiko.event.EVENT_LIBRARY_ANIME_UPDATED, ["check"]=false},
    {["text"] = "分集完播",       ["data"] = kiko.event.EVENT_LIBRARY_EP_FINISH, ["check"]=false},
    {["text"] = "App样式变化",    ["data"] = kiko.event.EVENT_APP_STYLE_CHANGED, ["check"]=false},
})

widgets.onEventListItemClick = function(param)
    local event = param.item.data
    local event_info = kiko.ui.get("event_info")
    if param.item.check then
        kiko.event.listen(event, function(p)
            local event_map = {
                [kiko.event.EVENT_PLAYER_STATE_CHANGED] = "PlayStateChanged",
                [kiko.event.EVENT_PLAYER_FILE_CHANGED] = "PlayFileChanged",
                [kiko.event.EVENT_LIBRARY_ANIME_ADDED] = "LibraryAnimeAdded",
                [kiko.event.EVENT_LIBRARY_ANIME_UPDATED] = "LibraryAnimeUpdated",
                [kiko.event.EVENT_LIBRARY_EP_FINISH] = "LibraryEpFinish",
                [kiko.event.EVENT_APP_STYLE_CHANGED] = "AppStyleChanged",
            }
            local _, json = kiko.table2json(p)
            event_info:append(string.format("[%s]%s", event_map[event], json))
        end)
    else
        kiko.event.unlisten(event)
    end
end

interaction.onTextClipboardBtnClick = function(param)
    local dtype = param["src"]:data("dtype")
    if dtype == "copy" then
        local txt = kiko.ui.get("clipboard_text"):getopt("text")
        kiko.clipboard.settext(txt)
    elseif dtype == "paste" then
        kiko.ui.get("clipboard_text"):setopt("text", kiko.clipboard.gettext())
    end
end

local img = kiko.ui.createimg(env.app_path .. "/img/kikoplay.png")
kiko.ui.get("clipboard_img_lb"):setimg(img:scale(120, 120, 1))

interaction.onImgClipboardBtnClick = function(param)
    local dtype = param["src"]:data("dtype")
    local lb = kiko.ui.get("clipboard_img_lb")
    if dtype == "copy" then
        kiko.clipboard.setimg(lb:getimg())
    elseif dtype == "paste" then
        lb:setimg(kiko.clipboard.getimg())
    end
end

interaction.onStorageBtnClick = function(param)
    local dtype = param["src"]:data("dtype")
    local key = kiko.ui.get("storage_key"):getopt("text")
    local val = kiko.ui.get("storage_val"):getopt("text")
    if dtype == "read" then
        kiko.ui.get("storage_val"):setopt("text", kiko.storage.get(key))
    elseif dtype == "write" then
        kiko.storage.set(key, val)
    end
end

return interaction
