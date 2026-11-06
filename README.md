# Mori

Mori 是一个使用 Flutter 开发的移动端 AI 陪伴助手，当前包含对话、记忆、设置三个基础页面，对话页已接入 DeepSeek 官方 API。

## 运行

```bash
flutter pub get
flutter run
```

## 配置 API Key 和模型

API Key 和模型都在应用内配置，不需要改代码：

1. 启动应用，进入底部 **设置**。
2. 找到 **DeepSeek API**，在输入框中粘贴 API Key。
3. 点击 **保存**。
4. 在 **对话模型** 下拉框中选择模型，选择后立即保存。
5. 回到 **对话** 即可开始聊天。

API Key 通过 `flutter_secure_storage` 保存在本机安全存储中（Android Keystore / iOS Keychain），不写入代码，也不会被 Git 跟踪。模型选择通过 `shared_preferences` 保存在本地。修改后下一条消息立即使用新的配置。

## 安全说明

移动端直连 DeepSeek 时，API Key 会随请求发送到 DeepSeek。正式上线时，建议改成由自己的后端代理请求，避免 Key 暴露在客户端。

## 模型

设置页提供官方当前模型：

- **DeepSeek Flash**（`deepseek-flash`）：响应更快，适合日常陪伴聊天，默认选项。
- **DeepSeek V4 Pro**（`deepseek-v4-pro`）：能力更强，适合复杂问题，价格更高。

接口：

```text
POST https://api.deepseek.com/chat/completions
```

返回格式为 OpenAI 兼容的流式 SSE；请求中关闭了 thinking，适合日常陪伴聊天。

## 目录

```text
lib/
├── config/       模型列表、接口地址和系统提示词
├── models/       聊天消息模型
├── pages/        对话、记忆、设置页面
└── services/     DeepSeek API、API Key 与模型选择的存储
```
