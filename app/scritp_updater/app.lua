
app = {
    update_url = "https://raw.githubusercontent.com/KikoPlayProject/KikoPlayScript/master/meta.json",
}

app.loaded = function(param)
    app.Updater = require "updater"
    local w = param["window"]
    app.w = w

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
    kiko.storage.set("window_config", {
        w = app.w:getopt("w"),
        h = app.w:getopt("h"),
        pinned = app.w:getopt("pinned"),
    })
    return true
end

app.onPageBtnClick = function(param)
    local page = kiko.ui.get("wpage")
    page:setopt("current_index", param["src"]:data("idx"))
end

app.onCheckUpdateBtnClick = function(param)
    app.w:message("获取信息中...", kiko.msg.NM_PROCESS | kiko.msg.NM_DARKNESS_BACK)
    local err, reply = kiko.net.httpget(app.update_url, {}, {})
    if err ~= nil then
        app.w:message(string.format("获取信息失败: %s", err), kiko.msg.NM_HIDE | kiko.msg.NM_ERROR)
        return
    end
    local err, obj = kiko.json2table(reply["content"])
    if err ~= nil then
        app.w:message(string.format("json解析失败: %s", err), kiko.msg.NM_HIDE | kiko.msg.NM_ERROR)
        return
    end
    local update_scripts, new_scripts = app.check_update(obj)
    app.set_update_scripts(update_scripts)
    app.set_new_scripts(new_scripts)
    app.w:message("获取完成", kiko.msg.NM_HIDE)
end

app.is_new_version = function(cur_version, remote_version)
    local cv = string.split(cur_version, ".")
    local rv = string.split(remote_version, ".")
    if #cv ~= #rv then
        local t = cv
        local pad_len = #rv - #cv
        if #cv > #rv then 
            t = rv
            pad_len = -pad_len
        end
        for i = 1, pad_len do
            table.insert(t, "0")
        end
    end
    for i = 1, #cv do 
        local cv_i = tonumber(cv[i])
        local rv_i = tonumber(rv[i])
        if cv_i == nil or rv_i == nil then 
            return false 
        end
        if cv_i < rv_i then
            return true
        elseif cv_i > rv_i then
            return false
        end
    end
    return false
end

app.is_match_kiko_version = function(min_kiko_version)
    local cur_kiko_version = env.kikoplay
    return not app.is_new_version(cur_kiko_version, min_kiko_version)
end

app.check_update = function(remote_scripts)
    local rs_map = {}
    for _, s in pairs(remote_scripts) do
        rs_map[s.id] = s
    end
    local all_scripts = kiko.allscripts()
    local ls_map = {}
    local update_scripts = {}
    for _, s in pairs(all_scripts) do
        ls_map[s.id] = s
        local rs = rs_map[s.id]
        if rs ~= nil and app.is_new_version(s.version, rs.version) then
            table.insert(update_scripts, {s, rs})
        end
    end
    local new_scripts = {}
    local valid_type = {
        ["danmu"] = 0,
        ["library"] = 1,
        ["resource"] = 2,
        ["bgm_calendar"] = 3,
    }
    for _, s in pairs(remote_scripts) do
        if ls_map[s.id] == nil and valid_type[s.type] ~= nil then
            s["type_id"] = valid_type[s.type]
            table.insert(new_scripts, s)
        end
    end
    return update_scripts, new_scripts
end

app.set_update_scripts = function(update_scripts)
    local own_list = kiko.ui.get("list_own_scripts")
    own_list:clear()
    local tip_btn = kiko.ui.get("w_page_btn_install")
    if #update_scripts == 0 then
        tip_btn:setopt("title", "已安装(0)")
        return
    end
    tip_btn:setopt("title", string.format("已安装(%d)", #update_scripts))
    local script_type_strs = {"弹幕脚本", "资料库脚本", "资源脚本", "日历脚本"}
    for _, s in pairs(update_scripts) do
        local ls, rs = s[1], s[2]
        local idx = own_list:append("")
        local view = own_list:setview(idx, string.format([[
            <hview> 
                <vview content_margin="0,0,0,0" view-depend:trailing-stretch="1">
                    <label id="lb_title" /> 
                    <label id="lb_version" title="%s → %s" />
                    <label id="lb_desc" title="%s" word_wrap="true" open_link="true" text_selectable="true" h_size_policy="fix" min_w="400" />
                </vview> 
                <button id="btn" title="更新" />
            </hview>
            ]], ls.version, rs.version, rs.desc))
        local lb_title = view:getchild("lb_title")
        lb_title:setopt("title", string.format([[
            <b> %s </b> <small> (%s) </small>
        ]], ls.name, script_type_strs[ls.type+1]))
        local btn = view:getchild("btn")
        btn:onevent("click", function(param)
            local updater = app.Updater:new({
                ["ls"] = ls,
                ["rs"] = rs,
                ["btn"] = param.src
            })
            updater:update()
        end)
        if not app.is_match_kiko_version(rs.min_kiko) then
            btn:setopt("enable", false)
            btn:setopt("title", "当前KikoPlay版本过低")
        end
    end
end

app.set_new_scripts = function(new_scripts)
    local new_list = kiko.ui.get("list_new_scripts")
    new_list:clear()
    local tip_btn = kiko.ui.get("w_page_btn_new")
    if #new_scripts == 0 then
        tip_btn:setopt("title", "未安装(0)")
        return
    end
    tip_btn:setopt("title", string.format("未安装(%d)", #new_scripts))
    local script_type_strs = {"弹幕脚本", "资料库脚本", "资源脚本", "日历脚本"}
    for _, s in pairs(new_scripts) do
        local idx = new_list:append("")
        local view = new_list:setview(idx, string.format([[
            <hview> 
                <vview content_margin="0,0,0,0" view-depend:trailing-stretch="1">
                    <label id="lb_title" /> 
                    <label id="lb_version" title="%s" />
                    <label id="lb_desc" title="%s" word_wrap="true" open_link="true" text_selectable="true" h_size_policy="fix" min_w="400" />
                </vview> 
                <button id="btn" title="下载" />
            </hview>
            ]], s.version, s.desc))
        local lb_title = view:getchild("lb_title")
        lb_title:setopt("title", string.format([[
            <b> %s </b> <small> (%s) </small>
        ]], s.name, script_type_strs[s.type_id+1]))
        local btn = view:getchild("btn")
        btn:onevent("click", function(param)
            local updater = app.Updater:new({
                ["rs"] = s,
                ["btn"] = param.src,
                ["is_download"] = true,
            })
            updater:update()
        end)
        if not app.is_match_kiko_version(s.min_kiko) then
            btn:setopt("enable", false)
            btn:setopt("title", "当前KikoPlay版本过低")
        end
    end
end
