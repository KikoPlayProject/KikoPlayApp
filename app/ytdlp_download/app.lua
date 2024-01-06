
app = {
    yt_dlp = require "yt_dlp",
    option_text_changed = false,
    current_file_name = nil,
    is_downloading = false,
}

app.loaded = function(param)
    local w = param["window"]
    app.w = w
    app.status_text = kiko.ui.get("status_text")
    app.video_combo = kiko.ui.get("video_format")
    app.audio_combo = kiko.ui.get("audio_format")
    
    kiko.event.listen(yt_dlp.NOTIFY_EVENT_ID, app.event_func)
    app.load_config()

    w:show()
end

app.close = function(param)
    kiko.storage.set("window_config", {
        w = app.w:getopt("w"),
        h = app.w:getopt("h"),
        pinned = app.w:getopt("pinned"),
    })
    return true
end

app.load_config = function()
    local window_config = kiko.storage.get("window_config") or {}
    if window_config.w ~= nil then
        app.w:setopt("w", window_config.w)
    end
    if window_config.h ~= nil then
        app.w:setopt("h", window_config.h)
    end
    if window_config.pinned ~= nil then
        app.w:setopt("pinned", window_config.pinned)
    end

    kiko.ui.get("save_location_textline"):setopt("text", kiko.storage.get("ytdlp_save_path"))
    kiko.ui.get("add_to_playlist_check"):setopt("checked", kiko.storage.get("add_to_playlist") or false)
    kiko.ui.get("yt_dlp_path"):setopt("text", app.yt_dlp.exe_path)
    kiko.ui.get("browser_profile_path_textline"):setopt("text", kiko.storage.get("ytdlp_cookie_profile_path"))

    local browsers = {"无", "firefox", "edge", "chrome", "chromium"}
    local browser_combo = kiko.ui.get("cookie_browser")
    browser_combo:append(browsers)
    local cookie_browser = kiko.storage.get("cookie_browser") or nil
    for i, b in ipairs(browsers) do
        if b == cookie_browser then
            browser_combo:setopt("current_index", i)
            break
        end
    end

    kiko.ui.get("option_text"):setopt("text", kiko.storage.get("extra_options"))
end

app.get_options = function()
    local options = {}
    local browser_combo = kiko.ui.get("cookie_browser")
    local idx = browser_combo:getopt("current_index")
    local profile_path = kiko.storage.get("ytdlp_cookie_profile_path")
    if idx > 1 then
        local browser_item = browser_combo:item(idx)
        if profile_path ~= nil and #profile_path > 0 then
            options["--cookies-from-browser"] = string.format("%s:\"%s\"", browser_item.text, profile_path)
        else
            options["--cookies-from-browser"] = browser_item.text
        end
    end

    local extra_options = string.trim(kiko.storage.get("extra_options"))
    if extra_options ~= nil and #extra_options > 0 then
        local option_lists = string.split(extra_options, "\n", true)
        for _, opt in ipairs(option_lists) do
            local sep_idx = string.indexof(opt, "=")
            if sep_idx == -1 then
                options[opt] = ""
            else
                options[string.sub(opt, 1, sep_idx-1)] = string.sub(opt, sep_idx+1)
            end
        end
    end
    
    return options
end

app.onPageBtnClick = function(param)
    local s_view = kiko.ui.get("page_container")
    s_view:setopt("current_index", param["src"]:data("idx"))
    if param.srcId == "setting_back" then
        if app.option_text_changed then
            local options = kiko.ui.get("option_text"):getopt("text")
            kiko.storage.set("extra_options", options)
            app.option_text_changed = false
        end
    end
end

app.onSetExePathBtnClick = function(param)
    local filename = kiko.dialog.openfile({
        title="设置yt-dlp位置",
        filter="yt-dlp (*.exe);;all (*)",
        multi = false
    })
    if filename and #filename > 0 then
        yt_dlp.set_exe_path(filename)
        kiko.ui.get("yt_dlp_path"):setopt("text", filename)
    end
end

app.event_func = function(param)
    if param.src ~= "kapp.yt-dlp_download" then return end
    if param.event_type == yt_dlp.event_type.NOTIFY then
        app.status_text:append(param.notify)
    end
end

app.set_desc_info = function(info_obj)
    local info_str = "标题：" .. info_obj.title .. "\n"
    if info_obj.series ~= nil then
        info_str = string.format("%s系列：%s\n", info_str, info_obj.series)
    end
    if info_obj.uploader ~= nil then
        info_str = string.format("%s上传用户：%s\n", info_str, info_obj.uploader)
    end
    if info_obj.timestamp ~= nil then
        info_str = string.format("%s时间：%s\n", info_str, os.date("%Y-%m-%d %H:%M:%S", info_obj.timestamp))
    end
    if info_obj.description ~= nil then
        info_str = string.format("%s描述：%s\n", info_str, info_obj.description)
    end
    kiko.ui.get("video_desc"):setopt("text", info_str)
end

app.get_format_size = function(format)
    local sz = 0
    if format.filesize ~= nil then
        sz = format.filesize
    elseif format.filesize_approx ~= nil then
        sz = format.filesize_approx
    else
        return "" 
    end
    local units = {"B","KB","MB","GB","TB"}
    for i = 1, 5 do
        if sz < 1024 then
            return string.format(" %.2f%s", sz, units[i])
        end
        sz = sz / 1024.0
    end
    return string.format(" %.2f%s", sz, units[#units])
end

app.format_is_video = function(format)
    if format.vcodec ~= nil and format.vcodec ~= "none" then return true end
    if format.width ~= nil and type(format.width) == "number" then return true end
    if format.height ~= nil and type(format.height) == "number" then return true end
    return false
end

app.set_formats = function(info_obj)
    local formats = info_obj.formats;
    local video_formats = {}
    local audio_formats = {}
    for _, format in ipairs(formats) do
        if app.format_is_video(format) then
            local format_desc = string.format("%s", format.format)
            if format.resolution ~= nil then
                format_desc = format_desc .. " " .. format.resolution
            end
            if format.vcodec ~= nil then
                format_desc = format_desc .. " " .. format.vcodec
            end
            format_desc = format_desc .. app.get_format_size(format)
            table.insert(video_formats, {
                ["text"] = format_desc,
                ["data"] = format
            })
        else
            local format_desc = string.format("%s", format.format)
            if format.acodec ~= nil and format.acodec ~= "none" then
                format_desc = format_desc .. " " .. format.acodec
            end
            if format.abr ~= nil then
                format_desc = format_desc .. " " .. format.abr .. "KBit/s"
            end
            format_desc = format_desc .. app.get_format_size(format)
            table.insert(audio_formats, {
                ["text"] = format_desc,
                ["data"] = format
            })
        end
    end
    app.video_combo:clear()
    app.video_combo:append(video_formats)
    if #video_formats > 0 then
        app.video_combo:append("无")
    end

    app.audio_combo:clear()
    if #video_formats > 0 then
        app.audio_combo:append("无")
    end
    app.audio_combo:append(audio_formats)
end

app.set_video_info = function(info_obj)
    if info_obj == nil then
        return
    end
    app.set_desc_info(info_obj)
    app.set_formats(info_obj)
    app.current_file_name = info_obj.filename
end

app.onAnalyzeBtnClick = function(param)
    local video_url = string.trim(kiko.ui.get("video_url_textline"):getopt("text"))
    if #video_url == 0 then return end

    kiko.ui.get("video_desc"):clear()
    app.status_text:clear()
    app.current_file_name = nil
    app.video_combo:clear()
    app.audio_combo:clear()

    local analyze_btn = param.src
    local download_btn=  kiko.ui.get("download_btn")
    analyze_btn:setopt("enable", false)
    download_btn:setopt("enable", false)

    app.yt_dlp.get_info(video_url, function(info_obj)
        app.set_video_info(info_obj)
        analyze_btn:setopt("enable", true)
        download_btn:setopt("enable", true)
    end, app.get_options())
end

app.onBrowseBtnClick = function(param)
    local dir = kiko.dialog.selectdir()
    if dir ~= nil then
        kiko.ui.get("save_location_textline"):setopt("text", dir)
        kiko.storage.set("ytdlp_save_path", dir)
    end
end

app.onCookieBrowserChanged = function(param)
    if param.index == 1 then
        kiko.storage.set("cookie_browser", nil)
    else
        kiko.storage.set("cookie_browser", param.text)
    end
end

app.onBrowseProfileBtnClick = function(param)
    local dir = kiko.dialog.selectdir()
    if dir ~= nil then
        kiko.ui.get("browser_profile_path_textline"):setopt("text", dir)
        kiko.storage.set("ytdlp_cookie_profile_path", dir)
    end
end

app.onOptionTextChanged = function()
    app.option_text_changed = true
end

app.onDownloadBtnClick = function(param)
    local save_path = string.trim(kiko.ui.get("save_location_textline"):getopt("text"))
    if #save_path == 0 then return end
    kiko.storage.set("ytdlp_save_path", save_path)

    local analyze_btn = kiko.ui.get("analyze_btn")
    local download_btn=  param.src

    if app.is_downloading then
        if yt_dlp.cancel_download() then
            analyze_btn:setopt("enable", true)
            download_btn:setopt("title", "开始下载")
            app.is_downloading = false
            local file_path = save_path .. "/" .. app.current_file_name
            local l_path = string.encode(file_path, string.CODE_UTF8, string.CODE_LOCAL)
            os.remove(l_path)
            return
        end
    end

    local url = string.trim(kiko.ui.get("video_url_textline"):getopt("text"))
    if #url == 0 then return end

    local video_idx = app.video_combo:getopt("current_index")
    local audio_idx = app.audio_combo:getopt("current_index")
    if video_idx == 0 and audio_idx == 0 then return end

    local video_format = app.video_combo:item(video_idx).data
    local audio_format = app.audio_combo:item(audio_idx).data
    if video_format == nil and audio_format == nil then return end

    analyze_btn:setopt("enable", false)
    -- download_btn:setopt("enable", false)
    download_btn:setopt("title", "取消下载")
    app.is_downloading = true

    app.yt_dlp.download(url, video_format, audio_format, save_path, function()
        analyze_btn:setopt("enable", true)
        -- download_btn:setopt("enable", true)
        download_btn:setopt("title", "开始下载")
        app.is_downloading = false
        local add_to_playlist = kiko.ui.get("add_to_playlist_check"):getopt("checked")
        kiko.storage.set("add_to_playlist", add_to_playlist)
        if add_to_playlist and app.current_file_name ~= nil then
            local file_path = save_path .. "/" .. app.current_file_name
            if not kiko.dir.exists(file_path) then
                app.status_text:append("添加播放列表失败，文件不存在：" .. file_path)
            else
                kiko.playlist.add({
                    title = app.current_file_name,
                    src_type = kiko.playlist.ITEM_LOCAL_FILE,  -- 三种类型：kiko.playlist.ITEM_LOCAL_FILE(本地文件)  kiko.playlist.ITEM_WEB_URL(url)  kiko.playlist.ITEM_COLLECTION(合集)
                    path = file_path,  -- 路径，如果是合集类型条目，设置path可添加本地文件夹
                    position = "/",  -- 插入位置，用/分隔层次
                })
                app.status_text:append("添加到播放列表：" .. file_path)
            end
        end
    end, app.get_options())

end