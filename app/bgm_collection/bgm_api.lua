bgm_api = {
    is_login = false,
    ep_cache = {}
}

bgm_api.load_info = function()
    local user_info = kiko.storage.get("bgm_user_info")
    local access_token = kiko.storage.get("bgm_access_token")
    if user_info ~= nil and access_token ~= nil then
        bgm_api.access_token = access_token
        bgm_api.user_info = user_info
        bgm_api.is_login = true
        return true
    end
    return false
end

bgm_api.save_info = function()
    kiko.storage.set("bgm_access_token", bgm_api.access_token)
    local r = bgm_api.user_info.hist_records
    local max_hist_records = 30
    if #r > max_hist_records then
        local t = {}
        for i = #r-max_hist_records+1, #r do
            table.insert(t, r[i])
        end 
        bgm_api.user_info.hist_records = t
    end
    kiko.storage.set("bgm_user_info", bgm_api.user_info)
end

bgm_api.login = function(access_token)
    local header = {
        ["Accept"]="application/json",
        ["Authorization"]="Bearer " .. access_token,
        ["User-Agent"] = "KikoPlay-ExtensionApp"
    }
    local err, reply = kiko.net.httpget("https://api.bgm.tv/v0/me", {}, header)
    if err ~= nil then return err end
    local content = reply["content"]
    local err, obj = kiko.json2table(content)
    if err ~= nil then return err end
    if bgm_api.user_info ~= nil and obj.username == bgm_api.user_info.username then
        bgm_api.user_info.avatar = obj.avatar.medium
        bgm_api.user_info.nickname = obj.nickname
        bgm_api.user_info.sign = obj.sign
    else
        bgm_api.user_info = {
            avatar = obj.avatar.medium,
            username = obj.username,
            nickname = obj.nickname,
            uid = math.floor(obj.id),
            sign = obj.sign,
            collection_bgm_ids = {},
            hist_records = {},
        }
    end
    bgm_api.access_token = access_token
    bgm_api.is_login = true
    return nil
end

bgm_api.check_user_info = function(err_func)
    kiko.net.request({
        method = "get",
        url = "https://api.bgm.tv/v0/me",
        header = {
            ["Accept"]="application/json",
            ["Authorization"]="Bearer " .. bgm_api.access_token,
            ["User-Agent"] = "KikoPlay-ExtensionApp"
        },
        success = function(reply)
            local content = reply:content()
            local err, obj = kiko.json2table(content)
            if err ~= nil then return end
            if bgm_api.user_info.avatar ~= obj.avatar.medium then
                bgm_api.user_info.avatar = obj.avatar.medium
                app.refresh_avatar()
            end
            if bgm_api.user_info.nickname ~= obj.nickname or bgm_api.user_info.sign ~= obj.sign then
                bgm_api.user_info.nickname = obj.nickname
                bgm_api.user_info.sign = obj.sign
                app.set_user_name_info()
            end
        end,
        error = function(reply)
            err_func(reply:error())
        end
    })
end

bgm_api.logout = function()
    bgm_api.access_token = nil
    bgm_api.is_login = false
end

bgm_api.get_ep = function(bgmId, ep_info, succ_func, err_func)
    if bgm_api.ep_cache[bgmId] ~= nil then
        local max_sort = 0
        for _, ep in ipairs(bgm_api.ep_cache[bgmId]) do
            if ep.idx > max_sort then max_sort = ep.idx end
        end
        for _, ep in ipairs(bgm_api.ep_cache[bgmId]) do
            if ep.idx == ep_info.index then
                if succ_func ~= nil then succ_func(tostring(ep.ep_id), ep.idx == max_sort) end
                return
            end
        end
    end
    local ep_index = ep_info.index
    if math.floor(ep_index) == ep_index then ep_index = math.floor(ep_index) end
    local page = math.ceil(ep_index / 100) - 1
    if page < 0 then page = 0 end
    kiko.net.request({
        method = "get",
        url = "https://api.bgm.tv/v0/episodes",
        header = {
            ["accept"]="application/json",
        },
        query = {
            ["subject_id"] = bgmId,
            ["type"] = 0,
            ["offset"] = page,
            ["limit"] = 100,
        },
        success = function(reply)
            local content = reply:content()
            local err, obj = kiko.json2table(content)
            if err ~= nil then
                err_func(err)
                return
            end
            local ep_list = {}
            local target_ep = nil
            local max_sort = 0
            for _, ep in ipairs(obj.data) do
                table.insert(ep_list, {
                    idx = ep.sort,
                    ep_id = ep.id,
                })
                if ep.sort == ep_info.index then
                    target_ep = {
                        idx = ep.sort, ep_id = ep.id
                    }
                end
                if ep.sort > max_sort then max_sort = ep.sort end
            end
            bgm_api.ep_cache[bgmId] = ep_list
            kiko.log("max_sort: ", max_sort, "target: ", target_ep.idx)
            if target_ep ~= nil and succ_func ~= nil then
                succ_func(tostring(target_ep.ep_id), target_ep.idx == max_sort and obj.total < obj.limit)
            else
                err_func("未从bangumi找到相关分集")
            end
        end,
        error = function(reply)
            err_func(reply:error())
        end
    })
end

bgm_api.add_collection = function(bgm_id, anime_name, is_private, collection_type, succ_callback, retry_ctx)
    if bgm_id == nil or bgm_api.access_token == nil or not bgm_api.is_login then return end
    if bgm_api.user_info.collection_bgm_ids[bgm_id] == collection_type then
        -- 重试场景下命中去重守卫：收藏其实已成功，标记成功并清空重试
        if retry_ctx ~= nil then
            app.mark_retry_done(retry_ctx, "<small style='color: rgb(75, 244, 61);'>收藏成功</small>")
        end
        return
    end
    local data = {
        type = collection_type, -- 1: 想看 2: 看过 3: 在看 4: 搁置 5: 抛弃
        private = is_private
    }
    local type_mapping = {
        [1] = "想看", [2] = "看过", [3] = "在看", [4] = "搁置", [5] = "抛弃",
    }
    local s_lb, title_idx
    if retry_ctx ~= nil then
        -- 复用已有条目，不新建列表项
        s_lb = retry_ctx.s_lb
        title_idx = retry_ctx.title_idx
        s_lb:setopt("title", "<small>正在同步...</small>")
        bgm_api.user_info.hist_records[title_idx].status = "<small>正在同步...</small>"
    else
        local lb_title = string.format([[
        <span style="font-size:22px">%s <a style='color: rgb(96, 208, 252);' href="https://bgm.tv/subject/%s">%s</a></span> <small>%s</small>
    ]], type_mapping[collection_type], bgm_id, anime_name, os.date("%Y-%m-%d %H:%M", os.time()))
        local t_lb
        t_lb, s_lb = app.push_collection_item(true, lb_title, "<small>正在同步...</small>")
        table.insert(bgm_api.user_info.hist_records, {record = lb_title})
        title_idx = #bgm_api.user_info.hist_records
        app.bind_retry(s_lb, title_idx)
    end

    -- 失败回调：状态文本带上重试链接、写入重试信息并落盘
    local on_fail = function(content, tooltip)
        local t = string.format("<small style='color: rgb(252, 96, 125);'>收藏失败: %s</small> %s", content, app.RETRY_LINK)
        s_lb:setopt("title", t)
        if tooltip ~= nil then s_lb:setopt("tooltip", tooltip) end
        local rec = bgm_api.user_info.hist_records[title_idx]
        rec.status = t
        rec.retry = {
            type = "collection",
            bgm_id = bgm_id,
            anime_name = anime_name,
            is_private = is_private,
            collection_type = collection_type,
        }
        kiko.storage.set("bgm_user_info", bgm_api.user_info)
    end

    local _, data_json = kiko.table2json(data)
    kiko.net.request({
        method = "post",
        url = "https://api.bgm.tv/v0/users/-/collections/" .. bgm_id,
        header = {
            ["Content-Type"]="application/json",
            ["Authorization"]="Bearer " .. bgm_api.access_token,
            ["User-Agent"] = "KikoPlay-ExtensionApp"
        },
        data = data_json,
        success = function(reply)
            local t = "<small style='color: rgb(75, 244, 61);'>收藏成功</small>"
            s_lb:setopt("title", t)
            bgm_api.user_info.collection_bgm_ids[bgm_id] = collection_type
            local rec = bgm_api.user_info.hist_records[title_idx]
            rec.status = t
            rec.retry = nil
            kiko.storage.set("bgm_user_info", bgm_api.user_info)
            kiko.flash()
            if succ_callback ~= nil then succ_callback() end
        end,
        error = function(reply)
            local content = reply:content()
            if content == nil or #content == 0 then content = reply:error() end
            local err, obj = kiko.json2table(content)
            if err == nil and obj["description"] ~= nil then
                content = obj["description"]
            end
            on_fail(content, reply:error())
        end
    })
end

bgm_api.ep_finish = function(anime_name, ep_info, is_private, update_item, retry_ctx)
    local bgm_id
    if retry_ctx ~= nil then
        -- 重试场景：bgm_id 复用保存的值，但仍需校验动画仍在资料库
        bgm_id = retry_ctx.bgm_id
        local anime = kiko.library.getanime(anime_name)
        if anime == nil or anime.scriptId ~= "Kikyou.l.Bangumi" then
            app.mark_retry_done(retry_ctx, "<small style='color: rgb(252, 96, 125);'>无法重试：动画已不在资料库</small>")
            return
        end
    else
        local anime = kiko.library.getanime(anime_name)
        if anime == nil or anime.scriptId ~= "Kikyou.l.Bangumi" then return end
        bgm_id = tostring(anime.data)
    end
    local ep_index = ep_info.index
    if math.floor(ep_index) == ep_index then ep_index = math.floor(ep_index) end
    -- 重试场景跳过"先收藏再更新进度"的自动链路，仅重放进度更新这一步；
    -- 收藏补单有各自独立的重试入口
    if retry_ctx == nil and bgm_api.user_info.collection_bgm_ids[bgm_id] == nil and update_item then
        bgm_api.add_collection(bgm_id, anime_name, is_private, 3, function()
            bgm_api.ep_finish(anime_name, ep_info, is_private)
        end)
        return
    end

    local s_lb, title_idx
    if retry_ctx ~= nil then
        s_lb = retry_ctx.s_lb
        title_idx = retry_ctx.title_idx
        s_lb:setopt("title", "<small>正在获取ep id...</small>")
        bgm_api.user_info.hist_records[title_idx].status = "<small>正在获取ep id...</small>"
    else
        local lb_title = string.format([[
            <span style="font-size:22px">完成了 <a style='color: rgb(96, 208, 252);' href="https://bgm.tv/subject/%s">%s</a> %s话</span> <small>%s</small>
        ]],  bgm_id, anime_name, tostring(ep_index), os.date("%Y-%m-%d %H:%M", os.time()))
        local t_lb
        t_lb, s_lb = app.push_collection_item(true, lb_title, "<small>正在获取ep id...</small>")
        table.insert(bgm_api.user_info.hist_records, {record = lb_title})
        title_idx = #bgm_api.user_info.hist_records
        app.bind_retry(s_lb, title_idx)
    end

    -- 失败回调：状态文本带上重试链接、写入重试信息并落盘
    local on_fail = function(fail_text, tooltip)
        local t = fail_text .. " " .. app.RETRY_LINK
        s_lb:setopt("title", t)
        if tooltip ~= nil then s_lb:setopt("tooltip", tooltip) end
        local rec = bgm_api.user_info.hist_records[title_idx]
        rec.status = t
        rec.retry = {
            type = "ep_finish",
            bgm_id = bgm_id,
            anime_name = anime_name,
            ep_info = ep_info,
            is_private = is_private,
            update_item = update_item,
        }
        kiko.storage.set("bgm_user_info", bgm_api.user_info)
    end

    local err_func = function(err)
        local t = string.format("<small style='color: rgb(252, 96, 125);'>获取ep id失败: %s</small>", err)
        on_fail(t, err)
    end
    local succ_func = function(ep_id, is_last)
        local t = "<small>正在更新进度...</small>"
        s_lb:setopt("title", t)
        bgm_api.user_info.hist_records[title_idx].status = t
        local _, data_json = kiko.table2json({
            type = 2  --  0: 未收藏 1: 想看 2: 看过 3: 抛弃
        })
        kiko.net.request({
            method = "put",
            url = "https://api.bgm.tv/v0/users/-/collections/-/episodes/" .. ep_id,
            header = {
                ["Content-Type"]="application/json",
                ["Authorization"]="Bearer " .. bgm_api.access_token,
                ["User-Agent"] = "KikoPlay-ExtensionApp"
            },
            data = data_json,
            success = function(reply)
                local t = "<small style='color: rgb(75, 244, 61);'>分集进度更新成功</small>"
                s_lb:setopt("title", t)
                local rec = bgm_api.user_info.hist_records[title_idx]
                rec.status = t
                rec.retry = nil
                kiko.storage.set("bgm_user_info", bgm_api.user_info)
                kiko.flash()
                kiko.log("is_last: ", is_last, "update_item: ", update_item)
                if is_last and update_item then
                    bgm_api.add_collection(bgm_id, anime_name, is_private, 2)
                end
            end,
            error = function(reply)
                local content = reply:content()
                if content == nil or #content == 0 then content = reply:error() end
                local err, obj = kiko.json2table(content)
                if err == nil and obj["description"] ~= nil then
                    content = obj["description"]
                end
                local t = string.format("<small style='color: rgb(252, 96, 125);'>分集进度更新失败: %s</small>", content)
                on_fail(t, reply:error())
            end
        })
    end
    bgm_api.get_ep(bgm_id, ep_info, succ_func, err_func)

end

return bgm_api
