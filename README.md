# rotation_ball_view

在 Flutter 中展示**可拖动旋转**的 3D 球面标签云：每个标签是任意 `Widget`，通过 `itemBuilder` 按 `index` 构建；支持深度缩放、半透明、点击回调 `index`。

## Demo

动图放在与 `README.md` 同级的 **`doc/`** 目录下（例如 `doc/demo.gif`），便于和源码一起发布到 pub.dev。

![RotationBallView 演示动图](doc/demo.gif)

## 安装

```yaml
dependencies:
  rotation_ball_view: ^0.1.0
```

## 用法

```dart
import 'package:flutter/material.dart';
import 'package:rotation_ball_view/rotation_ball_view.dart';

class BallPage extends StatefulWidget {
  const BallPage({super.key});

  @override
  State<BallPage> createState() => _BallPageState();
}

class _BallPageState extends State<BallPage> {
  bool _isAnimate = true;
  String _lastTap = '—';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      height: 360,
      child: RotationBallView(
        isAnimate: _isAnimate,
        itemCount: 30,
        itemBuilder: (context, index) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Item $index',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Icon(
                Icons.star_outline,
                size: 40,
                color: Colors.primaries[index % Colors.primaries.length],
              ),
            ],
          );
        },
        onItemTap: (index) {
          setState(() => _lastTap = 'index $index');
        },
        decoration: BoxDecoration(
          color: Colors.blue[400],
          borderRadius: BorderRadius.circular(180),
          boxShadow: [
            BoxShadow(
              color: Colors.red,
              blurRadius: 20.0,
            )
          ],
        ),
      ),
    );
  }
}
```

## 行为说明

- **半径**：由父组件给出的最大宽高取 `min(宽, 高) / 2`；无界时用屏幕尺寸兜底。
- **布局**：Fibonacci 球面近似均匀分布。
- **手势**：`Listener` 使用 `HitTestBehavior.translucent`，球面空白区域也可拖动旋转。
- **条目**：内部用 `FittedBox` 将内容缩放到可用区域，避免布局溢出。

## 发布到 pub

1. 修改 `pubspec.yaml` 中的 `homepage` / `repository` 为你的真实地址。
2. `dart pub publish --dry-run` 检查。
3. `dart pub publish` 发布。

## License

MIT（见 `LICENSE`）。
