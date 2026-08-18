# dart-vm

`dart-vm` 是一个本地调试命令行工具，用于通过 Dart VM Service 查看运行中
Dart / Flutter App 的信息。当前提供运行会话发现、网络采集、Flutter UI Inspector 和
通用 VM Service extension 调用能力；它不会发起、重放或修改业务请求。

## 安装

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/kuopenx/dart-vm/main/install.sh | sh
```

支持 macOS Apple Silicon、macOS Intel 和 Linux x64。安装位置：

```text
~/.local/bin/dart-vm
```

请确保 `~/.local/bin` 已加入 `PATH`。zsh 可以在 `~/.zshrc` 中加入：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Windows

```powershell
irm https://raw.githubusercontent.com/kuopenx/dart-vm/main/install.ps1 | iex
```

支持 Windows x64。安装位置：

```text
%LOCALAPPDATA%\dart-vm\dart-vm.exe
```

如果安装目录尚未加入用户 `PATH`，安装脚本会打印需要配置的目录。

安装完成后验证：

```bash
dart-vm --version
dart-vm --help
```

如果下载或升级失败，可以直接重新运行对应平台的安装命令。

### 从源码构建

开发者可以在仓库根目录构建当前平台的本机二进制：

```bash
dart pub get
mkdir -p build
dart compile exe bin/dart_vm.dart -o build/dart-vm
```

源码构建产物位于 `build/dart-vm`，仅用于本地开发；正式安装使用 GitHub Release
中的预编译二进制。

## 版本与升级

```bash
dart-vm --version
dart-vm upgrade --check
dart-vm upgrade
```

`upgrade --check` 只读取 GitHub 最新 Release，不修改本机文件。`upgrade` 下载当前平台的
Release ZIP，验证 `checksums.txt` 中的 SHA-256 后原地替换当前可执行文件；已有 VM
Service URI 配置不会改变。也可以重新运行安装脚本升级。

自升级只支持安装后的 `dart-vm` 独立二进制。从源码执行
`dart run bin/dart_vm.dart upgrade` 时会拒绝覆盖 Dart SDK。

## 使用前提

- App 必须以支持 VM Service 的调试方式运行，且 VM Service 仍可连接。
- 网络能力只覆盖最终通过 `dart:io HttpClient` 发出的请求，例如 Flutter Native
  环境下使用默认 IO Adapter 的 Dio 请求；不依赖 Dio，也不覆盖 Flutter Web、
  原生侧或自定义非 `dart:io` transport。
- 可通过 `dart-vm service list` 发现本机运行会话，也可从 Flutter 调试输出或 DevTools 获取 VM Service URI。

## 配置 VM Service URI

无法直接取得 URI 时，可以发现由本机 Flutter CLI 或 IDE 启动、当前仍可连接的 VM
Service。结果包含设备名、package、进程 PID 和 URI；该命令不会读取或修改已保存配置：

```bash
dart-vm service list
dart-vm config uri set '<从列表选择的 VM_SERVICE_URI>'
```

存在多个会话时，根据 `deviceName`、`packageName` 和 `pid` 选择目标；`service list`
本身不会改变当前保存的 URI。

发现能力依赖本机正在运行的 `dart development-service` 进程。由其他电脑控制、且本机
没有对应 development-service 和端口转发的设备无法被发现。

每次命令显式传入 URI：

```bash
dart-vm --uri '<VM_SERVICE_URI>' network status
```

也可以设置环境变量，之后所有命令默认使用它：

```bash
export DART_VM_SERVICE_URI='<VM_SERVICE_URI>'
dart-vm network status
```

已经取得 URI 时，也可以直接保存，后续命令复用：

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
  --name 'ext.example.analytics.list' \
  --param 'limit=20'

dart-vm extension call \
  --name 'ext.example.analytics.list' \
  --isolate 'isolates/123' \
  --param 'limit=20'
```

extension 的返回值会原样以 JSON 输出。是否存在某个 extension 由目标 App 决定。
