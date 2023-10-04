# <img src="../kikoplay.png" width=24 /> KikoPlay 扩展App开发参考 - 网络访问
2023.09 By Kikyou，本文档适用于KikoPlay 1.0.0及以上版本

KikoPlay提供同步/异步http api和websocket api供app使用，这些函数位于`kiko.net`中。


## 同步Http访问
和脚本中提供的http访问函数一致。
 - `httpget(url, query, header, redirect)`

   > `url`：string
   >
   > `query`：查询，`{[key]=value,...}`，可选，默认为空
   >
   > `header`: HTTP Header, `{[key]=value,...}`，可选，默认为空
   >
   > `redirect`：bool，是否自动进行重定向，默认`true`
   >
   > 返回：string/nil, [NetworkReply](#networkreply)

   发送HTTP GET请求。返回的第一个值表示是否发生错误，没有错误时为nil，否则是错误信息

 - `httpgetbatch(urls, querys, headers, redirect)`

   > `urls`： Array[string]
   > 
   > `querys`：查询，`Array[{[key]=value,...}]`，可选，默认为空
   >
   > `headers`: HTTP Header, `Array[{[key]=value,...}]`，可选，默认为空
   >
   > `redirect`：bool，是否自动进行重定向，默认`true`
   >
   > 返回：string/nil, Array[[NetworkReply](#networkreply)]

   和`httpget`类似，但可以一次性发出一组HTTP Get请求，需要确保`urls`、`querys`和`headers`中的元素一一对应，querys和headers也可以为空

 - `httppost(url, data, header, querys)`

   > `url`：string
   >
   > `data`：string, POST数据
   >
   > `header`: HTTP Header, `{[key]=value,...}`，可选，默认为空
   >
   > `querys`：查询，`Array[{[key]=value,...}]`，可选，默认为空
   >
   > 返回：string/nil, [NetworkReply](#networkreply)

   发送HTTP POST请求。返回的第一个值表示是否发生错误，没有错误时为nil，否则是错误信息

 - `httphead(url, query, header, redirect)`

   > `url`：string
   >
   > `query`：查询，`{[key]=value,...}`，可选，默认为空
   >
   > `header`: HTTP Header, `{[key]=value,...}`，可选，默认为空
   >
   > `redirect`：bool，是否自动进行重定向，默认`true`
   >
   > 返回：string/nil, [NetworkReply](#networkreply)

   发送HTTP Head请求。返回的第一个值表示是否发生错误，没有错误时为nil，否则是错误信息

## 异步Http访问
通过`kiko.net.request`函数构建请求，返回响应对象，在回调方法中处理。
 - `function request(params)`
   > `params`：table，请求参数
   >
   > 返回：reply对象

   params定义：
   ```lua
    {
       url="www.kikoplay.fun", -- 地址
       method="get", --方法，get,post,head,put,delete...
       data="", --数据，可选
       query={   --query，可选
           key="val"
       },
       header={  --header，可选
           key="val"
       },
       redirect=true,  --自动重定向，可选
       max_redirect=10， --最大重定向次数，可选
       trans_timeout=0,   --超时时间，可选，0表示不设置
       success = function(reply)  -- 请求成功的回调函数，reply是reply对象
          local recv = reply:content()
       end,
       error = function(reply)  -- 请求失败的回调函数，reply是reply对象
          local err = reply:error()
       end,
       progress =  function(received, total, reply)  --进度回调，received: 接收的字节数，total：总字节数

       end,
       extra = "",  -- extra信息，后续可通过reply对象的extra方法获取，可以是任意lua数据
    }
   ```
响应对象的方法：
 - `function content()`
   > 返回：string，接收的内容

   获取全部响应。如果已经用`read`读取过，返回剩下未读取的内容。

 - `function error()`
   > 返回：string，错误信息

   获取错误信息。

 - `function header()`
   > 返回：table

   获取响应头。

 - `function status()`
   > 返回：状态码

   获取响应状态码。

 - `function read(max_size)`
   > `max_size`：最多读取字节数，可选，默认1024
   >
   > 返回：读取的响应内容

   读取响应内容。对于响应内容比较长的请求，可以用这个函数逐步读取。

 - `function abort()`
   > 返回：空

   中断请求。

 - `function finished()`
   > 返回：true/false

   请求是否结束。

 - `function running()`
   > 返回：true/false

   请求是否还在进行。

 - `function extra()`
   > 返回：构造请求时，params表中的extra字段内容

   获取请求时设置的extra信息。

## WebSocket
通过`kiko.net.websocket`函数创建websocket对象。
 - `function websocket(params)`
   > `params`：table，请求参数
   >
   > 返回：websocket对象

   params定义：
   ```lua
    {
       connected = function(ws)  -- 成功建立连接的回调函数，ws是websocket对象
       end,
       disconnected = function(ws)  --  连接断开的回调函数，ws是websocket对象
       end,
       received =  function(ws, data, is_text, is_last_frame)  --收到数据的回调函数，data:收到的数据 is_text: 是否为文本数据 is_last_frame: 如果是帧数据，当前是否为最后一帧

       end,
       pong =  function(ws, elapsed_time, data)  --收到上一次ping回复的pong消息的回调函数，elapsed_time: 往返时间，data：随ping发送的可选数据

       end,
       state_changed = function(ws, state)  --websocket状态变化的回调函数，state: 新状态
       -- state取值：
       -- kiko.net.WS_UNCONNECTED   未连接
       -- kiko.net.WS_HOST_LOOKUP   正在查找主机名
       -- kiko.net.WS_CONNECTING    正在建立连接
       -- kiko.net.WS_CONNECTED     已连接
       -- kiko.net.WS_BOUND         socket绑定到地址和端口
       -- kiko.net.WS_CLOSING       即将关闭

       end,
       extra = "",  -- extra信息，后续可通过reply对象的extra方法获取，可以是任意lua数据
    }
   ```
websocket对象方法：
 - `function open(url)`
   > `url`: string，地址
   >
   > 返回：空

   通过url建立一个websocket连接。

 - `function close()`
   > 返回：空

   关闭websocket连接。

 - `function error()`
   > 返回：string，错误信息

   获取错误信息。

 - `function ping(data)`
   > `data`: string，可选
   >
   > 返回：空

   发送ping消息。

 - `function send(data, is_binary)`
   > `data`：string，要发送的数据
   >
   > `is_binary`：是否为二进制数据，可选，默认false
   >
   > 返回：空

   发送数据。

 - `function address()`
   > 返回：table，包含连接的地址信息

   获取地址信息。

 - `function state()`
   > 返回：连接状态

   获取当前连接状态。

 - `function extra()`
   > 返回：构造websocket时，params表中的extra字段内容

   获取构造websocket时设置的extra信息。
