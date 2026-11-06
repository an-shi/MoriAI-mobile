# Mori

Mori 是一个使用 Flutter 开发的移动端 AI 陪伴助手，当前包含对话、记忆、设置三个基础页面，对话页已接入 DeepSeek 官方 API。

## 运行

```bash
flutter pub get
flutter run
```

## 配置 API Key

API Key 在应用内配置，不需要改代码：

1. 启动应用，进入底部 **设置**。
2. 找到 **DeepSeek API**，在输入框中粘贴 API Key。
3. 点击 **保存**，回到 **对话** 即可开始聊天。
4. 之后可随时回到设置页修改或清除。

API Key 通过 `flutter_secure_storage` 保存在本机安全存储中（Android Keystore / iOS Keychain），不写入代码，也不会被 Git 跟踪。保存后下一条消息立即使用新的 Key。

## 安全说明

移动端直连 DeepSeek 时，API Key 会随请求发送到 DeepSeek。正式上线时，建议改成由自己的后端代理请求，避免 Key 暴露在客户端。

## 当前模型

默认使用 `deepseek-flash`，接口为：

```text
POST https://api.deepseek.com/chat/completions
```

返回格式为 OpenAI 兼容的流式 SSE；请求中关闭了 thinking，适合日常陪伴聊天。

如需使用 `deepseek-v4-pro`，修改 `lib/config/deepseek_config.dart` 中的 `model`。

## 目录

```text
lib/
├── config/       模型、接口地址和系统提示词
├── models/       聊天消息模型
├── pages/        对话、记忆、设置页面
└── services/     DeepSeek API 请求与 API Key 安全存储
```
