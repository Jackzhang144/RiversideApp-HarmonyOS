# 06 — 原生 UI/UX 基线

**What to build:** 在 MVP 功能收口后冻结信息架构与状态语义，建立可复用的 HDS + ArkUI 原生设计基线，并将 Home、Category、Topic、账户/认证和 Reply 的高频页面骨架迁移到该基线；不在本票执行全量视觉精修。

**Blocked by:** 05 — MVP 真机验收与回归.

**Status:** ready-for-agent

## Why now

- 现有 Wayfinder 已覆盖浏览、Topic/Post、认证、Reply 与回归，没有已定义的下一张功能 Ticket。
- 先建立基线，可以让后续每个新功能直接复用统一导航、状态、排版和反馈，不继续积累页面间差异。
- 不等待所有未来功能完成；先交付设计系统与高频骨架。等一批高频功能稳定后，再另开全局体验精修工作。

## Scope

### 信息架构与状态语义

- 冻结当前 MVP 的根入口、二级页面、返回关系和 Reply 编辑位置；任何 IA 调整必须先更新基线再改页面。
- 为 Home、Category 目录、Category Topic 列表、Topic/Post、账户、ArkWeb 认证和 Reply 建立统一主路径。
- 每个页面显式定义适用的 `initial/loading/content/empty/error/unauthorized/success` 状态、恢复动作和跨页状态保持规则；不为不适用的页面强造状态。

### HDS + ArkUI 设计基线

- 定义导航、Tabs、列表项、页面安全区与间距、字体层级、语义颜色、按钮、表单、SnackBar、Reply 编辑器和可访问性文案规范。
- HDS 优先；每个实际采用的 HDS 组件和属性都要逐项确认 API 23 起始版本、Stage/Phone 支持与中国大陆地区约束。
- HDS 没有覆盖、API 23 不支持或无法满足交互语义时，使用 ArkUI 基础组件，并在基线中记录回退原因和等价行为。
- 不像素级复刻 Flutter；保留 RiverSide 的信息架构与交互语义，采用 HarmonyOS 原生层级、反馈和动效。

### 高频页面骨架

- 先建立可复用 token、页面容器和状态组件，再按 Home → Category → Topic → 账户/认证 → Reply 的顺序迁移。
- 每个页面迁移独立提交，保持功能与 API 契约不变；不得把无关业务重构混入 UI 基线提交。
- 后续所有带 UI 的功能 Ticket 默认依赖本基线，并在同一功能提交中覆盖对应状态、可访问性和 HDS/ArkUI 选择。

## Environment boundary

- API 23 模拟器只用于 ArkTS 编译、信息结构、导航、状态切换和基础交互回归。
- HDS 视觉与沉浸效果、真实软键盘遮挡/焦点、触控反馈、动效和最终可访问性体验必须在中国大陆 API 23 物理真机验收。
- 缺少物理真机不阻塞基线文档、token、组件接口和高频骨架实现，但会使本票最终状态停在 `ready-for-human`。
- 真机验收同时检查未授权和 Reply 异常状态的视觉反馈；不得把模拟器联机结果改写为真机证据。

## Delivery order

1. 盘点现有页面与 HDS/ArkUI 使用，冻结 IA、状态矩阵和可访问性语义。
2. 建立 token 与可复用页面/状态组件的最小接口；先验证 API 23 编译，再迁移页面。
3. 逐页迁移高频骨架，每步保持现有浏览、认证和 Reply 行为不变。
4. 执行 API 23 模拟器自动回归和结构交互检查，记录 HDS 模拟器限制。
5. 在 API 23 中国大陆真机完成 HDS 视觉、软键盘、触控、动效和状态反馈验收。
6. 基线稳定后开放下一批功能 Ticket；全局体验精修另立后续票据。

## Acceptance

- [ ] 形成版本化的 IA、页面状态矩阵和可访问性文案基线，覆盖浏览、Category、Topic、账户、认证与 Reply。
- [ ] 形成 HDS/ArkUI 组件与 token 基线；每个实际 HDS 用法都有 API 23 证据和 ArkUI 回退说明。
- [ ] Home、Category、Topic、账户/认证和 Reply 高频骨架使用同一导航、间距、排版、颜色、按钮、表单与反馈规范。
- [ ] 加载、空态、失败、未授权和成功反馈可恢复且语义一致，不破坏已有 API、会话与 Reply 安全行为。
- [ ] 模拟器通过 ArkTS 构建、自动回归与基础交互检查；结果不包含 HDS 最终视觉结论。
- [ ] API 23 中国大陆物理真机通过 HDS 视觉/沉浸、软键盘、触控、动效和可访问性验收。
- [ ] 基线写入后续功能 Ticket 的交付约束；全局体验精修明确留到高频功能稳定后的独立工作。

## Out of scope

- 像素级复刻 Flutter 或一次性重写全部页面。
- 为尚未进入规划的未来功能提前设计完整页面。
- 在缺少物理真机时宣称 HDS 沉浸视觉、软键盘或动效已经验收。
- 本票内执行最终全局视觉精修、品牌重塑或与 UI 基线无关的业务重构。

## References

- `docs/adr/0001-use-arkui-native-components.md`
- `docs/research/hds-api23-component-fit.md`
- `docs/verification/api23-physical-device-readiness.md`
