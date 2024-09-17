gpt_translator = {
    _api_key = nil,
    _url = "https://api.chatanywhere.tech/v1/chat/completions",
    _prompt = "你是一位精通简体中文的专业翻译，现在请将我输入的其他语言字幕翻译成中文，在翻译时忽略错别字或者拼写错误，结合上下文意译而不是直译，保持译文简洁流畅。我会逐行输入，请逐行输出翻译结果，并组织它们与输入一一对应：",
    _req_sub_cnt = 20,
}

function gpt_translator:sep_api_key(key)
    self._api_key = key
end

function gpt_translator:get_prompt()
    return self._prompt
end

function gpt_translator:set_prompt(prompt)
    self._prompt = prompt
end

function gpt_translator:get_req_sub_cnt()
    return self._req_sub_cnt
end

function gpt_translator:set_req_sub_cnt(cnt)
    self._req_sub_cnt = cnt
end

function gpt_translator:_get_payload(message)
    local payload = {
        model = "gpt-3.5-turbo",
        messages = {
           {
              role = "system",
              content = "你是一个字幕翻译员"
           },
           {
              role = "user",
              content = self._prompt .. message
           }
        }
    }
    local _, json = kiko.table2json(payload, 'compact')
    return json
end

function gpt_translator:_format_error(title, err)
    return string.format('<span style="color:#f10000">%s: </span> %s', title, err)
end

function gpt_translator:_post_req(message)
    local payload = self:_get_payload(message)
    local headers = {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bearer ' .. self._api_key,
    }
    kiko.log("chatgpt req: ", payload)
    local err, reply = kiko.net.httppost(self._url, payload, headers)
    if err ~= nil then
        return self:_format_error('chatgpt req error', err), nil
    end
    kiko.log(reply)
    local err, obj = kiko.json2table(reply["content"])
    if obj["choices"] == nil or type(obj["choices"]) ~= "table" or #obj["choices"] == 0 or type(obj["choices"][1]) ~= "table" then
        return self:_format_error('chatgpt rsq error', reply["content"]), nil
    end
    local msg_obj = obj["choices"][1]
    if msg_obj["message"] == nil or type(msg_obj["message"]) ~= "table" or msg_obj["message"]["content"] == nil then
        return self:_format_error('chatgpt msg rsq error', reply["content"]), nil
    end
    local translate_msg = msg_obj["message"]["content"]
    return nil, string.split(translate_msg, '\n')
end

function gpt_translator:_sleep(n)
    local p = kiko.process.create()
    local params = {"-n", n+1, "localhost"}
    p:start("ping", params)
    p:waitfinish()
end

function gpt_translator:translate_sub(sub_list, msg_callback, fill_nil)
    local max_chars_req = 2000
    local max_subs_req = self._req_sub_cnt
    local cur_msg = ''
    local start_pos = 1
    local total_cnt, process_cnt = #sub_list, 0
    local cur_batch = {}
    msg_callback(string.format("ChatGPT 翻译中... 共 %d 条字幕", total_cnt))
    for i = 1, total_cnt + 1  do
        if #cur_msg > max_chars_req or #cur_batch >= max_subs_req or i == total_cnt + 1 then
            local err, rsp = self:_post_req(cur_msg)
            kiko.log(rsp)
            if err ~= nil then
                msg_callback(err)
                msg_callback("重试一次，sleep 5s...")
                self:_sleep(5)
                err, rsp = self:_post_req(cur_msg)
            end
            if err ~= nil then
                msg_callback(err)
                msg_callback(string.format("部分字幕翻译失败：%s", cur_msg))
            else
                process_cnt = process_cnt + i - start_pos
                msg_callback(string.format("[%d/%d]chatgpt processing... 输入：%d, 返回：%d", process_cnt, total_cnt, #cur_batch, #rsp))
                for j, pos in ipairs(cur_batch) do
                    local trans_content = rsp[j]
                    if trans_content ~= nil then
                        sub_list[pos]["translate_content"] = trans_content
                    end
                end
            end
            start_pos = i
            cur_msg = ''
            cur_batch = {}
            self:_sleep(2)
        end
        if i <= total_cnt then
            local append = true
            if fill_nil then
                if sub_list[i]["translate_content"] ~= nil then
                    append = false
                end
            end
            if append then
                table.insert(cur_batch, i)
                cur_msg = cur_msg .. '\n' .. sub_list[i].content
                sub_list[i]["translate_content"] = nil
            end
        end
    end
end

return gpt_translator