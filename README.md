# dart-vm

`dart-vm` 是一个本地调试命令行工具，用于通过 Dart VM Service 查看运行中
Dart / Flutter App 的信息。当前提供网络采集、Flutter UI Inspector 和通用 VM Service
extension 调用能力；它不会发起、重放或修改业务请求。

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

也可以在开始一轮调试时保存 URI，后续命令直接复用：

```bash
dart-vm config uri set '<VM_SERVICE_URI>'
dart-vm config uri show
dart-vm config uri clear
```

URI 来源优先级为：命令行 `--uri`、环境变量 `DART_VM_SERVICE_URI`、本地保存值。
三者都没有时命令会报错。目标 App 重启导致保存的 URI 失效时，命令会提示重新执行
`dart-vm config uri set '<VM_SERVICE_URI>'`。

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

## Flutter UI

UI 命令依赖 Flutter Debug Inspector；先用 `ui tree` 获取节点 ID。所有查询只读，截图只会写入 `--out` 指定的文件。

```bash
dart-vm ui status
dart-vm ui tree
dart-vm ui details --id='<widget-id>'
dart-vm ui layout --id='<widget-id>' --depth=1
dart-vm ui screenshot --id='<widget-id>' --width=390 --height=844 --out=widget.png
```

## 调用 VM Service extension

可以调用 App 注册的任意 VM Service isolate extension。省略 `--isolate` 时优先选择名为
`main` 的 isolate，也支持传入 isolate 名称或完整 ID。参数可重复传入，值使用 `key=value`
格式：

```bash
dart-vm extension call \
  --name 'ext.tada.analytics.list' \
  --param 'limit=20'

dart-vm extension call \
  --name 'ext.tada.analytics.list' \
  --isolate 'isolates/123' \
  --param 'limit=20'
```

extension 的返回值会原样以 JSON 输出。是否存在某个 extension 由目标 App 决定。
