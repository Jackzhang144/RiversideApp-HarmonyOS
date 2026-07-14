# 安全富内容与链接导航验证记录

日期：2026-07-14  
设备：Mate 70 Pro Phone 模拟器，API 23 Release  
账号：普通测试账号（不记录用户名或认证材料）

## 实现边界

- Topic/Post 的 Markdown 与 cooked HTML 解析为原生 ArkUI 内容块，覆盖正文、标题、引用、代码、公式、剧透、列表、表格、图片和 onebox。
- 列表解析支持嵌套内容并保留列表项内链接；所有 URL 在执行导航前经过 scheme、host 与站内路径策略分类。
- `river-side.cc` Topic/Profile 进入原生页面；普通 HTTPS 外链必须先经过明确确认，再调用系统外链能力。
- Bilibili/YouTube 只进入独立 ArkWeb 页面。该页面不注册 JavaScript bridge，禁用文件访问，使用 `MixedMode.None`，SSL 错误直接取消，并按供应商精确 host/path 白名单拦截页面与子资源导航。
- ArkWeb 页面优先消费自身后退历史，再退出到原生导航栈；加载错误显示可返回的失败状态。

## 自动化与构建

从仓库根目录执行：

```bash
scripts/verify-mvp-api23.sh 127.0.0.1:5555 emulator
```

结果：

- `entry@ohosTest` ArkTS 编译、签名、安装和启动通过。
- 11 个必需测试套件共 `137/137` 通过，`0 Failure / 0 Error / 0 Ignore`，`OHOS_REPORT_CODE: 0`。
- `RichContent` 针对性测试 `8/8` 通过，覆盖富内容块、Markdown 回退、嵌入识别、站内原生路由、危险 scheme/伪装 host 拒绝、ArkWeb 精确白名单、列表项链接和嵌套列表。
- 主 `entry` HAP ArkTS 编译、签名、安装和启动通过。
- 自动回归结束后没有检测到应用崩溃。

## 模拟器真实服务冒烟

1. 从 Home 进入真实 Topic，正式 Topic 页面成功渲染标题、段落、奖励规则、列表、链接和图片，没有把不受信任 Post HTML 整页交给 ArkWeb。
2. 点击正文图片链接后显示“打开外部链接？”确认框，包含目标 URL、“取消”和“继续打开”；取消后仍停留在 Topic。
3. 返回导航正常，应用崩溃日志为空。

本次真实 Topic 样本不含 Bilibili/YouTube 视频，因此模拟器冒烟没有实际播放嵌入视频；嵌入 URL 生成、精确导航白名单、危险 URL 拒绝和 ArkWeb 配置边界由自动测试与 ArkTS 编译覆盖。

## 当前阻塞与验收结论

当前 `devecocli device list` 只有 API 23 模拟器，没有 API 23 物理 Phone。实体设备上的 Bilibili/YouTube 实际加载、播放、返回历史、SSL/混合内容行为和真实硬件 ArkWeb 差异仍为 `blocked`。

因此本切片的实现、自动化、构建和模拟器内容回归均通过，但 Issue 中“物理 Phone 的 ArkWeb/嵌入验收均通过”这一项不能标记完成。连接 API 23 物理 Phone 后，应先执行同一自动回归脚本，再用各一个真实 Bilibili 与 YouTube Topic 样本验证播放、白名单拦截、外链确认和 Web 历史返回。
