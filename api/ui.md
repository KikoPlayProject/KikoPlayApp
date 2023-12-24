# <img src="../kikoplay.png" width=24 /> KikoPlay 扩展App开发参考 - UI
2023.09 By Kikyou，本文档适用于KikoPlay 1.0.0及以上版本

KikoPlay通过xml描述app的ui结构，`app.xml`根节点必须为`window`元素，通过`include`节点包含的其他文件没有这个限制。 可以通过xml属性来设置ui元素的各种状态、布局及事件响应方法。

ui元素由KikoPlay管理，在lua中将ui对象设置为nil并不会删除对象。

有一类元素可以起到容器的作用，它能容纳多个子元素，并按一定的方式进行排列布局。例如，`hview`是一个水平布局的容器，以下xml在`hview`中放置了三个按钮，它们将在水平方向上排列，同时第一个按钮和第二个按钮之间有可伸缩的空白。
```xml
<hview>
    <button id="bt1" title="Btn1" view-depend:trailing-stretch="1" />
    <button title="Btn2" />
    <button title="Btn3" />
</hview>
```

如果ui节点拥有`id`属性，可在lua中通过函数`kiko.ui.get(id)`获取元素对象。ui元素拥有一些公共方法，例如读取/修改属性的方法：
```lua
local btn = kiko.ui.get("btn1")
local btn_title = btn:getopt("title")  -- 获取按钮标题
btn:setopt("title", btn_title .. "_new_title")  -- 修改按钮标题
```

## 公共属性和方法

所有ui元素都具有如下属性，可以在xml或lua程序中读取/设置，但对于某些ui元素可能无效。

|  属性          | 含义  | 取值 |
|  -----         | ----  | ---- |
| id             | ui元素的id <br/>  |    |
| x              | 元素的x坐标，在有布局的容器中可能失效 |     |
| y              | 元素的y坐标，在有布局的容器中可能失效 |     |
| w              | 宽度，在有布局的容器中可能失效 |     |
| h              | 高度，在有布局的容器中可能失效 |     |
| max_w          | 的最大宽度 |     |
| max_h          | 最大高度 |     |
| min_w          | 最小宽度 |     |
| min_h          | 最小高度 |     |
| visible        | 是否可见 | `true/false`|
| enable         | 是否启用 | `true/false`|
| tooltip        | 工具提示 |     |
| h_size_policy  | 宽度调整策略 <br/> 影响元素在带有布局的容器中的宽度 |  `fix`: 固定 <br/> `min`: 当前宽度为最小宽度，容器有多余空间就扩张 <br/> `max`: 当前宽度为最大宽度，容器缩小时尽量缩小 <br/> `prefer`: 当前尺寸为最佳尺寸，被动扩张/收缩 <br/>  `expand`: 主动扩张，尽可能占据空间 <br/> `min_expand`: 当前宽度为最小高度，尽可能扩张 <br/> `ignore`:  忽略尺寸，可随意扩张/收缩 |
| v_size_policy  | 高度调整策略 | 取值同h_size_policy    |
||


以下方法为ui元素均支持的公共方法：

 - `function getopt(property)`

   > `property`： string
   >
   > 返回：不同属性返回类型不同

   获取ui元素的属性property，不存在返回nil

 - `function setopt(property, val)`

   > `property`： string
   > 
   > `val`: 不同属性类型不同
   >
   > 返回：true/false

   设置ui元素的属性property为val

 - `function data(key)`

   > `key`： string
   > 
   > 返回：string

   读取ui元素data中为key的属性。常见用法是在xml中设置属性`data:key`，之后在lua代码中读取，用于存储一些附加属性。

 - `function setstyle(file, vals)`

   > `file`： string
   > 
   > `vals`： table，变量表，可选
   >
   > 返回：无

   设置ui元素的样式，具体见[样式](#样式)。如果`file`是有效文件路径，会读取文件内容设置样式，否则会直接将`file`作为样式内容进行设置。KikoPlay会对样式中出现在`vals`里的变量进行替换，参考[样式](#样式)

 - `function addchild(content)`

   > `content`： string
   > 
   > 返回：成功返回子ui元素，失败返回nil

   为ui元素添加子节点，节点内容用xml描述。如果`content`是有效文件路径，会读取文件内容，否则会直接解析`content`。

 - `function getchild(id)`

   > `id`： string
   > 
   > 返回：成功返回子ui元素，失败返回nil

   获取ui元素指定id的子节点。

 - `function removechild(child)`

   > `child`： string/ui元素
   > 
   > 返回：空

   删除ui元素的子节点。

 - `function parent()`

   > 
   > 返回：ui元素的父元素，如果没有返回nil

   获取ui元素的父元素。

 - `function onevent(event, func)`

   > `event`： string
   > 
   > `func`: function
   >
   > 返回：空

   绑定事件event响应函数为func。同一个事件只能绑定一个响应函数，重复绑定之前的会失效。

 - `function adjustsize()`

   > 
   > 返回：空

   自动调整ui元素的尺寸来适应内容。

## 事件绑定
在xml中，事件绑定通过属性来设置。事件在event命名空间内，即属性名为 `event:事件名`，例如为按钮的点击事件绑定处理函数：
```xml
 <button title="btn" event:click="onBtnClick"/>
```
默认情况下，绑定的事件处理函数要放到`app`表下。如果要将事件绑定到`app`表内的其他表里的处理函数，例如`app.page1`，可以这样写：
```xml
<button title="btn" event:click="page1.onBtnClick"/>
```
这样做可以将扩展App划分为不同模块，事件绑定到不同模块中处理。

在lua中，可以通过成员函数`onevent`绑定事件处理函数，对于动态创建的ui元素比较有用。

KikoPlay会向事件处理函数传递一个类型为table的参数，对于由ui元素触发的事件，table中都会包含两个成员：
 - srcId：触发事件的ui元素的id
 - src：触发事件的ui元素

## 容器
容器是一类可以容纳其他ui元素的元素，目前有五种：view, vview, hview, sview, gview。大部分容器包含布局，位于容器中的子元素将会按布局排列。子元素通常需要设置在容器中的位置、距离等布局依赖属性，这类布局依赖属性的命名空间是`view-depend`，以下是全部的布局依赖属性：
|  属性               | 含义  | 取值 |  适用容器 |
|  -----              | ----  | ---- | ----|
| leading-spacing     | ui元素位置之前的距离  |    |  hview, vview |
| trailing-spacing    | ui元素位置之后的距离  |    |  hview, vview |
| leading-stretch     | ui元素位置之前的伸缩因子  |    |  hview, vview |
| trailing-stretch    | ui元素位置之后的伸缩因子  |    |  hview, vview |
| stretch             | ui元素的伸缩因子  |    |  hview, vview |
| align               | 对齐方式 |  可以用或运算组合：<br/> 0x1(left) 0x2(right), 0x4(hcenter) 0x8(justify) <br/> 0x20(top) 0x40(bottom) 0x80(vcenter) 0x100(baseline)  |  hview, vview， gview |
| row                 | 行  |    |  gview |
| col                 | 列  |    |  gview |
| row-span            | 行跨度 |    | gview |
| col-span            | 列跨度 |    | gview |
| row-stretch         | 行伸缩因子  |    |  gview |
| col-stretch         | 列伸缩因子  |    |  gview |
||||

容器有以下公共属性：
|  属性           | 含义  | 取值 |
|  -----         | ----  | ---- |
| spacing        | 布局中元素之间的默认距离 |    |
| content_margin | 容器的边缘空白 | 格式为 left,top,right,bottom   |
||


### view
最基础的容器，不包含任何布局。

### hview
水平布局容器，子ui元素会按水平排列。

### vview
垂直布局容器，子ui元素会按垂直排列。

### gview
网格布局，通过`row`和`col`布局属性将子ui元素放到不同的网格内。gview还有以下属性：
|  属性       | 含义  | 取值 |
|  -----      | ----  | ---- |
| h_spacing   | 布局中元素水平方向的默认距离 |   |
| v_spacing   | 布局中元素垂直方向的默认距离 |   |
| row-stretch | 行伸缩因子 | 格式为：row1:stretch1(;row2:stretch2;...)   |
| col-stretch | 列伸缩因子 | 格式为：col1:stretch1(;col2:stretch2;...)   | 
||

注意，布局依赖属性中的`row-stretch`和`col-stretch`只能设置ui元素所在行/列的伸缩因子，gview的
`row-stretch`和`col-stretch`属性可以设置多行/多列。

### sview
堆叠布局，在构建多个页面时很有用。sview的每个元素将占据一个页面，可通过属性`current_index`获取/设置当前页面，页面从1开始。sview还有以下属性：
|  属性       | 含义  | 取值 |
|  -----      | ----  | ---- |
| current_index   | 当前页 | 从1开始   |
| stack_mode   | 堆叠模式 | one: 仅当前页面可见(默认)，all: 全部页可见  |
| count | 页面数量(只读属性) |  |
||

## UI组件
本节将列出扩展App可用的全部UI组件。

### button
按钮组件。 

#### 属性
|  属性        | 含义   | 取值 |
|  -----       | ----  | ---- |
| title        | 按钮标题 |    |
| checkable    | 按钮是否可选中  | true/false |
| checked      | 按钮是否已选中， 只有checkable=true才能设置选中| true/false |
| btn_group | 按钮组，位于同一个按钮组的按钮只有一个可被选中 |  |
||

#### 方法
 - `function click()`
   >
   > 返回：空

   模拟按钮点击。

#### 事件
|  事件        | table中的参数   | 描述 |
|  -----       | ----  | ---- |
| click        |  |  点击事件  |
||

### checkbox
复选框组件。 

#### 属性
|  属性        | 含义   | 取值 |
|  -----       | ----  | ---- |
| title        | 标题 |    |
| check_state  | 复选框选中状态  | 0：未选中 1：部分选中 2：选中 |
| checked      | 按钮是否已选中， 只有checkable=true才能设置选中| true/false |
| btn_group | 按钮组，位于同一个按钮组的按钮只有一个可被选中 |  |
||

#### 方法
 - `function click()`
   >
   > 返回：空

   模拟点击。

#### 事件
|  事件        | table中的参数   | 描述 |
|  -----       | ----  | ---- |
| check_state_changed    | state: 复选框选中状态 |  复选框状态变化事件  |
||

### combo
下拉列表组件。 

#### 属性
|  属性        | 含义   | 取值 |
|  -----       | ----  | ---- |
| text        | 下拉框文本 |    |
| items  | 列表条目（只写属性）  | 用","分隔多个条目 |
| current_index      | 当前选择项目索引| 从1开始，未选择为0 |
| editable | 是否可编辑 | true/false |
| count | 条目数量（只读属性） |  |
||

#### 方法
 - `function append(item)` 

   `function append(items)` 
   > `item`： string/table，单个item
   >
   > `items`： array of item，多个item
   > 返回：空

   向下拉列表中添加条目，支持同时添加单个或多个条目。 

   item：一个字符串，或者一个table：
   ```lua
    {
        ["text"]="条目标题",
        ["data"]="条目附加数据"
    }
   ```
   使用table可以设置item的其他属性，这里支持通过`data`项为item附加一些其他数据，`data`支持lua的各种数据结构，例如table。示例：
   ```lua
    combo:append("条目1")
    combo:append({"条目2", "条目3"})
    combo:append({["text"]="条目4", ["data"]="test data"})
    combo:append({
        {["text"]="条目5", ["data"]="test data"},
        {["text"]="条目6", ["data"]="test data2"},
        "条目7"
    })
   ```

 - `function insert(pos, item)` 

   `function insert(pos, items)` 
   > `pos`： 插入位置，从1开始
   >
   > `item`： string/table，单个item
   >
   > `items`： array of item，多个item
   > 返回：空

   向下拉列表的指定位置插入条目，`item`和`items`的定义同`append`方法。

 - `function item(index)` 
   > `index`： 条目索引，从1开始
   >
   > 返回：table结构的item

   获取指定位置的item。

 - `function remove(index)` 
   > `index`： 条目索引，从1开始
   >
   > 返回：空

   删除指定位置的条目。

- `function clear()` 
   >
   > 返回：空

   清空列表。

#### 事件
|  事件        | table中的参数   | 描述 |
|  -----       | ----  | ---- |
| current_changed  | index: 当前选择项目 <br/> text: 当前项目的标题 <br/> data: 当前项目的data |  下拉列表当前选择项目发生变化的事件  |
| text_changed     | text: 当前文本 |  对于支持编辑的下拉列表，文本发生变化的事件  |
||

### label
标签组件，支持设置html、图片。

#### 属性
|  属性        | 含义   | 取值 |
|  -----       | ----  | ---- |
| title        | 标签内容 |  支持直接设置html  |
| align        | 文本对齐方式 |  可以用或运算组合：<br/> 0x1(left) 0x2(right), 0x4(hcenter) 0x8(justify) <br/> 0x20(top) 0x40(bottom) 0x80(vcenter) 0x100(baseline)  |
| scale_content      | 是否缩放内容，显示图片时有效 | true/false，默认false |
| word_wrap | 是否自动换行 | true/false，默认false |
| open_link | 点击链接时是否自动打开 | true/false，默认false |
| text_selectable | 文本是否可选 | true/false，默认false |
||

#### 方法
 - `function setimg(filepath)`

   `function setimg(image)`
   > `filepath`：文件路径
   > 
   > `image`：[image对象](#image)
   >
   > 返回：空

   为label设置图片。可以设置文件路径，也可以直接设置image对象。如果为nil，则清空当前显示图片。

 - `function getimg()`
   >
   > 返回：[image对象](#image)

   获取label当前显示的图片，如果没有返回空。

- `function clear()` 
   >
   > 返回：空

   清空标签内容。

#### 事件
|  事件        | table中的参数   | 描述 |
|  -----       | ----  | ---- |
| link_click   | link: 点击的链接 |  标签内链接点击事件  |
||

### list
列表组件，可以展示文本/图片列表，也支持显示包含复杂ui元素的条目。

#### 属性
|  属性             | 含义   | 取值 |
|  -----           | ----  | ---- |
| count            | 条目数量（只读属性） |  |
| current_index    | 当前选择项目索引| 从1开始，未选择为0 |
| word_wrap        | 文本是否自动换行 | true/false，默认false |
| selection_mode   | 选择模式  | none: 不能选择 <br/> single: 单选（默认） <br/> multi：多选 |
| alter_row_color  | 是否用交替颜色绘制背景 | true/false |
| disable_h_scroll | 禁用水平滚动 | true/false |
| disable_v_scroll | 禁用垂直滚动 | true/false |
| h_scroll_visible | 水平滚动条是否可见 | true/false |
| v_scroll_visible | 垂直滚动条是否可见 | true/false |
| elide_mode       | 文本太长时，'...'的展示位置 |  left: 左侧 <br/> right: 右侧（默认） <br/> middle：中间 <br/> none：不展示  |
| view_mode        | 视图模式 | icon: 图标模式 <br/> list: 列表模式（默认） |
| icon_size        | 图标大小 | 格式为：w,h |
| grid_size        | 图标模式下网格大小 | 格式为：w,h |
| is_uniform_size  | 条目是否具有相同尺寸 | true/false，默认false |
||

#### 方法
 - `function append(item)` 

   `function append(items)` 
   > `item`： string/table，单个item
   >
   > `items`： array of item，多个item
   >
   > 返回：list当前条目数量

   向列表中添加条目，支持同时添加单个或多个条目。 

   item：一个字符串，或者一个table：
   ```lua
    {
        ["text"]="条目标题",
        ["tip"]="提示内容",
        ["fg"]="前景色",  -- 整数，例如：0xffff00
        ["bg"]="背景色",  -- 整数，例如：0xffff00
        ["align"]="对齐方式",
        ["check"]="是否包含复选框",  -- none: 无复选框，true: 选中，false：未选中
        ["icon"]="图标",  -- 可以是文件路径、图片二进制数据或者Image对象
        ["data"]="条目附加数据", -- 支持lua的各种数据结构，例如table, function
    }
   ```
   添加条目的方式和下拉列表combo类似。

 - `function insert(pos, item)` 

   `function insert(pos, items)` 
   > `pos`： 插入位置，从1开始
   >
   > `item`： string/table，单个item
   >
   > `items`： array of item，多个item
   >
   > 返回：list当前条目数量

   向列表的指定位置插入条目，`item`和`items`的定义同`append`方法。

 - `function item(index)` 
   > `index`： 条目索引，从1开始
   >
   > 返回：table结构的item

   获取指定位置的item。

 - `function remove(index)` 
   > `index`： 条目索引，从1开始
   >
   > 返回：空

   删除指定位置的条目。

- `function clear()` 
   >
   > 返回：空

   清空列表。

 - `function set(index, key, val)` 
   > `index`： 条目索引，从1开始
   >
   > `key`： 属性
   >
   > `val`： 属性值
   >
   > 返回：空

   设置指定位置条目的属性，例如`list:set(1, "text", "新标题")`。

 - `function selection()` 
   >
   > 返回：选中的items

   获取list中被选中的条目。 

 - `function scrollto(index)`
   > `index`： 条目索引，从1开始
   >
   > 返回：空

   滚动到指定位置的条目。 

 - `function setview(index, xml)` 
   > `index`： 条目索引，从1开始
   >
   > `xml`： 视图xml，可以是文件路径，也可以是xml字符串
   >
   > 返回：item的ui视图元素

   为指定位置的item设置ui元素视图。这个方法可以构造有复杂内容的item，例如item包含两行文本和一个按钮：
   ```xml
    local idx = comp_list:append("")
    local view = comp_list:setview(idx, string.format([[
        <hview> 
            <vview content_margin="0,0,0,0" view-depend:trailing-stretch="1">
                <label title="这是标题 %d" /> 
                <label title="Test View description......." />
            </vview> 
            <button id="btn" title="Button Test" />
        </hview>
        ]], idx))
    local btn = view:getchild("btn")
    btn:onevent("click", function(param) 
        kiko.log("复杂列表：" .. tostring(idx))
    end)
   ```

 - `function getview(index)` 
   > `index`： 条目索引，从1开始
   >
   > 返回：item的ui视图元素

   获取指定位置item的ui视图元素，未设置返回空。

#### 事件
|  事件                | table中的参数   | 描述 |
|  -----              | ----  | ---- |
| item_click          | item: 点击的item | item单击事件  |
| item_double_click   | item: 点击的item | item双击事件  |
| scroll_edge         | bottom: 是否滚动到底端 |  滚动到边缘的事件，如果bottom=false，表示滚动到顶端  |
||

### progress
进度条组件。 

#### 属性
|  属性   | 含义   | 取值 |
|  -----  | ----  | ---- |
| title   | 标题格式，%p 被替换为完成的百分比，%v 被替换为当前值，%m 被替换为全部的步数 |  默认为 %p%  |
| min     | 最小值  |  |
| max     | 最大值  |  |
| value   | 当前值  |  |
| text_visible   | 标题是否可见  | true/false |
| align   | 对齐方式 |  可以用或运算组合：<br/> 0x1(left) 0x2(right), 0x4(hcenter) 0x8(justify) <br/> 0x20(top) 0x40(bottom) 0x80(vcenter) 0x100(baseline)  |  hview, vview， gview |
||

#### 方法
 - `function click()`
   >
   > 返回：空

   模拟点击。

#### 事件
|  事件        | table中的参数   | 描述 |
|  -----       | ----  | ---- |
| check_state_changed    | state: 复选框选中状态 |  复选框状态变化事件  |
||

### radio
单选框组件。 默认情况下，在容器同一层的单选框只能有一个被选中。

#### 属性
|  属性      | 含义   | 取值 |
|  -----    | ----  | ---- |
| title     | 标题 |    |
| checked   | 是否已选中 | true/false |
| btn_group | 按钮组，位于同一个按钮组的按钮只有一个可被选中 |  |
||

#### 方法
 - `function click()`
   >
   > 返回：空

   模拟点击。

#### 事件
|  事件        | table中的参数   | 描述 |
|  -----     | ----  | ---- |
| toggled    | checked: 是否选中 |  选中状态变化事件  |
||

### slider
滑动条组件。

#### 属性
|  属性      | 含义   | 取值 |
|  -----    | ----  | ---- |
| min     | 最小值  |  |
| max     | 最大值  |  |
| value   | 当前值  |  |
| step    | 步长  |  |
||

#### 事件
|  事件        | table中的参数   | 描述 |
|  -----     | ----  | ---- |
| value_changed    | value: 当前值 | 滑动条当前值改变事件  |
||

### textline
单行文本组件。

#### 属性
|  属性               | 含义   | 取值 |
|  -----             | ----  | ---- |
| text               | 文本内容 |    |
| placeholder_text   | 提示文本 |  |
| editable           | 是否可编辑 | true/false |
| input_mask         | 通过input_mask可以使文本框只接受特定格式的文本，具体参考[这里](https://doc.qt.io/qt-5/qlineedit.html#inputMask-prop)  ||
| echo_mode | 回显模式，可用于密码输入场景 | 0: 显示输入的字符(默认) <br/> 1: 不显示任何内容 <br/> 2: 显示掩码 <br/> 3: 编辑时显示输入的字符，否则显示掩码 |
| show_clear_btn     | 显示清空按钮 | true/false |
||

#### 事件
|  事件        | table中的参数   | 描述 |
|  -----         | ----  | ---- |
| text_changed   | text: 当前文本 | 文本发生变化的事件 |
| return_pressed |  | 按下回车键的事件 |
||

### textbox
多行文本组件，支持展示html。

#### 属性
|  属性               | 含义   | 取值 |
|  -----             | ----  | ---- |
| text               | 文本内容 |    |
| placeholder_text   | 提示文本 |  |
| editable           | 是否可编辑 | true/false |
| open_link          | 是否允许打开链接 | true/false，默认false |
| max_line           | 最大行数  | 默认为0表示无限制 |
| word_wrap | 是否自动换行 | true/false，默认true |
| disable_h_scroll | 禁用水平滚动 | true/false |
| disable_v_scroll | 禁用垂直滚动 | true/false |
||

#### 方法
 - `function append(text, is_html)`
   > `text`: 文本内容
   >
   > `is_html`: 是否为html，可选，默认false
   >
   > 返回：空

   在文本框末尾添加文本。

 - `function toend()`
   > 返回：空

   光标移动到末尾。

 - `function clear()` 
   >
   > 返回：空

   清空文本框。

#### 事件
|  事件        | table中的参数   | 描述 |
|  -----         | ----  | ---- |
| text_changed   |  | 文本发生变化的事件 |
||

### tree
树形列表组件。

#### 属性
|  属性             | 含义   | 取值 |
|  -----           | ----  | ---- |
| count            | 最外层条目数量（只读属性） |  |
| col_count        | 列数量（只读属性） |  |
| header_visible   | 列头是否可见 | true/false，默认true |
| root_decorated   | 最外层是否显示展开/折叠按钮  | true/false，默认true |
| sortable         | 是否可排序 | true/false，默认false |
| word_wrap        | 文本是否自动换行 | true/false，默认false |
| selection_mode   | 选择模式  | none: 不能选择 <br/> single: 单选（默认） <br/> multi：多选 |
| alter_row_color  | 是否用交替颜色绘制背景 | true/false |
| disable_h_scroll | 禁用水平滚动 | true/false |
| disable_v_scroll | 禁用垂直滚动 | true/false |
| elide_mode       | 文本太长时，'...'的展示位置 |  left: 左侧 <br/> right: 右侧（默认） <br/> middle：中间 <br/> none：不展示  |
||

#### 方法
 - `function append(item)` 

   `function append(items)` 
   > `item`： array，单个item，`item[i]`指定了第i列的内容
   >
   > `items`： array of item，多个item
   >
   > 返回：添加的item对象。如果添加了单个item，直接返回这个item对象；如果添加了多个条目，返回包含全部item对象的array


   在最外层添加条目，支持同时添加单个或多个条目。 

   item：array，`item[i]`指定了第i列的内容，可以是一个字符串，也可以是table：
   ```lua
    {
        ["text"]="标题",
        ["tip"]="提示内容",
        ["fg"]="前景色",  -- 整数，例如：0xffff00
        ["bg"]="背景色",  -- 整数，例如：0xffff00
        ["align"]="对齐方式",
        ["check"]="是否包含复选框",  -- none: 无复选框，true: 选中，false：未选中
        ["icon"]="图标",  -- 可以是文件路径、图片二进制数据或者Image对象
        ["collapse"]="折叠还是展开",  -- true：折叠 false：展开
        ["data"]="条目附加数据", -- 支持lua的各种数据结构，例如table, function
    }
   ```
   示例：
   ```lua
    local tree = kiko.ui.get("tree")
    tree:setheader({"列1", "列2"})  
    tree:append({"text in col1", "text in col2"})  -- 添加一行
    -- 添加两行
    local items = tree:append({
        {"KikoPlay TreeTest", "Kikyou"},
        {{["text"]="00:01", ["bg"]=0xffff00, ["data"]="dt1"}, {["text"]="Hhhhhhhh", ["fg"]=0x0000ff}},
    })
   ```

 - `function insert(pos, item)` 

   `function insert(pos, items)` 
   > `pos`： 插入位置，从1开始
   >
   > `item`： array，单个item，`item[i]`指定了第i列的内容
   >
   > `items`： array of item，多个item
   >
   > 返回：插入的item对象。如果是单个item，直接返回这个item对象；如果添加了多个条目，返回包含全部item对象的array

   向列表的指定位置插入条目，`item`和`items`的定义同`append`方法。

 - `function item(index)` 
   > `index`： 条目索引，从1开始
   >
   > 返回：item对象

   获取指定位置的item。

 - `function remove(index)` 

   `function remove(item)` 
   > `index`： item索引，从1开始
   >
   > `item`：item对象
   >
   > 返回：空

   删除指定位置的item，或删除item对象。

- `function clear()` 
   >
   > 返回：空

   清空列表。

 - `function indexof(item)` 
   > `item`： item对象
   >
   > 返回：item对象在其父节点中的索引

   获取item在父节点中的索引。

 - `function selection()` 
   >
   > 返回：array of items

   获取选中的items。 

 - `function setheader(headers)`
   > `headers`： array of string
   >
   > 返回：空

   设置列。 

 - `function headerwidth(get_or_set, col, width)` 
   > `get_or_set`： "get"/"set"，获取列宽还是设置列宽
   >
   > `col`： 列索引，从1开始
   >
   > `width`：列宽，如果是"get"，忽略这个参数
   >
   > 返回：如果是"get"，返回对应列宽，否则为空

   设置/获取指定列的宽度。

#### item对象方法
item对象包含一系列方法来支持构建树：

 - `function append(item)` 

   `function append(items)` 
   > `item`： array，单个item，`item[i]`指定了第i列的内容
   >
   > `items`： array of item，多个item
   >
   > 返回：添加的item对象。如果添加了单个item，直接返回这个item对象；如果添加了多个条目，返回包含全部item对象的array


   为item添加子item，支持同时添加单个或多个条目，参数和tree的`append`方法相同。    示例：
   ```lua
    local tree = kiko.ui.get("tree")
    tree:setheader({"列1", "列2"})  
    -- 添加两行
    local items = tree:append({
        {"KikoPlay TreeTest", "Kikyou"},
        {{["text"]="00:01", ["bg"]=0xffff00, ["data"]="dt1"}, {["text"]="Hhhhhhhh", ["fg"]=0x0000ff}},
    })
    -- 向第二行添加子item
    items[2]:append({
      {{["text"]="00:01", ["fg"]=0xff0000, ["data"]="dt2"}, "child 1"},
    })
   ```

 - `function insert(pos, item)` 

   `function insert(pos, items)` 
   > `pos`： 插入位置，从1开始
   >
   > `item`： array，单个item，`item[i]`指定了第i列的内容
   >
   > `items`： array of item，多个item
   >
   > 返回：插入的item对象。如果是单个item，直接返回这个item对象；如果添加了多个条目，返回包含全部item对象的array

   向item下的指定位置插入条目，`item`和`items`的定义同`append`方法。

- `function parent()` 
   > 返回：item的父item

   获取item的父item，如果没有返回空。

 - `function child(index)` 
   > `index`： 条目索引，从1开始
   >
   > 返回：item对象

   获取指定位置的子item。

- `function childcount()` 
   > 返回：子item数量

   获取子item数量。

 - `function remove(index)` 

   `function remove(item)` 
   > `index`： item索引，从1开始
   >
   > `item`：item对象
   >
   > 返回：空

   删除指定位置的子item，或删除子item对象。

- `function clear()` 
   > 返回：空

   清空子item。

 - `function indexof(item)` 
   > `item`： item对象
   >
   > 返回：item对象在其父节点中的索引

   获取item在父节点中的索引。
  
- `function scrollto()` 
   > 返回：空

   滚动到item位置。

 - `function get(col, key)` 
   > `col`： 列索引，从1开始
   >
   > `key`： 属性
   >
   > 返回：item指定列的属性

   获取item指定列的属性，例如`item:get(1, "text")`。`icon`属性无法获取。

 - `function set(col, key, val)` 
   > `col`： 列索引，从1开始
   >
   > `key`： 属性
   >
   > `val`： 属性值
   >
   > 返回：空

   设置item指定列的属性，例如`item:set(1, "text", "新标题")`。


#### 事件
|  事件                | table中的参数   | 描述 |
|  -----              | ----  | ---- |
| item_click          | item: 点击的item | item单击事件  |
| item_double_click   | item: 点击的item | item双击事件  |
| scroll_edge         | bottom: 是否滚动到底端 |  滚动到边缘的事件，如果bottom=false，表示滚动到顶端  |
||

### window
目前app仅包含一个窗口，由KikoPlay创建。
#### 属性
|  属性        | 含义   | 取值 |
|  -----       | ----  | ---- |
| title        | 标题 |    |
| pinned       | 窗口是否顶置  | true/false |
| content_margin | 窗口的边缘空白 | 格式为 left,top,right,bottom   |
||

#### 方法
 - `function show()`
   >
   > 返回：空

   显示窗口。

 - `function raise()`
   >
   > 返回：空

   前置窗口。

 - `function message(msg, flag)`
   > `msg`: 消息内容，string
   >
   > `flag`：标志
   >
   > 返回：空

   显示提示消息。`flag`有以下取值，可以用或运算组合：
   ```lua
    kiko.msg.NM_HIDE           -- 自动隐藏
    kiko.msg.NM_PROCESS        -- 显示loading图标
    kiko.msg.NM_SHOWCANCEL     -- 显示取消按钮，目前无意义
    kiko.msg.NM_ERROR          -- 错误消息
    kiko.msg.NM_DARKNESS_BACK  -- 背景变暗
   ```
   默认情况下`flag = kiko.msg.NM_HIDE`，表示消息过一段时间后会自动隐藏。


## UI相关类型
### Image
Image类目前提供了简单的图片读写功能。
#### 创建Image
`createimg`方法位于`kiko.ui`中。
 - `function createimg(path)`

   `function createimg(params)`
   > `path`: 文件路径
   >
   > `params`：参数table
   > ```lua
   > {
   >   ["w"]=100, -- 宽，可选
   >   ["h"]=100, -- 高，可选
   >   ["data"]="", --图片二进制数据
   >   ["format"]=5, --格式，可选，参考 https://doc.qt.io/qt-5/qimage.html#Format-enum
   > }
   >```
   >
   > 返回：image对象

   可以直接从文件加载，也可以通过params table从二进制数据加载。
  
   如果指定了宽/高，会对图片进行缩放。

#### Image对象方法
- `function size()`
   >
   > 返回：w, h

   获取图片尺寸。

 - `function save(path)`
   > `path`：保存路径，string
   >
   > 返回：true/false，是否保存成功

   保存图片到文件。

 - `function tobytes(format)`
   > `format`: 格式，可选，默认为jpg
   >
   > 返回：图片二进制数据

   将图片保存为二进制数据。

 - `function scale(w, h, mode)`
   > `w`：宽度
   >
   > `h`：高度
   >
   > `mode`：模式，0:自由缩放(默认) 1:控制比例，确保图片在矩形内 2:控制比例，图片占满矩形
   >
   > 返回：缩放后的图片

   对图片进行缩放。

### 通用对话框
`kiko.dialog`中包含如下函数，用于创建通用对话框：
 - `function openfile(options)`
   > `options`: table，对话框选项:
   > ```lua
   >{
   >   title="对话框标题",
   >   path=env.app_path, -- 默认路径  
   >   filter="Images (*.jpg *png);;all (*.*)",  -- 过滤器
   >   multi = false  -- 是否支持选择多个文件
   >}
   >```
   >
   > 返回：选择文件返回路径(string, or array of string，对应多个文件)，未选择文件返回nil

   显示打开文件对话框。
  

 - `function savefile(options)`
   > `options`: table，对话框选项：
   > ```lua
   >{
   >   title="对话框标题",
   >   path=env.app_path, -- 默认路径  
   >   filter="Images (*.jpg *png);;all (*.*)",  -- 过滤器
   >}
   >```
   >
   > 返回：保存文件路径，取消则返回nil

   显示保存文件对话框。

 - `function selectdir(options)`
   > `options`: table，对话框选项：
   > ```lua
   >{
   >   title="对话框标题",
   >   path=env.app_path, -- 默认路径  
   >}
   >```
   >
   > 返回：目录路径，取消则返回nil

   显示选择目录对话框。

 - `dialog(dialog_config)`

    > `dialog_config`：Table，配置对话框显示内容，内容包括：
    > ```lua
    > {
    >    ["title"]=string,  --对话框标题，可选
    >    ["tip"]=string,    --对话框提示信息
    >    ["text"]=string,   --可选，存在这个字段将在对话框显示一个可供输入的文本框，并设置text为初始值
    >    ["image"]=string   --可选，内容为图片数据，存在这个字段将在对话框内显示图片
    > }
    > ```
    > 返回：bool，string

    展示一个对话框，第一个返回值表示用户点击接受(true)还是直接关闭(false)，第二个返回值为用户输入的文本

## 样式
App同样支持Qt里的样式表，通过`setstyle`对ui元素及其子元素加载样式。具体请参考[Qt Style Sheets](https://doc.qt.io/qt-5/stylesheet.html)。写法基本和css一致，KikoPlay做了一些扩展：

 - 变量替换

    标识符前有@表示是一个变量，KikoPlay会尝试进行替换，默认内置的变量：
    ```
    @AppPath：app路径
    @AppDataPath: app数据路径
    @StyleBGMode: 是否启用主题色
    @ThemeColor： 主题色
    @ThemeColorL1：主题色-提高亮度
    @ThemeColorL2
    @ThemeColorL3
    @ThemeColorL4
    @ThemeColorL5
    @ThemeColorD1：主题色-降低亮度
    @ThemeColorD2
    @ThemeColorD3
    @ThemeColorD4
    @ThemeColorD5
    ```
    在`setstyle`的第二个参数中可以自定义其他变量。

  - 分支控制
    
    KikoPlay支持在QSS中使用条件语句，需要配合bool类型的变量，例如在启用主题色的情况下设置border-color：
    ```css
    @if{StyleBGMode}
        border-color:rgb(@ThemeColor);
    @else
        border-color:#1CA0E4;
    @endif
    ```

## include节点

通过include节点来包含其他xml文件，这样可以将app划分为不同模块/页面。include节点的属性会应用到被引用的文件的根节点上。示例：
```xml
<sview id="page">
    <include content_margin="0,0,0,0"> pages/page_widgets.xml  </include>
    <include content_margin="0,0,0,0"> pages/page_interaction.xml  </include>
    <include content_margin="0,0,0,0"> pages/page_network.xml  </include>
</sview>
```
