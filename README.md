# Mori

Mori 是 MoriBot 的官方 Flutter 手机客户端。当前版本以 MoriBot 为唯一数据源：角色卡、会话、消息和生成媒体都保存在服务端，手机本地只保留可重建的缓存。

## 运行

```bash
flutter pub get
flutter run
```

## 首次配对

1. 启动 MoriBot 服务端，登录后台。
2. 在后台首页点击「连接 MoriMobile」，生成一次性配对码。
3. 打开 Mori，在配对页填写：
   - 服务器地址，例如 `http://192.168.1.10:6186` 或 `https://mori.example.com`
   - 8 位配对码
   - 设备名称
4. 也可以直接粘贴 `morimobile://pair?server=...&code=...` 配对链接。
5. 配对成功后进入主界面，之后打开应用会使用安全存储中的设备令牌自动登录。

## 页面

底部导航包含三个页面：

- **对话**：MoriBot 会话列表、新建会话、下拉刷新、上拉加载更多。
- **角色**：服务端角色卡列表，可查看角色简介并开始新会话。
- **设置**：账户、服务器、设备、实时通道、清除缓存和解除配对。

聊天页支持：

- 加载和增量同步服务端历史消息
- 发送文本消息，支持强制语音回复
- 播放 MoriBot 生成的语音
- 查看 MoriBot 生成的图片
- 重命名、删除会话
- 清除本地缓存不会影响服务端数据

## 数据与缓存

- MoriBot 是角色卡、会话、消息和媒体的唯一数据源。
- 手机端通过设备令牌访问 `/api/v1/mobile/app/*`。
- 会话列表、角色卡和消息会写入本地缓存，用于快速打开页面。
- 消息按 `id` 增量同步，只有缓存缺失时才重新拉取完整历史。
- 退出配对或清除缓存后，本地数据可以安全丢弃，重新从服务端同步。
- 服务端把会话和消息保存在 SQLite，媒体保存在 `data/media/`，都会随 MoriBot 数据目录一起迁移。

## 实时通道

配对成功后，客户端会连接 MoriBot 的 WSS 实时通道，用于服务端事件和连接状态。聊天请求仍通过 HTTPS JSON API 完成；断线时页面会显示缓存并提供重试。

## 目录

```text
lib/
├── models/moribot/       MoriBot API 数据模型
├── pages/moribot/        配对、会话、角色、聊天、账户页面
├── services/moribot/     客户端、会话、缓存、消息仓库、实时通道、媒体缓存
├── ui/                   主题与通用组件
└── widgets/moribot/      MoriBot 专用头像等组件
```

## 安全说明

- 设备令牌保存在 Android Keystore / iOS Keychain 中，不写入代码或 Git。
- 手机不保存模型供应商 API Key，也不直接调用模型供应商。
- 生产环境请通过 HTTPS/WSS 暴露 MoriBot，并配置 `dashboard.public_url`、`trusted_hosts` 和 `force_https`。
- 解除配对只会清除本机令牌和缓存，不会删除服务端数据。
