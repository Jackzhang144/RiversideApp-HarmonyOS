# Topic 创作、编辑与草稿验证记录

日期：2026-07-14

## 结论

Topic/Post 创作、指定 Post 引用、服务端许可编辑、Markdown/Emoji/投票工具、显式重试和服务端草稿状态已经接入正式 ArkUI 流程。自动化、主 HAP 构建和 API 23 模拟器 UI 冒烟通过。

真实服务拒绝路径通过：普通测试账号向固定 Category `111` 创建 Topic 时，服务端返回 `404 not_found`；编辑器完整保留标题和正文并只提供用户触发的显式重试，没有自动重发，也没有产生论坛数据。当前账号的真实 Category 列表不再包含 `111`，因此成功创建、回复和编辑的真实写入回读被外部服务状态阻塞。应用据此同时检查账号创建许可与 Category `111` 可见性，不满足时禁用首页新建入口。

## 环境

- 设备：`Mate 70 Pro` phone emulator
- 系统：HarmonyOS API 23 Release
- 设备序列：`127.0.0.1:5555`
- 账号：已认证普通测试账号；未记录 User API Key、client id 或其他会话材料

## 自动验证

从 `app/` 工程根目录执行：

```bash
devecocli build --modules entry
devecocli build --modules entry@ohosTest
devecocli run --module entry@ohosTest --device 127.0.0.1:5555 --skip-build
hdc -t 127.0.0.1:5555 shell aa test \
  -b cc.river_side_hm.app \
  -m entry_test \
  -s unittest OpenHarmonyTestRunner \
  -s timeout 60000
```

结果：`129/129` 通过，`0 Failure / 0 Error / 0 Ignore`，`OHOS_REPORT_CODE: 0`。

覆盖范围：

- 文本选择上的粗体、斜体、H1-H4、链接、引用、行内/块代码、有序/无序/待办/完成列表、隐藏、目录、表格和数学公式转换。
- 冻结的 Discourse 单选/多选投票模板。
- 跨楼层指定 Reply 的作者、Topic id 和 Post number 引用语义。
- 新 Topic 固定 Category `111`，服务端拒绝后保留内容并等待显式重试。
- 仅允许编辑服务端 `canEdit` 为真的 Category `111` Post；失败不覆盖本地已显示正文。
- Topic 与 Reply 草稿的恢复、sequence 续写、舍弃和成功后清理；清理失败时可见报错并抑制旧草稿回流。
- Category `111` 之外同时隐藏 Reply 入口并在模型层拒绝提交。
- 401 后保留草稿并在重新认证后恢复编辑。

## 模拟器 UI 冒烟

1. 首页 `+` 可进入正式新建 Topic 页面，页面明确显示“仅发布到测试专用 Category #111”。
2. 标题、正文、保存草稿、舍弃、发布按钮以及图片后续切片提示均可见。
3. 工具栏在真实 `TextArea` 光标位置将 `hello` 转换为 `hello**粗体文本**`；未触发网络写入。
4. 编辑器代码已接入 Emoji 选择菜单、H1-H4、链接、引用、行内/块代码、有序/无序/待办/完成列表、隐藏、目录、表格、数学公式、单选/多选投票和禁用图片按钮；本轮通过 ArkTS 编译与模板单测覆盖，未逐一手工点按。
5. 输入法展开和收起后编辑内容保持，舍弃空 sequence 草稿不会调用服务端删除接口。

## 真实服务证据与阻塞

1. 已认证普通测试账号身份加载成功，页面显示全局“可发帖”能力。
2. 使用唯一标记准备 Category `111` Topic，发布请求只发送一次。
3. 服务端返回 `404`；网络日志确认是一次 `POST`，响应后 UI 显示“服务器返回 404”和“显式重试”。
4. 标题、正文仍在编辑器中，没有自动重发；随后人工舍弃，未创建 Topic。
5. 当前已认证 Category 页面不包含 `111`；匿名读取 `/c/111/show.json` 同样返回 `not_found`。这与三天前 MVP 验证时 Category `111` 可用的服务状态不同。

恢复成功写验收的前提：服务端重新向普通测试账号开放 Category `111` 后，在该 Category 创建一次唯一标记 Topic，随后只在该 Topic 内完成指定 Reply、Post/Topic 编辑、草稿保存/恢复/删除和最终回读。禁止改用其他 Category 绕过此门槛。
