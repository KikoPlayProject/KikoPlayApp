
app = {
    timer = nil,
    running = false,
    interval = 10000,
    cur_watch_duration = 0,
    tip_duration = 0,
}

app.loaded = function(param)
    local w = param["window"]
    app.w = w
    
    local duration = kiko.storage.get("tip_duration") or 60
    kiko.ui.get("duration_text"):setopt("text", duration)
    app.tip_duration = duration * 60 * 1000  --ms

    local auto_start = kiko.storage.get("auto_start_check") or false
    kiko.ui.get("auto_start_check"):setopt("checked", auto_start)

    local tip_text = kiko.storage.get("tip_text") or "你已经观看一段时间了，休息一下吧~"
    kiko.ui.get("tip_text"):setopt("text", tip_text)
    app.tip_text = tip_text

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

    if param.scene ~= kiko.launch_scene.AUTO_START then
        w:show()
    end
    if auto_start then
        app.run()
    end
end

app.close = function(param)
    kiko.storage.set("window_config", {
        w = app.w:getopt("w"),
        h = app.w:getopt("h"),
        pinned = app.w:getopt("pinned"),
    })
    local duration = tonumber(kiko.ui.get("duration_text"):getopt("text"))
    if duration and duration > 0 then
        kiko.storage.set("tip_duration", duration)
    end
    kiko.storage.set("auto_start_check",  kiko.ui.get("auto_start_check"):getopt("checked"))
    return true
end

app.is_watching = function()
    local _, is_pause = kiko.player.property("pause")
    return kiko.player.curfile() ~= nil and not is_pause
end

app.run = function()
    if app.timer == nil then
        app.timer = kiko.timer.create(app.interval)
        app.timer:ontimeout(function()
            if not app.is_watching() then return end
            app.cur_watch_duration = app.cur_watch_duration + app.interval
            if app.cur_watch_duration >= app.tip_duration then
                kiko.gtip({
                    message = app.tip_text,
                    group = "eye_tip",
                    showclose = true,
                    timeout = 5000,
                    bg = 0xf0135f4d
                })
                app.cur_watch_duration = 0
            end   
        end)
    end
    kiko.ui.get("start_btn"):setopt("title", "停止提醒")
    kiko.ui.get("duration_text"):setopt("enable", false)
    kiko.ui.get("tip_text"):setopt("enable", false)
    app.timer:start()
    app.running = true
end

app.stop = function()
    if app.timer == nil then return end
    app.cur_watch_duration = 0
    kiko.ui.get("start_btn"):setopt("title", "开启提醒")
    kiko.ui.get("duration_text"):setopt("enable", true)
    kiko.ui.get("tip_text"):setopt("enable", true)
    app.timer:stop()
    app.running = false
end

app.onStartBtnClick = function(param)
    local duration = tonumber(kiko.ui.get("duration_text"):getopt("text"))
    if duration == nil or duration <= 0 then
        app.w:message("提醒间隔错误", kiko.msg.NM_HIDE | kiko.msg.NM_ERROR)
        return
    end
    app.tip_duration = duration * 60 * 1000  -- ms
    app.tip_text = kiko.ui.get("tip_text"):getopt("text")
    if app.running then
        app.stop()
    else
        app.run()
    end
end

app.onPreviewBtnClick = function(param)
    kiko.gtip({
        message = app.tip_text,
        group = "eye_tip",
        showclose = true,
        bg = 0xf0135f4d
    })
end

