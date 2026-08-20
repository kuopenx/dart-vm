# 网络 HTTP Profile

查看运行中应用通过 `dart:io` HTTP profiler 记录的请求。应用重启后，记录会被清除。

## 操作方式

查看记录状态：

```bash
dart-vm network status
```

若 profiling 未开启，开启后重新触发目标请求：

```bash
dart-vm network on
```

只有开启后发生的请求会被记录。

列出请求，也可以按 URI 子串筛选：

```bash
dart-vm network requests
dart-vm network requests --path="/activity/"
```

使用请求 `id` 查看详情或 body：

```bash
dart-vm network request --id=-242378432789
dart-vm network request --id=-242378432789 --body
```

停止记录后续请求：

```bash
dart-vm network off
```
