
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
    if param.scene ~= kiko.launch_scene.AUTO_START then
        w:show()
    end
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
        ep_finish_update_item_checked = kiko.ui.get("ep_finish_update_item_check"):getopt("checked"),
        is_private = kiko.ui.get("private_collection_check"):getopt("checked"), 
    })
    app.bgm.save_info()
    return true
end

app.onPageNavigate = function(param)
    local s_view = kiko.ui.get("list_setting_sview")
    s_view:setopt("current_index", param["src"]:data("idx"))
end

app.set_info_page = function()
    app.refresh_avatar()
    app.set_user_name_info()

    local count = #app.bgm.user_info.hist_records
    for i = count, 1, -1 do
        local item = app.bgm.user_info.hist_records[i]
        local status = item.status or ""
        -- 旧版本存储的失败状态文本里没有重试链接，加载时补上
        if item.retry ~= nil and string.find(status, 'href="retry"', 1, true) == nil then
            status = status .. " " .. app.RETRY_LINK
            item.status = status
        end
        local _, s_lb = app.push_collection_item(false, item.record, status)
        app.bind_retry(s_lb, i)
    end

    local check_status = kiko.storage.get("check_status") or {
        add_library_checked=true, 
        item_update_checked=true, 
        ep_finish_checked=true, 
        is_private=false,
        ep_finish_update_item_checked=false,
    }
    kiko.ui.get("add_library_check"):setopt("checked", check_status.add_library_checked)
    kiko.ui.get("item_update_check"):setopt("checked", check_status.item_update_checked)
    kiko.ui.get("ep_finish_check"):setopt("checked", check_status.ep_finish_checked)
    kiko.ui.get("private_collection_check"):setopt("checked", check_status.is_private)
    kiko.ui.get("ep_finish_update_item_check"):setopt("checked", check_status.ep_finish_update_item_checked)
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
            local update_item = kiko.ui.get("ep_finish_update_item_check"):getopt("checked")
            kiko.log("ep finish: ", anime_name, ep_info)
            if anime_name ~= nil and ep_info ~= nil and ep_info.type == kiko.anime.EP_TYPE_EP then
                app.bgm.ep_finish(anime_name, ep_info, private, update_item)
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
            <label id="item_status_label" open_link="false" text_selectable="true" />
        </vview>
    ]])
    local text_lb = view:getchild("item_text_label")
    local status_lb = view:getchild("item_status_label")
    text_lb:setopt("title", content)
    status_lb:setopt("title", status)
    return text_lb, status_lb
end

-- 失败状态文本里内嵌的重试链接，点击触发 link_click。作为状态文本的一部分，
-- 不会改变条目高度，避免按钮控件带来的高度测量问题。
-- 样式与条目标题里的 bgm.tv 链接写法一致（已被验证可正常渲染）。
app.RETRY_LINK = [[<a style='color: rgb(96, 208, 252);' href="retry">重试</a>]]

-- 绑定状态标签的 link_click：点击 href="retry" 链接时派发重试。
-- 点击时动态读取 hist_records[title_idx].retry，因此无论失败多少次、是否重启，
-- 同一 handler 始终拿到最新参数。
app.bind_retry = function(s_lb, title_idx)
    if s_lb == nil then return end
    s_lb:onevent("link_click", function(param)
        if param.link ~= "retry" then return end
        local rec = app.bgm.user_info.hist_records[title_idx]
        if rec == nil or rec.retry == nil then return end
        app.do_retry(rec.retry, s_lb, title_idx)
    end)
end

-- 派发重试，复用同一条目的 s_lb / title_idx，不新建列表项
app.do_retry = function(retry_info, s_lb, title_idx)
    if retry_info == nil then return end
    local ctx = {
        s_lb = s_lb,
        title_idx = title_idx,
        bgm_id = retry_info.bgm_id,
    }
    if retry_info.type == "collection" then
        app.bgm.add_collection(retry_info.bgm_id, retry_info.anime_name,
            retry_info.is_private, retry_info.collection_type, nil, ctx)
    elseif retry_info.type == "ep_finish" then
        app.bgm.ep_finish(retry_info.anime_name, retry_info.ep_info,
            retry_info.is_private, retry_info.update_item, ctx)
    end
end

-- 标记重试条目结束（成功或不可恢复失败）：更新状态文本、清空 retry 并落盘
app.mark_retry_done = function(retry_ctx, status_text)
    if retry_ctx == nil then return end
    if retry_ctx.s_lb ~= nil then retry_ctx.s_lb:setopt("title", status_text) end
    local rec = app.bgm.user_info.hist_records[retry_ctx.title_idx]
    if rec ~= nil then
        rec.status = status_text
        rec.retry = nil
    end
    kiko.storage.set("bgm_user_info", app.bgm.user_info)
end
