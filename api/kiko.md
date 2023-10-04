# <img src="../kikoplay.png" width=24 /> KikoPlay 扩展App开发参考 - KikoPlay交互与环境
2023.09 By Kikyou，本文档适用于KikoPlay 1.0.0及以上版本

这部分介绍和KikoPlay交互的api及脚本环境相关的api。

## 播放器
播放器交互api位于`kiko.player`，包括：
 - `function setmedia(path)`
   > `path`: string，播放文件路径，或者url
   > 
   > 返回：空

   播放文件或者url。

 - `function curfile()`
   > 返回：string，当前正在播放的文件路径

   获取当前正在播放的文件路径。

 - `function property(prop)`
   > `prop`: string, 属性名
   >
   > 返回：mpv错误码，0表示成功，<0表示出错

   获取libmpv属性。

 - `function command(cmd)`
   > `cmd`: string or array of string，mpv命令
   >
   > 返回：mpv错误码，0表示成功，<0表示出错

   设置libmpv命令。

 - `function optgroups()`
   > 返回：table，包含KikoPlay中全部的mpv配置组和当前使用的配置组

   获取全部和当前的配置组。

 - `function setoptgroup(group)`
   > `group`: string, 配置组名
   >
   > 返回：空

   切换配置组。

## 播放列表
播放列表交互api位于`kiko.playlist`中，包括：
 - `function add(item_info)`
   > `item_info`: table
   > 
   > 返回：true/false，是否添加成功

   向播放列表添加条目。`item_info`结构：
   ```lua
    {
        title="条目标题",
        src_type=kiko.playlist.ITEM_LOCAL_FILE,  -- 三种类型：kiko.playlist.ITEM_LOCAL_FILE(本地文件)  kiko.playlist.ITEM_WEB_URL(url)  kiko.playlist.ITEM_COLLECTION(合集)
        path="",  -- 路径，如果是合集类型条目，设置path可添加本地文件夹
        position="/",  -- 插入位置，用/分隔层次
        anime_title="", -- 动画标题，本地文件/url类型的条目可以设置
        pool="",  -- 弹幕池id
        bgm_collection=false,  -- 是否为番组集合
    }
   ```

 - `function curitem()`
   > 返回：table，当前正在播放的条目，没有返回nil

   获取当前正在播放的条目，类型同`item_info`。


## 弹幕
弹幕相关函数位于`kiko.danmu`下。
 - `function launch(dms)`
   > `dms`: array of danmu_info
   > 
   > 返回：空

   向当前正在播放的视频中发射弹幕，这些弹幕不会进入弹幕池中。danmu_info结构：
   ```lua
    {
        text="弹幕文本", 
        time=100,  -- 视频时间，单位ms 
        color=0xffffff,  -- 颜色，可选，默认白色 
        fontsize=1, --  1=normal, 2=small, 3=large
        type=0,  -- 0: 滚动弹幕  1：顶端弹幕  2：底端弹幕 
        date=0,  --  日期时间戳，单位s，可选
        sender="",  -- 发送人，可选
    }
   ```

 - `function getpool(pool_id)`

   `function getpool(pool_info)`
   > `pool_id`：string，弹幕池id
   >
   > `pool_info`：table 
   >
   > 返回：包含弹幕池信息的table

   获取弹幕池信息，可以通过id直接获取，也可以通过动画名+分集索引+分集类型获取。pool_info结构：
   ```lua
    {
        id="",  --弹幕池id，可选。获取弹幕池时如果不设置id，需要设置下面的动画名，分集索引和分集类型
        anime="", --动画名
        ep_index=1, --分集索引
        ep_type=kiko.anime.EP_TYPE_EP, --分集类型
        ep_name="",  --分集标题
        srcs = {  -- 弹幕源信息，array
            {
                name = "源标题",
                id = 0,  -- 源索引
                duration = 0,  -- 视频时长，单位s
                delay = 0,  -- 延迟，单位ms
                desc = "描述信息",
                scriptId = "脚本id",
                scriptName = "脚本名",
                scriptData = "脚本附加数据",
                timeline = "时间轴调整记录，格式为：time1 delta1;(time2, delta2;......)",
            },
            ...
        }
    }
   ```
    分集类型定义：
    ```lua
        kiko.anime.EP_TYPE_EP,
        kiko.anime.EP_TYPE_SP,
        kiko.anime.EP_TYPE_OP,
        kiko.anime.EP_TYPE_ED,
        kiko.anime.EP_TYPE_Trailer,
        kiko.anime.EP_TYPE_MAD,
        kiko.anime.EP_TYPE_Other
    ```

 - `function addpool(pool_info)`
   > `pool_info`: table
   > 
   > 返回：添加成功或弹幕池已存在返回pool_id，否则返回空

   添加弹幕池。`pool_info`中需要包括动画名、分集索引和分集类型。

 - `function getdanmu(pool_id)`
   > `pool_id`: string，弹幕池id
   > 
   > 返回：全部弹幕信息。

   获取弹幕池中的全部弹幕，返回结构：
   ```lua
    {
        source = {  -- 弹幕源信息array
            {
                name = "源标题",
                id = 0,  -- 源索引
                duration = 0,  -- 视频时长，单位s
                delay = 0,  -- 延迟，单位ms
                desc = "描述信息",
                scriptId = "脚本id",
                scriptName = "脚本名",
                scriptData = "脚本附加数据",
                timeline = "时间轴调整记录，格式为：time1 delta1;(time2, delta2;......)，time为时间点(单位s)，delta为在时间点处插入的延迟(单位ms)",
            },
            ...
        },
        comment = {  -- 全部弹幕array
            {
                0, 0, 0xffffff,0,"弹幕文本","发送用户",0
            },  -- 格式为：时间(s), 类型(0:滚动 1:顶部 2:底部),颜色,弹幕源id,弹幕文本,发送用户,发送时间戳
            ...
        }
    }
   ```
   返回的弹幕没有应用弹幕源的偏移信息，弹幕的最终时间是：原始时间 + delay + sum(原始时间之前的timeline delta).

 - `function addsrc(pool_id, src_info)`
   > `pool_id`：string，弹幕池id
   >
   > `src_info`: table
   > 
   > 返回：添加成功或源已存在（有相同的scriptId和scriptData字段）返回源索引，否则返回空

   向弹幕池添加弹幕源。`src_info`结构：
   ```lua
    {
        source = {
            name = "源标题",
            duration = 0,  -- 视频时长，单位s,可选
            delay = 0,  -- 延迟，单位ms，可选
            desc = "描述信息", --可选
            scriptId = "脚本id",  -- 必须
            scriptName = "脚本名",  -- 可选
            scriptData = "脚本附加数据",  -- 必须
            timeline = "时间轴调整记录，格式为：time1 delta1;(time2, delta2;......)，time为时间点(单位s)，delta为在时间点处插入的延迟(单位ms)",  -- 可选
        },
        comment = {  -- 源包含的弹幕array
            {
                text="弹幕文本", 
                time=100,  -- 视频时间，单位ms 
                color=0xffffff,  -- 颜色，可选，默认白色 
                fontsize=1, --  1=normal, 2=small, 3=large
                type=0,  -- 0: 滚动弹幕  1：顶端弹幕  2：底端弹幕 
                date=0,  --  日期时间戳，单位s，可选
                sender="",  -- 发送人，可选
            }, 
            ...
        }
    }

   ```

## 资料库
资料库api位于`kiko.library`下。
 - `function getanime(anime_name)`
   > `anime_name`: string，动画名
   > 
   > 返回：anime_info

   获取动画信息。anime_info结构：
   ```lua
    {
        name = "动画名", 
        desc = "描述信息", 
        url = "链接", 
        coverUrl = "封面url", 
        scriptId = "脚本id", 
        data = "脚本附加数据", 
        airDate = "放送日期，yyyy-MM-dd", 
        epCount = 12, -- 分集数量 
        addTime = 0, -- 添加时间戳 
        crt = {  -- 角色
            {
                name="角色名",
                actor="演员",
                link="链接",
                imgurl="图片链接",
            }，
            ...
        }, 
        staff = { -- staff信息
            key="val", ...
        }, 
        eps = { -- 分集信息，可能没有
            {  
                name = "分集标题",
                index = 1,  -- 索引
                type =  kiko.anime.EP_TYPE_EP, -- 分集类型
                localFile = "本地文件路径",
                finishTime = 0, -- 完成时间戳(s)
                lastPlayTime = 0, -- 上次播放时间戳(s)
            }, 
            ...
        }
    }
   ```

 - `function gettag(anime_name)`
   > `anime_name`: string，动画名
   > 
   > 返回：array of string

   获取动画的标签。

 - `function addanime(anime_name)`

   `function addanime(anime_info)`
   > `anime_name`: string，动画名
   > 
   > `anime_info`：table，动画信息
   >
   > 返回：true/false，是否添加成功

   添加动画，可以仅添加动画名，也可以包含详细信息。`anime_info`的内容：
   ```lua
    {
        name = "动画名",  -- 必须
        desc = "描述信息", 
        url = "链接", 
        coverUrl = "封面url",  -- KikoPlay会下载封面，也可以是本地文件路径
        scriptId = "脚本id", 
        data = "脚本附加数据", 
        airDate = "放送日期，yyyy-MM-dd",  -- 必须
        epCount = 12, -- 分集数量 
        addTime = 0, -- 添加时间戳 
        crt = {  -- 角色
            {
                name="角色名",
                actor="演员",
                link="链接",
                imgurl="图片链接",  -- KikoPlay会下载图片，也可以是本地文件路径
            }，
            ...
        }, 
        staff = "key:val;key:val..."  -- staff信息
        ...
    }
   ```   

 - `function addtag(anime_name, tags)`
   > `anime_name`: string，动画名
   > 
   > `tags`：array of string，要添加的标签
   >
   > 返回：成功添加的标签数

   向动画添加标签。

## 下载
下载相关函数位于`kiko.download`中。
 - `function addurl(url_info)`
   > `url_info`: table
   > 
   > `tags`：array of string，要添加的标签
   >
   > 返回：true/false(是否添加成功), err_info(错误信息) 

   添加url下载任务。`url_info`结构：
   ```lua
    {
        url = "", -- string 或者 array of string，可同时添加多个链接
        save_dir = "", -- 保存位置，可选
        skip_magnet_confirm = false, -- 是否跳过磁力链接的文件确认，如果跳过会下载全部文件，默认false，可选
        skip_confirm = false, -- 是否跳过KikoPlay的下载确认，默认false，可选
    }
   ```

 - `function addtorrent(torrent_data, save_dir)`
    > `torrent_data`: 种子文件数据
    >
    > `save_dir`：string，保存位置，可选
    >
    > 返回：true/false(是否添加成功), err_info(错误信息) 

   添加种子下载任务。

## 事件监听
KikoPlay提供了事件总线组件，用来监听/发送事件。相关函数位于`kiko.event`中。
 - `function listen(event, callback)`
    > `event`: 要监听的事件
    >
    > `callback`：function，事件发生的回调函数
    >
    > 返回：空

   监听事件。同类型的事件如果添加多个监听，只有最后一次监听的回调函数会被调用。`callback`指定的函数需要接受一个table类型的参数，包含关于事件的详细内容。

   事件定义：
    - kiko.event.EVENT_PLAYER_STATE_CHANGED 

        播放器状态变化。参数：
        ```lua
        {
            state = 0  -- 新状态，0 正在播放 1 暂停 2 停止 3 完播
        }
        ```

    - kiko.event.EVENT_PLAYER_FILE_CHANGED 

        播放的文件发生变化。参数：
        ```lua
        {
            file = "", -- 新文件
            anime_name = "",  -- 动画名称，只有播放的文件位于播放列表，且关联了弹幕池才有这一项
            epinfo = {  -- 分集信息，只有播放的文件位于播放列表，且关联了弹幕池才有这一项
                name = "分集标题",
                index = 1,  -- 索引
                type =  kiko.anime.EP_TYPE_EP, -- 分集类型
                localFile = "本地文件路径",
                finishTime = 0, -- 完成时间戳(s)
                lastPlayTime = 0, -- 上次播放时间戳(s)
            }
        }
        ```

    - kiko.event.EVENT_LIBRARY_ANIME_ADDED 

        动画添加到资料库中。参数同`getanime`返回的anime_info。

    - kiko.event.EVENT_LIBRARY_ANIME_UPDATED 

        资料库动画的信息被更新。参数同`getanime`返回的anime_info。

    - kiko.event.EVENT_LIBRARY_EP_FINISH 

        剧集完播。参数：
        ```lua
        {
            path = "", -- 完播的文件路径
            anime_name = "",  -- 动画名称，只有播放的文件位于播放列表，且关联了弹幕池才有这一项
            epinfo = {  -- 分集信息，只有播放的文件位于播放列表，且关联了弹幕池才有这一项
                name = "分集标题",
                index = 1,  -- 索引
                type =  kiko.anime.EP_TYPE_EP, -- 分集类型
                localFile = "本地文件路径",
                finishTime = 0, -- 完成时间戳(s)
                lastPlayTime = 0, -- 上次播放时间戳(s)
            }
        }
        ```

    - kiko.event.EVENT_APP_STYLE_CHANGED 

        KikoPlay主题发生变化。参数：
        ```lua
        {
            mode = 0, -- 0: 无背景无主题色  1：有背景无主题色 2：有背景有主题色
            dark_mode = false, -- 是否开启深色模式
        }
        ```

## 定时器
`kiko.timer`包含两个方法：
 - `function create(interval)`
    > `interval`: 定时器触发间隔，ms
    >
    > 返回：定时器对象

   创建定时器。

 - `function run(timeout, func)`
    > `timeout`: 超时间隔，ms
    >
    > `func`：回调函数
    >
    > 返回：空

   在`timeout`后运行`func`，一次性。

定时器方法：
 - `function ontimeout(func)`
    > `func`: 定时器触发的回调函数
    >
    > 返回：空

   设置定时器的超时回调函数。

 - `function start()`
    > 返回：空

   开启定时器。

 - `function stop()`
    > 返回：空

   停止定时器。

 - `function setinterval(interval)`
    > `interval`: 定时器触发间隔，ms
    >
    > 返回：空

   设置定时器触发间隔。

 - `function interval()`
    > 返回：定时器触发间隔

   获取定时器触发间隔。

 - `function active()`
    > 返回：true/false

   定时器是否在运行中。

 - `function remaining()`
    > 返回：定时器下一次超时的剩余时间，ms

   获取定时器下一次超时的剩余时间。

## 剪贴板
剪贴板操作函数位于`kiko.clipboard`：
 - `function gettext()`
    > 返回：string

   获取剪贴板上的文本。

 - `function getimg()`
    > 返回：Image对象，参考[Image](ui.md#image)

   获取剪贴板上的图片。

 - `function settext(text)`
    > `text`: string
    >
    > 返回：空

   设置剪贴板文本。   

 - `function setimg(img)`
    > `img`: Image对象，参考[Image](ui.md#image)
    >
    > 返回：空

   设置剪贴板图片。 

## 存储
KikoPlay为App提供了一个简单易用的kv存储，相关api位于`kiko.storage`中，持久化文件位于App数据目录下的`storage`文件。
 - `function get(key)`
    > `key`: string
    >
    > 返回：`key`对应的value

   读取`key`对应的value。

 - `function set(key, value)`
    > `key`: string
    >
    > `value`：值，支持table等lua类型
    >
    > 返回：空

   写入kv。   

## 进程
`kiko.process`包括：
 - `function create()`
    > 返回：process对象

   创建进程对象。

 - `function sysenv(timeout, func)`
    > 返回：table，kv形式

   获取环境变量。

process对象包含的方法：
 - `function start(program, params)`
    > `program`：string，程序路径
    >
    > `params`: table of string，命令行参数
    >
    > 返回：空

   在新进程中启动程序并传递命令行参数。

 - `function terminate()`
    > 返回：空

   结束进程。

 - `function kill()`
    > 返回：空

   强制结束进程。

 - `function onevent(funcs)`
    > `funcs`: table，包含事件回调函数
    >
    > 返回：空

   设置进程事件的回调。`funcs`结构：
   ```lua
    {
        start = function()  -- 进程启动后的回调

        end,
        error = function(err_number)  -- 进程出错的回调
            -- err_number：
            --  0 启动失败
            --  1 崩溃
            --  2 waitfor超时
            --  3 读错误
            --  4 写错误
            --  5 未知错误
        end,
        finished = function(exit_code, exit_status)  -- 进程结束回调
            -- exit_status： 0 正常  1 崩溃
        end,
        readready = function(channel) -- 可以开始读取的回调
            -- channel： 0 标准输出stdout 1 标准错误输出stderr
        end
    }
   ```

 - `function setenv(params)`
    > `params`: table，kv形式
    >
    > 返回：空

   设置进程的环境变量。

 - `function env()`
    > 返回：table

   获取进程的环境变量。

 - `function dir()`
    > 返回：string

   获取进程的工作目录。

 - `function setdir(path)`
    > `path`：string
    >
    > 返回：空

   设置进程的工作目录。

 - `function pid()`
    > 返回：integer

   获取进程的pid。

 - `function exitstate()`
    > 返回：exit_code, exit_status

   获取进程的退出状态。

- `function waitstart(timeout)`
    > `timeout`：等待时长，可选，默认-1表示无限时长，单位ms
    >
    > 返回：空

   等待进程启动。

- `function waitfinish(timeout)`
    > `timeout`：等待时长，可选，默认-1表示无限时长，单位ms
    >
    > 返回：空

   等待进程结束。

- `function waitwritten(timeout)`
    > `timeout`：等待时长，可选，默认-1表示无限时长，单位ms
    >
    > 返回：空

   等待写操作完成。

- `function waitreadready(timeout)`
    > `timeout`：等待时长，可选，默认-1表示无限时长，单位ms
    >
    > 返回：空

   等待可读取。

- `function readoutput()`
    > 返回：string

   从标准输出中读取。

- `function readerror()`
    > 返回：string

   从标准错误输出中读取。

- `function write(data)`
    > `data`：string，写入数据
    >
    > 返回：写入的字节数

   向标准输入中写入数据。

## 文件和目录信息
`kiko.dir`提供了一些操作文件和目录的函数。
- `function fileinfo(path)`
    > `path`：string，路径
    >
    > 返回：table

   获取文件或目录信息。

- `function exists(path)`
    > `path`：string，路径
    >
    > 返回：true/false

   文件或目录是否存在。

- `function mkpath(path)`
    > `path`：string，路径
    >
    > 返回：true/false

   创建目录。

- `function rmpath(path)`
    > `path`：string，路径
    >
    > 返回：true/false

   删除目录，需要目录为空。

- `function rename(old_path, new_path)`
    > `old_path`：string，之前的路径
    >
    > `new_path`：string，新路径
    >
    > 返回：true/false

   重命名文件/目录。

- `function syspath()`
    > 返回：table，kv形式

   获取系统路径。

- `function entrylist(path, namefilter, filter, sort)`
    > `path`：string，路径
    >
    > `namefilter`：string，文件名过滤，可选
    >
    > `filter`：integer，过滤器，可选
    >
    > `sort`：integer，排序规则，可选
    >
    > 返回：array of string

   获取`path`下的文件和目录。`namefilter`支持通配符，多个过滤规则用`;`隔开，它们是或的关系，例如："*.cpp;*.cxx;*.cc"。

   `filter`类型如下，可用或组合：
   ```lua
    kiko.dir.FILTER_DIRS
    kiko.dir.FILTER_ALL_DIRS
    kiko.dir.FILTER_FILES
    kiko.dir.FILTER_DRIVES
    kiko.dir.FILTER_NO_SYMLINKS
    kiko.dir.FILTER_NO_DOT
    kiko.dir.FILTER_ALL_ENTRIES
    kiko.dir.FILTER_HIDDEN
   ```
  `sort`类型如下，可用或组合：
  ```lua
    kiko.dir.SORT_NAME
    kiko.dir.SORT_TIME
    kiko.dir.SORT_SIZE
    kiko.dir.SORT_TYPE
    kiko.dir.SORT_NO
    kiko.dir.SORT_DIR_FIRST
    kiko.dir.SORT_DIR_LAST
    kiko.dir.SORT_REVERSE
    kiko.dir.SORT_IGNORE_CASE
  ```
## 环境信息
在创建App时，KikoPlay会在lua虚拟机环境中创建一个全局table `env`，包含以下内容：
```lua
{
    app_path = "App目录",
    os = "操作系统",
    os_version = "操作系统版本",
    kikoplay = "KikoPlay版本",
    data_path = "App数据目录",
}

```
## 其他函数
一些常用函数位于`kiko`表下，基本和脚本中提供的函数类似：
 - `json2table(jsonstr)`

   > `jsonstr`：string, json字符串
   >
   > 返回：string/nil, Table

   将json字符串解析为lua的Table
   返回的第一个值表示是否发生错误，没有错误时为nil，否则是错误信息

 - `table2json(table, compact)`

   > `table`：Table, 待转换为json的table
   >
   > `compact`: string, 可选，表示输出紧凑还是格式化的json，默认为格式化的json，传入"compact"则输出紧凑的json
   >
   > 返回：string/nil, string

   将lua的Table转换为json字符串
   返回的第一个值表示是否发生错误，没有错误时为nil，否则是错误信息

 - `compress(content, type)`

   > `content`：string, 待压缩的字符串
   >
   > `type`：压缩方式，可选，默认为gzip，目前也只支持gzip
   >
   > 返回：string/nil, string

   压缩字符串， 第二个返回值为压缩结果

   返回的第一个参数表示是否发生错误，没有错误时为nil，否则是错误信息

 - `decompress(content, type)`

   > `content`：string, 待压缩的字符串
   >
   > `type`：压缩方式，可选，支持inflate和gzip，默认为inflate
   >
   > 返回：string/nil, string

   解压缩字符串， 第二个返回值为解压缩结果

   返回的第一个值表示是否发生错误，没有错误时为nil，否则是错误信息

 - `execute(detached, program, args)`

   > `detached`：bool，是否等待程序执行结束，true:不等待
   >
   > `program`：string，执行的程序
   >
   > `args`： Array[string]， 参数列表
   >
   > 返回：string/nil, bool/number

   执行外部程序。返回的第一个值表示调用参数是否正确，没有错误时为nil，否则是错误信息。第二个值为程序执行结果，如果`detached=true`，值为true/false表示程序是否启动；如果`detached=false`，值为外部程序的返回值

 - `hashdata(path_data, ispath, filesize, algorithm`)

   > `path_data`：string，文件路径或者待计算hash的数据
   >
   > `ispath`：bool，第一个参数是否是文件路径，默认=true
   >
   > `filesize`： number，只有第一个参数为文件路径才有意义，表示读取文件的大小，=0表示读取整个文件，否则只读取前`filesize` bytes
   >
   > `algorithm`：string，hash算法，默认为md5，可选：md4,md5,sha1,sha224,sha256,sha386,sha512
   >
   > 返回：string/nil, string

   计算文件或者数据的hash，第一个返回值表示是否出错，第二个返回值为hash值

 - `base64(data, type)`

   > `data`：string，待转换或者已经base64编码的数据
   >
   > `type`：string, 可选from/to, from：base64解码，to: base64编码，默认为from
   >
   > 返回：string/nil, string

   0.9.0新增，base64转换函数，第一个返回值表示是否出错，第二个返回值为base64编码/解码结果

 - `log(...)`

   打印输出到KikoPlay的“脚本日志”对话框中。支持多个参数，如果只有一个参数且类型为Table，会以json的形式将整个Table的内容输出(注意，Table不能包含循环引用)
 
 - `flash()`
   > 返回：空
   
   闪烁App图标。

 - `viewtable(table)`

   可视化Table的全部内容，便于进行调试

 - `sttrans(str, to_simp)`

   > `str`：string，源字符串
   >
   > `to_simp`：bool，是否转换为简体中文，true：转换为简体中文，false：转换为繁体中文
   >
   > 返回：string/nil, string

    简繁转换，这个函数只有在windows系统上有效，其他平台上会原样返回。第一个返回值表示是否出错，第二个返回值为转换后的结果

 - `envinfo()`

   > 返回： Table，包含：
   >```lua
   > {
   >    ["os"]=string,         --操作系统
   >    ["os_version"]=string, --系统版本
   >    ["kikoplay"]=string    --KikoPlay版本
   > }
   >

   显示脚本环境信息

 - `xmlreader(str)`

   > `str`：string，xml内容
   >
   > 返回：kiko.xmlreader

    创建一个流式XML读取器。KikoPlay提供了一个简单的XML读取器（封装Qt中的QXmlStreamReader），kiko.xmlreader提供如下方法：
    ```lua
    adddata(str)        --继续添加xml数据
    clear()             --清空数据
    atend()             --读取是否到达末尾，true/false
    readnext()          --读取下一个标签
    startelem()         --当前是否是开始标签，true/false
    endelem()           --当前是否是结束标签，true/false
    name()              --返回当前标签名称
    attr(attr_name)     --返回属性attr_name的值
    hasattr(attr_name)  --当前标签是否包含attr_name属性，true/false
    elemtext()          --读取从当前开始标签到结束标签之间的文本并返回
    error()             --返回错误信息，没有错误返回nil
    ```
    一个示例:
    ```lua
    local xmlreader = kiko.xmlreader(danmuContent)
    local curDate, curText, curTime, curColor, curUID = nil, nil, nil, nil, nil
    while not xmlreader:atend() do
        if xmlreader:startelem() then
            if xmlreader:name()=="contentId" then
                curDate = string.sub(xmlreader:elemtext(), 1, 10)
            elseif xmlreader:name()=="content" then
                curText = xmlreader:elemtext()
            elseif xmlreader:name()=="showTime" then
                curTime = tonumber(xmlreader:elemtext()) * 1000
            elseif xmlreader:name()=="color" then
                curColor = tonumber(xmlreader:elemtext(), 16)
            elseif xmlreader:name()=="uid" then
                curUID = "[iqiyi]" .. xmlreader:elemtext()
            end
        elseif xmlreader:endelem() then
            if xmlreader:name()=="bulletInfo" then
                table.insert(danmuList, {
                    ["text"]=curText,
                    ["time"]=curTime,
                    ["color"]=curColor,
                    ["date"]=curDate,
                    ["sender"]=curUID
                })
            end
        end
        xmlreader:readnext()
    end
    ```
 - `htmlparser(str)`

   > `str`：string，html内容
   >
   > 返回：kiko.htmlparser

    创建一个流式HTML读取器。KikoPlay提供了一个简单的HTML读取器，可以顺序解析HTML标签。kiko.htmlparser提供如下方法：
    ```lua
    adddata(str)         --继续添加html数据
    seekto(pos)          --跳转到pos位置
    atend()              --读取是否到达末尾，true/false
    readnext()           --读取下一个标签
    curpos()             --返回当前位置
    readcontent()        --读取内容并返回，直到遇到结束标签</
    readuntil(lb, start) --向前读取，直到遇到lb标签，start=true表示希望遇到开始的lb标签，=false表示希望遇到结束的lb标签
    start()              --当前标签是否是开始标签，true/false
    curnode()            --返回当前标签名
    curproperty(prop)    --读取当前标签的prop属性值
    ```
    简单示例（来自library/bangumi.lua）：
    ```lua
    --tagContent 为部分网页内容
    local parser = kiko.htmlparser(tagContent)
    while not parser:atend() do
        --遇到开始的链接标签<a>
        if parser:curnode()=="a" and parser:start() then  
            parser:readnext()
            table.insert(tags, parser:readcontent())
        end
        parser:readnext()
    end
    ```
- `regex(str, option)`

   > `str`：string，正则表达式内容
   >
   > `option`：string，可选，包含i,m,s,x四个选项，可多选：  
   >  - i: CaseInsensitiveOption
   >  - s: DotMatchesEverythingOption
   >  - m: MultilineOption
   >  - x: ExtendedPatternSyntaxOption
   >
   > 返回：kiko.regex

    封装了`QRegularExpression`，提供了比lua自带的更为高级的正则表达式。kiko.regex提供如下方法：
    ```lua
    find(target, initpos)
    --用当前表达式从initpos位置匹配一次目标字符串target，如果有匹配，返回 起始位置，结束位置，捕获组1，捕获组2，...，可代替Lua原生的string.find()。如果没有匹配，函数什么都不返回
    gmatch(target)
    --用当前表达式无限次匹配目标字符串，返回Lua风格迭代器，迭代时每次输出当次匹配结果，包括表达式完整匹配（首个返回值）和所有捕获组匹配到的内容，从Lua原生的string.gmatch()迁移则注意是否需要跳过首个返回值
    gsub(target, repl)
     --用当前表达式对目标字符串无限次执行替换操作，返回替换后的字符串，可接受字符串，表格（{[key]=value,...}）和函数格式的替换值，返回替换后的结果
    setpattern(pattern, options)
    --重新设置正则表达式，参数含义和构造函数相同
    ```
    简单示例：
    ```lua
    local reg = kiko.regex("(\\w+)\\s*(\\w+)")
    local i, j , w, f= reg:find("hello world from Lua", 7)
    print(("start: %d, end: %d"):format(i, j))  -- start: 7, end: 16
    print(w, f)  -- world	from

    reg:setpattern("\\$(.*?)\\$")
    local x = reg:gsub("4+5 = $return 4+5$", function (o, s)
        print("in gsub: ", o, s)  -- in gsub: 	$return 4+5$	return 4+5
        return load(s)()
      end)
    print("gsub: ", x)  -- gsub: 	4+5 = 9

    local x = reg:gsub("4+5 = $ret$", "99")
    print("gsub: ", x)  -- gsub: 	4+5 = 99

    reg:setpattern("(\\w)(\\w)(\\w)\\s(.+)")
    local x = reg:gsub("abc abc", {a="Ki", b="ko", c="Play", abc="0.9.0"})
    print("table gsub: ", x)  -- table gsub: 	KikoPlay 0.9.0

    local s = "hello world from Lua"
    reg:setpattern("\\w+")
    for w in reg:gmatch(s) do
        print("gmatch: ", w)
    end
    ```

## 字符串函数
KikoPlay在`string`中增加了以下几个函数：
 - `trim(str)`
   > `str`：string
   >
   > 返回： 去除`str`两边空白字符后的结果

   去除字符串两边的空白。

 - `startswith(str, token)`
   > `str`：string
   >
   > `token`：string
   >
   > 返回： bool

   判断`token`是否为`str`的前缀。

 - `endswith(str, token)`
   > `str`：string
   >
   > `token`：string
   >
   > 返回： bool

   判断`token`是否为`str`的后缀。

 - `split(str, token, skip_empty)`
   > `str`：string
   >
   > `token`：string
   >
   > `skip_empty`：bool，可选，默认false
   >
   > 返回： array of string

   将`str`按照`token`切分，如果`skip_empty=true`，忽略切分中产生的空字符串。

 - `indexof(str, target, from)`
   > `str`：string
   >
   > `target`：string
   >
   > `from`：integer，可选，默认从1开始
   >
   > 返回： integer

   返回`target`在`str`中从`from`开始首次出现的位置，如果没有返回-1。

 - `lastindexof(str, target, from)`
   > `str`：string
   >
   > `target`：string
   >
   > `from`：integer，可选，默认从-1开始向前搜索
   >
   > 返回： integer

   返回`target`在`str`中从`from`开始从后向前首次出现的位置，如果没有返回-1。

 - `encode(str, src_code, dest_code)`
   > `str`：string
   >
   > `src_code`：源编码
   >
   > `dest_code`：目标编码
   >
   > 返回： string

    将`str`从源编码转为目标编码。编码目前有两种取值：
    ```lua
        string.CODE_LOCAL -- 本地编码
        string.CODE_UTF8 -- utf-8编码
    ```
