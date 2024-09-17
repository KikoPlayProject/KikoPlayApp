app = {
    recognizer = require 'recognizer',
    translator = require 'translator',
    cur_video_file = nil,
    cur_sub_res = nil,
    cur_saved_sub_file = nil,
    prompt_changed = false,
    _STORAGE_whisper_model = "whisper_model",
    _STORAGE_chatgpt_api = "chatgpt_api_key",
    _STORAGE_save_sub_type = "save_sub_type",
    _STORAGE_volume = "player_volume",
    _STORAGE_tran_only_miss = "sub_trans_only_miss_part",
    _STORAGE_chatgpt_prompt = "chatgpt_prompt",
    _STORAGE_cuda_whisper = "enable_cuda_whisper",
    _STORAGE_chatgpt_req_sub_cnt = "chatgpt_req_sub_cnt",
    _STORAGE_video_lang = "whisper_video_lang",
}


app.loaded = function(param)
    app.player = kiko.ui.get("player")
    app.player:command({"set", "volume", "20"})
    app.pos_slider = kiko.ui.get("pos_slider")
    app.pos_label = kiko.ui.get("time_label")

    app.sub_list_tree = kiko.ui.get("sub_list_tree")
    app.sub_list_tree:setheader({"开始时间", "结束时间", "识别内容", "翻译结果"})

    local w = param["window"]
    app.w = w
    app.load_settings()

    w:setstyle(env.app_path .. "/style.qss")
    w:show()
end

app.load_settings = function()
    kiko.ui.get("whisper_model_textline"):setopt("text", kiko.storage.get(app._STORAGE_whisper_model) or "")
    kiko.ui.get("chatgpt_api_key_textline"):setopt("text", kiko.storage.get(app._STORAGE_chatgpt_api) or "")
    kiko.ui.get("video_lang_textline"):setopt("text", kiko.storage.get(app._STORAGE_video_lang) or "auto")
    local volume = kiko.storage.get(app._STORAGE_volume)
    if volume ~= nil then
        kiko.ui.get("volume_slider"):setopt("value", volume)
    end
    local cur_save_type = kiko.storage.get(app._STORAGE_save_sub_type)
    if cur_save_type ~= nil then
        kiko.ui.get("save_sub_type_combo"):setopt("current_index", cur_save_type)
    end
    kiko.ui.get("sub_trans_miss_check"):setopt("checked", kiko.storage.get(app._STORAGE_tran_only_miss) or false)
    kiko.ui.get("prompt_text"):setopt("text", kiko.storage.get(app._STORAGE_chatgpt_prompt) or app.translator:get_prompt())
    kiko.ui.get("cuda_whisper_check"):setopt("checked", kiko.storage.get(app._STORAGE_cuda_whisper) or false)
    local req_sub_cnt = kiko.storage.get(app._STORAGE_chatgpt_req_sub_cnt) or app.translator:get_req_sub_cnt()
    app.translator:set_req_sub_cnt(req_sub_cnt)
    kiko.ui.get("chatgpt_sub_cnt_textline"):setopt("text", req_sub_cnt)
    
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
end

app.close = function(param)
    local window_config = {
        w = app.w:getopt("w"),
        h = app.w:getopt("h"),
        pinned = app.w:getopt("pinned"),
    }
    kiko.storage.set("window_config", window_config)
    kiko.storage.set(app._STORAGE_tran_only_miss, kiko.ui.get("sub_trans_miss_check"):getopt("checked"))
    kiko.storage.set(app._STORAGE_cuda_whisper, kiko.ui.get("cuda_whisper_check"):getopt("checked"))
    if app.prompt_changed then
        local prompt = kiko.ui.get("prompt_text"):getopt("text")
        kiko.storage.set(app._STORAGE_chatgpt_prompt, prompt)
        app.prompt_changed = false
    end
    return true
end

app.onContentPageBtnClick = function(param)
    kiko.ui.get("content_sview"):setopt("current_index", param["src"]:data("idx"))
end

app.onMainPageBtnClick = function(param)
    kiko.ui.get("main_sview"):setopt("current_index", param["src"]:data("idx"))
end

app.onBrowseWhisperModel = function(param)
    local filename = kiko.dialog.openfile({
        title="选择whisper模型文件",
        filter="model (*.bin)",
        multi = false
    })
    if filename ~= nil then
        kiko.storage.set(app._STORAGE_whisper_model, filename)
        kiko.ui.get("whisper_model_textline"):setopt("text", filename)
    end
end

app.onAPIKeyChanged = function(param)
    local key = string.trim(param["text"])
    if #key > 0 then
        kiko.storage.set(app._STORAGE_chatgpt_api, key)
    end
end

app.onVideoLangChanged = function(param)
    local lang = string.trim(param["text"])
    if #lang > 0 then
        kiko.storage.set(app._STORAGE_video_lang, lang)
    end
end

app.onReqSubCntChanged = function(param)
    local cnt = tonumber(string.trim(param["text"]))
    if cnt ~= nil and cnt > 0 then
        kiko.storage.set(app._STORAGE_chatgpt_req_sub_cnt, cnt)
        app.translator:set_req_sub_cnt(cnt)
    end
end

app.onWhisperModelChanged = function(param)
    local model = string.trim(param["text"])
    if #model > 0 then
        kiko.storage.set(app._STORAGE_whisper_model, model)
    end
end

app.onPromptTextChanged = function(param)
    app.prompt_changed = true
end

app.onSaveSubComboChanged = function(param)
    if param["index"] == 0 then return end
    kiko.storage.set(app._STORAGE_save_sub_type, param["index"])
end

app.onPlayerOpenFile = function(param)
    local filename = kiko.dialog.openfile({
        title="选择文件",
        filter="all (*.*)",
        multi = false
    })
    if filename ~= nil then
        app.player:command({"loadfile", filename})
        app.cur_video_file = filename
    end
end

app.onOpenKikoPlayFile = function(param)
    local cur_file = kiko.player.curfile()
    if cur_file == nil then
        return
    end
    app.player:command({"loadfile", cur_file})
    app.cur_video_file = cur_file
end

app.onOpenSubFile = function(param)
    local filename = kiko.dialog.openfile({
        title="选择文件",
        filter="srt sub (*.srt)",
        multi = false
    })
    if filename ~= nil then
        local sub_res = app.recognizer:load_srt(string.encode(filename, string.CODE_UTF8 ,string.CODE_LOCAL))
        if sub_res ~= nil and #sub_res > 0 then
            app.refresh_sub_list(sub_res)
            app.cur_saved_sub_file = filename
        else
            app.w:message("字幕文件打开失败", kiko.msg.NM_ERROR | kiko.msg.NM_HIDE)
        end
    end
end

app.onPlayerPlayPause = function(param)
    app.player:command({"cycle", "pause"})
end

app.onPlayerDurationChanged = function(param)
    local duration = param["duration"] * 1000  -- ms
    app.pos_slider:setopt("max", duration)
    local mm, ss = math.modf(duration / 1000) // 60, math.modf(duration / 1000) % 60
    app.cur_duration = string.format("%02d:%02d", mm, ss)
    app.pos_label:setopt("title", string.format("00:00/%s", app.cur_duration))
end

app.onPlayerPosChanged = function(param)
    local pos = param["pos"] * 1000  -- ms
    app.pos_slider:setopt("value", pos)
    local mm, ss = math.modf(pos / 1000) // 60, math.modf(pos / 1000) % 60
    app.pos_label:setopt("title", string.format("%02d:%02d/%s", mm, ss, app.cur_duration))
end

app.onPosSliderMoved = function(param)
    local pos = param["value"] / 1000.0
    app.player:command({"seek", pos, "absolute"})
    local mm, ss = math.modf(pos / 1000) // 60, math.modf(pos / 1000) % 60
    app.pos_label:setopt("title", string.format("%02d:%02d/%s", mm, ss, app.cur_duration))
end

app.onVolumeChanged = function(param)
    app.player:command({"set", "volume", string.format("%d", param["value"])})
    kiko.storage.set(app._STORAGE_volume, param["value"])
end

app.onStartRecognize = function(param)
    if app.cur_video_file == nil then return end
    local model = kiko.storage.get(app._STORAGE_whisper_model)
    if model == nil then
        app.w:message("请在设置中指定whisper模型文件", kiko.msg.NM_ERROR | kiko.msg.NM_HIDE)
        return
    end
    local translate_btn = kiko.ui.get("translate_btn")
    local open_sub_btn = kiko.ui.get("open_sub_btn")
    open_sub_btn:setopt("enable", false)
    param["src"]:setopt("enable", false)
    translate_btn:setopt("enable", false)
    local whisper_options = {
        model = model,
        use_cuda = kiko.ui.get("cuda_whisper_check"):getopt("checked"),
        lang = kiko.storage.get(app._STORAGE_video_lang) or "auto",
    }
    local status_text = kiko.ui.get("status_text")
    status_text:clear()
    kiko.ui.get("c_page_2"):setopt("checked", true)
    kiko.ui.get("content_sview"):setopt("current_index", 2)
    local finish_cb = function(sub_list)
        param["src"]:setopt("enable", true)
        translate_btn:setopt("enable", true)
        open_sub_btn:setopt("enable", true)
        if sub_list ~= nil and #sub_list > 0 then
            app.refresh_sub_list(sub_list)
            kiko.ui.get("c_page_1"):click()
        end
    end
    app.recognizer:recognize(app.cur_video_file, whisper_options, function(text) status_text:append(text, true) end, finish_cb)
end

app.refresh_sub_list = function(sub_list)
    app.sub_list_tree:clear()
    app.cur_sub_res = sub_list
    app.cur_saved_sub_file = nil
    for _, item in ipairs(sub_list) do
        app.sub_list_tree:append({
            {
                {text=item.time_start,edit=true },
                {text=item.time_end,edit=true },
                {text=item.content,edit=true },
            }
        })
    end
end

app.onStartTranslate = function(param)
    if app.cur_sub_res == nil then return end
    local api_key = kiko.storage.get(app._STORAGE_chatgpt_api)
    if api_key == nil then 
        app.w:message("请先在设置中设置ChatGPT API Key", kiko.msg.NM_ERROR | kiko.msg.NM_HIDE)
        return
    end
    local recognize_btn = kiko.ui.get("recognize_btn")
    local open_sub_btn = kiko.ui.get("open_sub_btn")
    open_sub_btn:setopt("enable", false)
    recognize_btn:setopt("enable", false)
    param["src"]:setopt("enable", false)
    local status_text = kiko.ui.get("status_text")
    status_text:clear()
    kiko.ui.get("c_page_2"):setopt("checked", true)
    kiko.ui.get("content_sview"):setopt("current_index", 2)
    if app.prompt_changed then
        local prompt = kiko.ui.get("prompt_text"):getopt("text")
        kiko.storage.set(app._STORAGE_chatgpt_prompt, prompt)
        app.prompt_changed = false
        app.translator:set_prompt(prompt)
    end
    local fill_nil = kiko.ui.get("sub_trans_miss_check"):getopt("checked")
    app.translator:sep_api_key(api_key)
    app.translator:translate_sub(app.cur_sub_res, function(text) status_text:append(text, true) end, fill_nil)
    for i, item in ipairs(app.cur_sub_res) do
        if item.translate_content ~= nil then
            local tree_item = app.sub_list_tree:item(i)
            tree_item:set(4, "text", item.translate_content)
            tree_item:set(4, "edit", true)
        end
    end
    app.cur_saved_sub_file = nil
    kiko.ui.get("c_page_1"):click()
    param["src"]:setopt("enable", true)
    recognize_btn:setopt("enable", true)
    open_sub_btn:setopt("enable", true)
end 

app.onMenuClick = function(param)
    if param.id == "m_remove" then
        local sels = app.sub_list_tree:selection()
        if #sels == 0 then return end
        local item = sels[1]
        local idx = app.sub_list_tree:indexof(item)
        table.remove(app.cur_sub_res, idx)
        app.sub_list_tree:remove(item)
        app.cur_saved_sub_file = nil
    elseif param.id == "m_seek" then
        local sels = app.sub_list_tree:selection()
        if #sels == 0 then return end
        local item = sels[1]
        local idx = app.sub_list_tree:indexof(item)
        local seek_time = app.cur_sub_res[idx].time_start
        local time_reg = kiko.regex("(\\d+):(\\d+):(\\d+).(\\d+)")
        local t, e, hh, mm, ss, ms = time_reg:find(seek_time)
        if t ~= nil and e ~= nil then
            local pos = tonumber(hh)*3600+tonumber(mm)*60+tonumber(ss)+tonumber(ms)/1000
            app.player:command({"seek", pos, "absolute"})
            app.onPlayerPosChanged({pos=pos})
        end
    end
end

app.onTreeSubItemChanged = function(param)
    local item = param["item"]
    local idx = app.sub_list_tree:indexof(item)
    if app.cur_sub_res == nil then return end
    local col = param["col"]
    local content = item:get(col, "text")
    if col == 1 then
        app.cur_sub_res[idx].time_start = content
    elseif col == 2 then
        app.cur_sub_res[idx].time_end = content
    elseif col == 3 then
        app.cur_sub_res[idx].content = content
    elseif col == 4 then
        app.cur_sub_res[idx].translate_content = content
    end
end

app.onSaveSub = function(param)
    if app.cur_sub_res == nil then return end
    local from_path = app.cur_video_file
    if from_path == nil then
        from_path = app.cur_saved_sub_file
    end
    local pos = string.lastindexof(from_path, "/")
    if pos == -1 then
        pos = string.lastindexof(from_path, "\\")
    end
    local path = nil
    if pos ~= -1 then
        path = string.sub(from_path, 1, pos)
    end
    local save_type = kiko.storage.get(app._STORAGE_save_sub_type)
    if save_type == nil then
        save_type = 1
    end

    local filename = kiko.dialog.savefile({
        title="保存字幕文件",
        filter="SRT Sub (*.srt)",
        path=path,
    })
    if filename ~= nil then
        app.save_srt(filename, app.cur_sub_res, save_type)
        app.cur_saved_sub_file = filename
    end
end

app.save_srt = function(filename, sub_list, save_type)
    file = io.open(string.encode(filename, string.CODE_UTF8 ,string.CODE_LOCAL), "w")
    for i, item in ipairs(sub_list) do
        file:write(string.format("%d\n", i))
        file:write(string.format("%s --> %s\n", item.time_start, item.time_end))
        if save_type == 1 then -- 双语
            if item.translate_content ~= nil then
                file:write(string.format("%s\n%s\n\n", item.content, item.translate_content))
            else
                file:write(string.format("%s\n\n", item.content))
            end
        elseif save_type == 2 then  -- 原始识别
            file:write(string.format("%s\n\n", item.content))
        else  -- 翻译
            file:write(string.format("%s\n\n", item.translate_content))
        end
    end
    file:close()
end

app.onJumpSub = function(param)
    if app.cur_sub_res == nil then return end
    local time_reg = kiko.regex("(\\d+):(\\d+):(\\d+).(\\d+)")
    local pos = app.pos_slider:getopt("value") / 1000
    for i, item in ipairs(app.cur_sub_res) do
        local t, e, hh, mm, ss, ms = time_reg:find(item.time_end)
        if t ~= nil and e ~= nil then
            local sub_pos = tonumber(hh)*3600+tonumber(mm)*60+tonumber(ss)+tonumber(ms)/1000
            if sub_pos >= pos then
                app.sub_list_tree:item(i):scrollto()
                return
            end
        end
    end
end

app.onLoadToKikoPlay = function(param)
    if app.cur_saved_sub_file == nil then
        app.w:message("请先保存字幕文件", kiko.msg.NM_ERROR | kiko.msg.NM_HIDE)
        return
    end
    if kiko.player.curfile() == nil then
        app.w:message("KikoPlay当前无正在播放的文件", kiko.msg.NM_ERROR | kiko.msg.NM_HIDE)
        return
    end
    kiko.player.command({"sub-add", app.cur_saved_sub_file, "cached"})
end

