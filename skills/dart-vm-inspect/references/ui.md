# Flutter UI 检查

查看 Flutter Widget 树、属性和布局，或截取 Widget 图片。

## 操作方式

检查 Flutter Inspector 是否可用：

```bash
dart-vm ui status
```

输出 Widget 树并获取节点 ID：

```bash
dart-vm ui tree
```

查看 Widget 属性及其详情子树：

```bash
dart-vm ui details --id="<widget-id>"
```

查看 Layout Explorer 数据：

```bash
dart-vm ui layout --id="<widget-id>" --depth=1
```

将 Widget 截取为 PNG：

```bash
dart-vm ui screenshot \
  --id="<widget-id>" \
  --width=390 \
  --height=844 \
  --out="<png-path>"
```

界面发生较大变化后，重新读取 Widget 树，再使用新的节点 ID。
