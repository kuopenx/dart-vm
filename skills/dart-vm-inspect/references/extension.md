# VM Service Extension

调用应用已注册的 VM Service extension，并输出 JSON 结果。extension 名称、参数和响应结构从项目文档或源码获取。

## 操作方式

调用 main isolate：

```bash
dart-vm extension call \
  --name="ext.example.status" \
  --param="limit=20"
```

需要时按名称或 ID 指定 isolate；多个参数重复传入 `--param`：

```bash
dart-vm extension call \
  --name="<extension-name>" \
  --isolate="<isolate-name-or-id>" \
  --param="key1=value1" \
  --param="key2=value2"
```
