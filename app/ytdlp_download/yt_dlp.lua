yt_dlp = {
    NOTIFY_EVENT_ID = 101,
    event_type = {
        NOTIFY = 1,
    },
    exe_path = kiko.storage.get("yt_dlp_path"),
    cur_process = nil,
    options = {
        ["--no-playlist"] = "",
        ["--break-on-reject"] = "",
        ["--match-filter"] = "!playlist",
    }
}

yt_dlp.set_exe_path = function(path)
    kiko.storage.set("yt_dlp_path", path)
    yt_dlp.exe_path = path
end

yt_dlp.merge_options = function(...)
    local tables = {...}
    local options = {}
    for k, v in pairs(yt_dlp.options) do
        options[k] = v
    end
    local string_args = {}
    for i = 1, #tables do
        local t = tables[i]
        if type(t) == "table" then
            for k, v in pairs(t) do
                options[k] = v
            end
        elseif type(t) == "string" then
            string_args[#string_args + 1] = t
        end
    end
    local args = {}
    for k, v in pairs(options) do
        args[#args + 1] = k
        if #v > 0 then
            args[#args + 1] = v
        end
    end
    for i = 1, #string_args do
        args[#args + 1] = string_args[i]
    end
    return args
end

yt_dlp.push_event = function(e_type, content)
    local msg = {
        src = "kapp.yt-dlp_download",
        event_type = e_type
    }
    for k, v in pairs(content) do
        msg[k] = v
    end
    kiko.event.push(yt_dlp.NOTIFY_EVENT_ID, msg)
end

yt_dlp.get_info = function(url, callback, options)
    local exe_path = yt_dlp.exe_path
    if exe_path == nil or not kiko.dir.fileinfo(exe_path).exists then
        app.w:message("请先设置yt-dlp位置", kiko.msg.NM_ERROR | kiko.msg.NM_HIDE)
        return
    end

    local p = kiko.process.create()
    yt_dlp.cur_process = p

    p:onevent({
        readready = function(channel)
            if channel == 1 then
                local err = string.trim(p:readerror())
                err = string.encode(err, string.CODE_LOCAL, string.CODE_UTF8)
                yt_dlp.push_event(yt_dlp.event_type.NOTIFY, {notify = err})
            end
        end,
        finished = function(exit_code, exit_status)  -- 进程结束回调
            -- exit_status： 0 正常  1 崩溃
            yt_dlp.cur_process = nil
            if exit_status ~= 0 then
                yt_dlp.push_event(yt_dlp.event_type.NOTIFY, {notify = "yt_dlp异常退出：" .. tostring(exit_code)})
            end
            
            local info_list = string.split(string.trim(p:readoutput()), "\n", true)
            info_str = info_list[#info_list]
            local err, info_obj = kiko.json2table(info_str)
        
            if err ~= nil then
                callback(nil)
            else
                callback(info_obj)
            end
        end,
    })
    local info_options = {
        ["--dump-json"] = ""
    }
    p:start(exe_path, yt_dlp.merge_options(info_options, options, url))    
end

yt_dlp.download = function(url, video, audio, save_path, callback, options)
    local exe_path = yt_dlp.exe_path
    if exe_path == nil or not kiko.dir.fileinfo(exe_path).exists then
        app.w:message("请先设置yt-dlp位置", kiko.msg.NM_ERROR | kiko.msg.NM_HIDE)
        return
    end

    local select_format = ""
    if video ~= nil and audio ~= nil then
        select_format = string.format("%s+%s", video.format_id, audio.format_id)
    elseif video ~= nil then
        select_format = video.format_id
    else
        select_format = audio.format_id
    end

    local download_options = {
        ["--format"] = select_format,
        ["--paths"] = save_path,
    }

    local p = kiko.process.create()
    yt_dlp.cur_process = p

    p:onevent({
        readready = function(channel)
            if channel == 1 then
                local err = string.trim(p:readerror())
                err = string.encode(err, string.CODE_LOCAL, string.CODE_UTF8)
                yt_dlp.push_event(yt_dlp.event_type.NOTIFY, {notify = err})
            else
                local output = string.trim(p:readoutput())
                output = string.encode(output, string.CODE_LOCAL, string.CODE_UTF8)
                yt_dlp.push_event(yt_dlp.event_type.NOTIFY, {notify = output})
            end
        end,
        finished = function(exit_code, exit_status)  -- 进程结束回调
            -- exit_status： 0 正常  1 崩溃
            yt_dlp.cur_process = nil
            if exit_status ~= 0 then
                yt_dlp.push_event(yt_dlp.event_type.NOTIFY, {notify = "yt_dlp异常退出：" .. tostring(exit_code)})
            end
            callback()
        end,
    })
    p:start(exe_path, yt_dlp.merge_options(download_options, options, url))    
end

yt_dlp.cancel_download = function()
    if yt_dlp.cur_process == nil then return false end
    yt_dlp.cur_process:kill()
    yt_dlp.cur_process = nil
    return true
end


return yt_dlp