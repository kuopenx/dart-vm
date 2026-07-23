# dart-vm

`dart-vm` 是一个本地调试命令行工具，用于通过 Dart VM Service 查看运行中
Dart / Flutter App 的信息。当前提供网络采集能力；它不会发起、重放或修改业务请求。

## 使用前提

- App 必须以支持 VM Service 的调试方式运行，且 VM Service 仍可连接。
- 网络能力只覆盖 `dart:io` / Dio 发出的请求。
- 先从 Flutter 调试输出或 DevTools 获取 VM Service URI。

## 配置 VM Service URI

每次命令显式传入 URI：

```bash
dart-vm --uri '<VM_SERVICE_URI>' network status
```

也可以设置环境变量，之后所有命令默认使用它：

```bash
export DART_VM_SERVICE_URI='<VM_SERVICE_URI>'
dart-vm network status
```

两者同时存在时，`--uri` 优先。

## 网络采集

```bash
# 查看采集状态。
dart-vm network status

# 开启采集；只记录此后发生的请求。
dart-vm network on

# 按路径筛选并列出已记录请求。
dart-vm network requests --path '/activity/'

# 查看一条请求的摘要。
dart-vm network request --id='<request-id>'

# 显式查看 UTF-8 请求与响应 body。
dart-vm network request --id='<request-id>' --body

# 停止记录后续请求。
dart-vm network off
```

`on` 与 `off` 只影响当前这次 App 运行；重启后采集状态和已记录数据都会丢失。
默认输出 JSON。请求和响应 headers、cookies 不会输出；body 只有传入 `--body` 时才会输出，请谨慎处理其中的敏感数据。

## 查看帮助

```bash
dart-vm --help
dart-vm help network
```
