# binaryu/workbuddy2api — 自用 fork

上游：[linguo2625469/workbuddy2api-panel](https://github.com/linguo2625469/workbuddy2api-panel)（活跃维护的那份）。

本 fork 只加两件事：**每账号独立 socks5 出口代理**（+ 代理 MITM 时的 TLS 免校验）、**`/v1/responses` 适配层**（Codex 接入）。
其余代码与上游一致，不夹带别的扩展（上游作者在 #109 明确拒绝过打包式扩展，#153 里也说过暂不做代理，
所以这两层只在本 fork 维护，不提 PR）。

## 相对上游的差异

两个提交，落在 `main` 上（按功能分开，便于 rebase 时定位冲突）。

| 改动 | 位置 |
|---|---|
| socks5 解析 / 连通性探测 / 失效自愈 / `data/proxies.json`(0600) 持久化 | `internal/proxypool/`（新增） |
| 按账号 uid 在请求构造期选路，未分配代理则直连；代理级 `|insecure` 与全局 `upstream.tls_skip_verify` | `internal/upstream/router.go`（新增）、`transport.go`、`client.go`、`cmd/server/main.go` |
| 面板「代理池」视图 + 账号池每行「代理」按钮（批量添加 / 按 IP 顺序分配 / 同一个 IP / 一键清除 / 探测） | `internal/panel/proxies.go`（新增）、`panel.go`、`app.js`、`index.html` |
| `/v1/responses` 适配层（Responses ↔ Chat Completions 双向翻译，含流式事件序列、工具调用、命名空间工具拍平、usage 口径） | `internal/server/responses.go`（新增）、`handler.go` |
| 面板「接入」页（Base URL / API Key 自动推导、Codex `config.toml` 片段、curl / Python 示例、模型列表点选复制） | `internal/panel/app.js`、`index.html` |

代理不可用时请求失败并记错，**不静默回落到直连**；未分配代理的账号行为与上游完全一致。

写法：`socks5://user:pass@1.2.3.4:1080`、`socks5h://1.2.3.4:1080`、`user:pass@1.2.3.4:1080`、
`1.2.3.4:1080:user:pass`，行尾可接 `|备注`、`|insecure`。落盘文件在 `data/` 下（docker-compose 已挂载 `./data`）。

## 同步上游

```bash
./sync-upstream.sh            # fetch upstream → rebase → go build + go test → force-with-lease 推 main
./sync-upstream.sh --no-push  # 只看不动远端
```

冲突通常落在 `internal/panel/app.js`、`panel/index.html`、`panel/panel.go`、`cmd/server/main.go`、
`internal/upstream/client.go`、`internal/server/handler.go`、`README.md` —— 因为上游也在改面板和配置，冲突跟「作者做不做代理」无关。
解冲突时的经验（2026-10 实测一次）：
- `Client.SanitizeFingerprints` 上游已改成 `atomic.Bool`，赋值要走 `.Store(...)`；
- 面板 overview 的 map 字面量里，`accounts` 用 `p.accountsWithProxy()`（`pool.List()` 的超集，多带 `proxy` 字段），
  同时保留上游新增的 `model_locks`。

## 部署

与上游一致（`cp config.example.json config.json`，`docker compose up -d` 或直接跑二进制）。
GitHub Actions 会在每次 push 后构建五平台二进制并推镜像 `ghcr.io/binaryu/workbuddy2api:latest`。

## Codex 接入

面板左侧「接入」页会按你当前访问地址生成配置，或手写：

```toml
# ~/.codex/config.toml
model = "cn:glm-5.2"
model_provider = "wb2api"
model_context_window = 200000

[model_providers.wb2api]
name = "WorkBuddy2API"
base_url = "http://127.0.0.1:7863/v1"
env_key = "WB2API_KEY"
wire_api = "responses"
```

```bash
export WB2API_KEY=<config.json 里的 api_key>
codex exec "只回答两个字：你好"
```
