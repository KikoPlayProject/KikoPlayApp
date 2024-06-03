network = {}

network.onPageBtnClick = function(param)
    local page = kiko.ui.get("npage")
    page:setopt("current_index", param["src"]:data("idx"))
end

network.onHttpPageBtnClick = function(param)
    local page = kiko.ui.get("s_http_req_page")
    page:setopt("current_index", param["src"]:data("idx"))
end

network.onHttpRespPageBtnClick = function(param)
    local page = kiko.ui.get("s_http_resp_page")
    page:setopt("current_index", param["src"]:data("idx"))
end

network.onSendBtnClick = function(param)
    local method = kiko.ui.get("method_combo"):getopt("text")
    local url = kiko.ui.get("http_url"):getopt("text")
    local query_list = string.split(kiko.ui.get("http_query"):getopt("text"), "\n", true)
    local query = {}
    for _, kv in ipairs(query_list) do
        local s, e = string.find(kv, "=")
        if s ~= nil then
            local k = string.sub(kv, 1, s-1)
            local v = string.sub(kv, e+1)
            query[k] = v
        end
    end
    local header_list = string.split(kiko.ui.get("http_header"):getopt("text"), "\n", true)
    local header = {}
    for _, kv in ipairs(header_list) do
        local s, e = string.find(kv, "=")
        if s ~= nil then
            local k = string.sub(kv, 1, s-1)
            local v = string.sub(kv, e+1)
            header[k] = v
        end
    end
    local data = kiko.ui.get("http_data"):getopt("text")
    local resp = kiko.ui.get("http_resp")
    local resp_header = kiko.ui.get("http_resp_head")
    local btn = param["src"]
    btn:setopt("enable", false)
    kiko.net.request({
        method = method,
        url = url,
        query = query,
        header = header,
        data = data,
        --redirect = true,
        --max_redirect = 10
        --trans_timeout = 30000
        success = function(reply)
            resp:setopt("text", reply:content())
            local _, hj = kiko.table2json(reply:header())
            resp_header:setopt("text", hj)
            btn:setopt("enable", true)
        end,
        error = function(reply)
            resp:setopt("text", reply:error())
            local _, hj = kiko.table2json(reply:header())
            resp_header:setopt("text", hj)
            btn:setopt("enable", true)
        end,
        progress = function(received, total, reply)
            resp:setopt("text", string.format("[%d/%d]", received, total))
        end
    })
end

network.onWSOpenBtnClick = function(param)
    if network.ws == nil then
        local info_box = kiko.ui.get("ws_recv")
        network.ws = kiko.net.websocket({
            connected = function(ws)
                local addr = ws:address()
                info_box:append(string.format("[connected]address: %s:%d, peer name: %s", addr.peer_addr, addr.peer_port, addr.peer_name))
            end,
            disconnected = function(ws)
                info_box:append("[disconnected]")
            end,
            received = function(ws, data, is_text, is_last_frame)
                info_box:append("[received]" .. data)
            end,
            pong = function(ws, elapsed_time, payload)
                info_box:append(string.format("[pong]elapsed: %d, payload: %s", elapsed_time, payload))
            end,
            state_changed = function(ws, state)
                local state_map = {
                    [kiko.net.WS_UNCONNECTED] = "unconnected",
                    [kiko.net.WS_HOST_LOOKUP] = "host-lookup",
                    [kiko.net.WS_CONNECTING] = "connecting",
                    [kiko.net.WS_CONNECTED] = "unconnected",
                    [kiko.net.WS_BOUND] = "bound",
                    [kiko.net.WS_CLOSING] = "closing",
                }
                info_box:append(string.format("[state_changed]new state: %s", state_map[state]))
            end
        })
    end
    local url = kiko.ui.get("ws_url"):getopt("text")
    network.ws:open(url)
end

network.onWsSendBtnClick = function(param)
    local dtype = param["src"]:data("dtype")
    if dtype == "ping" then
        network.ws:ping()
    elseif dtype == "send" then
        local data = kiko.ui.get("ws_data"):getopt("text")
        network.ws:send(data)
    elseif dtype == "close" then
        network.ws:close()
    end
end

return network