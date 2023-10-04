app = {
    tmp_files = {},
    record_loaded = false,
}


app.loaded = function(param)
    app.page = kiko.ui.get("page")
    app.task_list = kiko.ui.get("task_list")
    local w = param["window"]
    app.w = w

    app.search = require "pages/page_search"
    app.download_list = require "download_list"

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
    w:setstyle(env.app_path .. "/style.qss")
    w:show() 
end

app.close = function(param)
    local window_config = {
        w = app.w:getopt("w"),
        h = app.w:getopt("h"),
        pinned = app.w:getopt("pinned"),
    }
    kiko.storage.set("window_config", window_config)
    for _, file in ipairs(app.tmp_files) do
        os.remove(string.encode(file, string.CODE_UTF8 ,string.CODE_LOCAL))
    end
    app.download_list.save_record()
    return true
end

app.onPageBtnClick = function(param)
    app.page:setopt("current_index", param["src"]:data("idx"))
    if param["src"]:data("idx") == "2" and not app.record_loaded then
        app.w:message("正在加载...", kiko.msg.NM_PROCESS | kiko.msg.NM_DARKNESS_BACK)
        app.download_list.load_list()
        app.w:message("正在加载...", kiko.msg.NM_HIDE)
        app.record_loaded = true
    end
end


