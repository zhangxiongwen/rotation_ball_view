# Changelog

## 0.1.0+1

- **Fix:** `isAnimate: false` 时停止空闲循环动画（此前 `AnimationController` 仍会 `forward` 并循环）。

## 0.1.0

- `RotationBallView`: Fibonacci 球面标签云，`itemBuilder` / `onItemTap` / `isAnimate` / 可选 `decoration`；球半径为布局 **min(宽, 高) / 2**（`LayoutBuilder` + `ballRadiusFromLayout`）；`MediaQuery` 由组件内部 `context` 读取。
- Example：含 **`isAnimate` 开关** 演示空闲旋转与拖动惯性。
