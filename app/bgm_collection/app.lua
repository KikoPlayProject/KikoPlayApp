
app = {}

app.loaded = function(param)
    local w = param["window"]
    app.w = w
    app.page = kiko.ui.get("m_sview")
    app.collection_hist_list = kiko.ui.get("collection_hist_list")

    app.bgm = require "bgm_api"
    
    kiko.ui.get("logo"):setimg(env.app_path .. "/logo.png")
    kiko.ui.get("access_token_text"):setopt("text", kiko.storage.get("input_access_token") or "")

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
    
    if app.bgm.load_info() then
        app.set_info_page()
        app.check_user_info()
        app.page:setopt("current_index", 2)
    end
    w:show()
end

app.close = function(param)
    kiko.storage.set("window_config", {
        w = app.w:getopt("w"),
        h = app.w:getopt("h"),
        pinned = app.w:getopt("pinned"),
    })
    kiko.storage.set("check_status", {
        add_library_checked = kiko.ui.get("add_library_check"):getopt("checked"),
        item_update_checked = kiko.ui.get("item_update_check"):getopt("checked"), 
        ep_finish_checked = kiko.ui.get("ep_finish_check"):getopt("checked"), 
        is_private = kiko.ui.get("private_collection_check"):getopt("checked"), 
    })
    app.bgm.save_info()
    return true
end

app.set_info_page = function()
    app.refresh_avatar()
    app.set_user_name_info()

    local count = #app.bgm.user_info.hist_records
    for i = count, 1, -1 do
        local item = app.bgm.user_info.hist_records[i]
        app.push_collection_item(false, item.record, item.status)
    end

    local check_status = kiko.storage.get("check_status") or {
        add_library_checked=true, item_update_checked=true, ep_finish_checked=true, is_private=false
    }
    kiko.ui.get("add_library_check"):setopt("checked", check_status.add_library_checked)
    kiko.ui.get("item_update_check"):setopt("checked", check_status.item_update_checked)
    kiko.ui.get("ep_finish_check"):setopt("checked", check_status.ep_finish_checked)
    kiko.ui.get("private_collection_check"):setopt("checked", check_status.is_private)
end

app.refresh_avatar = function()
    local avatar_info = kiko.storage.get("avatar_info")
    if avatar_info == nil or avatar_info.url ~= app.bgm.user_info.avatar then
        local err, reply = kiko.net.httpget(app.bgm.user_info.avatar)
        if err == nil then
            avatar_info = {
                data = reply.content,
                url = app.bgm.user_info.avatar
            }
            kiko.storage.set("avatar_info", avatar_info)
        end
    end
    local img = kiko.ui.createimg({
        data = avatar_info.data
    })
    if img ~= nil then
        local avatar_label = kiko.ui.get("avatar")
        avatar_label:setimg(img)
    end
end

app.set_user_name_info = function()
    local user_home_page = string.format("https://bgm.tv/user/" .. tostring(math.floor(app.bgm.user_info.uid)))
    local nickname_label = kiko.ui.get("nickname") 
    nickname_label:setopt("title", string.format("<h4><a style='color: rgb(96, 208, 252);' href=\"%s\">%s</a></h4>", user_home_page, app.bgm.user_info.nickname))
    local sign_label = kiko.ui.get("sign") 
    sign_label:setopt("title", "还没有签名~")
    if #app.bgm.user_info.sign > 0 then
        sign_label:setopt("title", app.bgm.user_info.sign)
    end
end

app.check_user_info = function()
    bgm_api.check_user_info(function(err)
        local sign_label = kiko.ui.get("sign") 
        sign_label:setopt("title", string.format("<small style='color: rgb(252, 96, 125);'>Access Token可能失效: %s</small>", err))
    end)
end

app.onLoginBtnClick = function(param)
    local access_token = kiko.ui.get("access_token_text"):getopt("text")
    if #access_token == 0 then
        app.w:message("Access Token不能为空", kiko.msg.NM_HIDE | kiko.msg.NM_ERROR)
        return
    end
    app.w:message("获取信息中...", kiko.msg.NM_PROCESS | kiko.msg.NM_DARKNESS_BACK)
    kiko.storage.set("input_access_token", access_token)
    local err = app.bgm.login(access_token)
    if err ~= nil then
        app.w:message(err, kiko.msg.NM_HIDE | kiko.msg.NM_ERROR)
        return
    end
    
    app.set_info_page()
    app.w:message("获取信息中...", kiko.msg.NM_HIDE)
    app.page:setopt("current_index", 2)
end

app.onLogoutBtnClick = function(param)
    app.bgm.logout()
    app.page:setopt("current_index", 1)
    app.collection_hist_list:clear()
end

app.onSceneCheckChanged = function(param)
    local event_map = {
        ["add_library_check"] = kiko.event.EVENT_LIBRARY_ANIME_ADDED,
        ["item_update_check"] = kiko.event.EVENT_LIBRARY_ANIME_UPDATED,
        ["ep_finish_check"] = kiko.event.EVENT_LIBRARY_EP_FINISH,
    }
    local event = event_map[param.srcId]
    if event == nil then return end

    app.setListenEvent(event, param.state == 2)
end

app.setListenEvent = function(event, enable)
    if not enable then
        kiko.event.unlisten(event)
        return
    end
    if event == kiko.event.EVENT_LIBRARY_ANIME_ADDED or event == kiko.event.EVENT_LIBRARY_ANIME_UPDATED then
        kiko.event.listen(event, function(anime)
            if anime.scriptId == "Kikyou.l.Bangumi" and #anime.data > 0 then
                local bgmId = tostring(anime.data)
                local anime_name = anime.name
                local collection_type = 3
                local private = kiko.ui.get("private_collection_check"):getopt("checked")
                app.bgm.add_collection(bgmId, anime_name, private, collection_type, nil)
            end
        end)
    elseif event == kiko.event.EVENT_LIBRARY_EP_FINISH then
        kiko.event.listen(event, function(info)
            local anime_name = info.anime_name
            local ep_info = info.epinfo
            local private = kiko.ui.get("private_collection_check"):getopt("checked")
            if anime_name ~= nil and ep_info ~= nil and ep_info.type == kiko.anime.EP_TYPE_EP then
                app.bgm.ep_finish(anime_name, ep_info, private)
            end
        end)
    end
end

app.push_collection_item = function(is_front, content, status)
    local idx = -1
    if is_front then
        idx = 1
        app.collection_hist_list:insert(1, "")
    else
        idx = app.collection_hist_list:append("")
    end
    local view = app.collection_hist_list:setview(idx, [[
        <vview>
            <label id="item_text_label" word_wrap="true" open_link="true" text_selectable="true" />
            <label id="item_status_label" open_link="true" text_selectable="true" />
        </vview>
    ]])
    local text_lb = view:getchild("item_text_label")
    local status_lb = view:getchild("item_status_label")
    text_lb:setopt("title", content)
    status_lb:setopt("title", status)
    return text_lb, status_lb
end
