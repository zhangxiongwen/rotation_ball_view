import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

/// 点击球面上某一标签时的回调，参数为 [index]（`0 .. itemCount-1`）。
typedef OnRotationBallItemTap = void Function(int index);

/// 3D 旋转球标签云：每个条目由 [itemBuilder] 提供 Widget，在球面上随深度缩放与半透明。
///
/// 球半径取 **父级给出的布局范围内「宽、高」中较小边的一半**（与 [ClipOval] 内切圆一致）；
/// 某一维为无界时，用 [MediaQuery] 的屏幕尺寸兜底。
class RotationBallView extends StatefulWidget {
  const RotationBallView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.onItemTap,
    this.isAnimate = true,
    this.decoration,
  });

  /// 球面上条目数量
  final int itemCount;

  /// 每个条目对应的 Widget，[index] 为 `0 .. itemCount-1`
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// 点击某一条目时回调其 [index]
  final OnRotationBallItemTap? onItemTap;

  /// 是否启用**空闲自动旋转**（长时间循环动画）以及松手后的惯性 [AnimationController.fling] / 继续旋转。
  /// 为 `false` 时仍可手指拖动旋转，只是不会自动转。
  final bool isAnimate;

  /// 非空时在外层套 [Container] 并应用该装饰（背景、圆角、阴影等）。
  final Decoration? decoration;

  @override
  State<RotationBallView> createState() => _RotationBallViewState();
}

/// 由 [LayoutBuilder] 约束与屏幕尺寸推算球半径：`min(可用宽, 可用高) / 2`（至少为 1）。
int ballRadiusFromLayout(BoxConstraints constraints, Size screenSize) {
  double w = constraints.maxWidth;
  double h = constraints.maxHeight;
  if (!w.isFinite || w <= 0) w = screenSize.width;
  if (!h.isFinite || h <= 0) h = screenSize.height;
  final double side = min(w, h);
  return max(1, (side / 2.0).floor());
}

class _RotationBallViewState extends State<RotationBallView>
    with SingleTickerProviderStateMixin {
  /// 球半径（逻辑像素），在首次 [LayoutBuilder] 布局后按约束更新。
  int _ballRadius = 1;

  final List<RotationBallPoint> points = [];

  /// 各 index 在未缩放下的测量尺寸（用于定位与命中）
  final Map<int, Size> _itemSizes = {};

  late Animation<double> animation;
  late AnimationController controller;
  double currentRadian = 0;

  late Offset lastPosition;
  late Offset downPosition;

  Offset? _pointerDownCanvasLocal;
  bool _tapCancelledByMovement = false;

  int lastHitTime = 0;

  static const int _tapCallbackDebounceMs = 400;
  static const double _cancelMoveFromDownPx = 14.0;

  RotationBallPoint axisVector = _axisVector(Offset(2, -1));

  @override
  void initState() {
    super.initState();

    _syncLayoutFromItemCount(widget.itemCount);

    controller = AnimationController(
      duration: const Duration(milliseconds: 40000),
      vsync: this,
    );
    animation = Tween(begin: 0.0, end: pi * 2).animate(controller);
    animation.addListener(() {
      setState(() {
        for (int i = 0; i < points.length; i++) {
          _rotatePoint(axisVector, points[i], animation.value - currentRadian);
        }
        currentRadian = animation.value;
      });
    });
    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed && widget.isAnimate) {
        currentRadian = 0;
        controller.forward(from: 0.0);
      }
    });
    if (widget.isAnimate) {
      controller.forward();
    }
  }

  void _syncIdleAnimationToIsAnimate() {
    if (widget.isAnimate) {
      if (!controller.isAnimating) {
        currentRadian = 0;
        controller.forward(from: 0.0);
      }
    } else {
      controller.stop();
    }
  }

  void _applyLayoutRadius(int r) {
    if (r == _ballRadius) return;
    setState(() {
      _ballRadius = r;
      _generatePoints(widget.itemCount);
    });
  }

  void _syncLayoutFromItemCount(int count) {
    if (count < 10) {
      RotationBallViewUtil.nameHalfSize = 12;
    } else if (count < 20) {
      RotationBallViewUtil.nameHalfSize = 10;
    } else if (count < 30) {
      RotationBallViewUtil.nameHalfSize = 8;
    } else {
      RotationBallViewUtil.nameHalfSize = 6;
    }
  }

  void _generatePoints(int count) {
    points.clear();
    _itemSizes.clear();

    if (count == 0) return;

    final double r = _ballRadius.toDouble();
    final double goldenAngle = pi * (3 - sqrt(5));

    for (int i = 0; i < count; i++) {
      final double yNorm = 1 - (2 * (i + 0.5)) / count;
      final double rr = sqrt(max(0.0, 1.0 - yNorm * yNorm));
      final double theta = goldenAngle * i;
      final double x = cos(theta) * rr * r;
      final double y = yNorm * r;
      final double z = sin(theta) * rr * r;

      points.add(RotationBallPoint(x, y, z, i));
    }
  }

  int? _pickItemAt(Offset canvasLocal, double dpr) {
    double snap(double v) => (v * dpr).round() / dpr;

    final List<int> order = List<int>.generate(points.length, (i) => i);
    order.sort((a, b) => points[b].z.compareTo(points[a].z));

    const double pad = 6.0;

    for (final i in order) {
      final RotationBallPoint p = points[i];
      if (p.z < 0) continue;

      final List<double> xy = _transformCoordinate(p, _ballRadius);
      final double tx = xy[0];
      final double ty = xy[1];
      final double ax = snap(tx);
      final double ay = snap(ty);

      double depthScale =
          RotationBallViewUtil.depthScaleFromZ(p.z, layoutRadius: _ballRadius);
      depthScale = (depthScale * 256).round() / 256.0;
      final double effectiveScale = depthScale * p.pressScale;

      final Size? sz = _itemSizes[i];
      if (sz == null || sz.isEmpty) continue;

      final double w = sz.width * effectiveScale;
      final double h = sz.height * effectiveScale;
      final Rect rect = Rect.fromCenter(
        center: Offset(ax, ay),
        width: w + pad * 2,
        height: h + pad * 2,
      );
      if (rect.contains(canvasLocal)) {
        return i;
      }
    }
    return null;
  }

  void _onItemSize(int index, Size size) {
    if (!mounted) return;
    final Size? old = _itemSizes[index];
    if (old == size) return;
    setState(() {
      _itemSizes[index] = size;
    });
  }

  void _resetAllPressScales() {
    for (final p in points) {
      p.pressScale = 1.0;
    }
  }

  @override
  void didUpdateWidget(RotationBallView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isAnimate != widget.isAnimate) {
      _syncIdleAnimationToIsAnimate();
    }

    if (oldWidget.itemCount != widget.itemCount) {
      _syncLayoutFromItemCount(widget.itemCount);
      _generatePoints(widget.itemCount);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.decoration != null) {
      return Container(
        decoration: widget.decoration,
        child: _buildBall(context),
      );
    }
    return _buildBall(context);
  }

  Widget _buildBall(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size screenSize = MediaQuery.sizeOf(context);
        final int layoutR = ballRadiusFromLayout(constraints, screenSize);
        if (layoutR != _ballRadius) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _applyLayoutRadius(layoutR);
          });
        }

        final double dpr =
            MediaQuery.devicePixelRatioOf(context).clamp(1.0, 4.0);
        double snap(double v) => (v * dpr).round() / dpr;

        final List<int> order = List<int>.generate(points.length, (i) => i);
        order.sort((a, b) => points[a].z.compareTo(points[b].z));

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (PointerDownEvent event) {
        final int now = DateTime.now().millisecondsSinceEpoch;
        downPosition = _convertCoordinate(event.localPosition, _ballRadius);
        lastPosition = _convertCoordinate(event.localPosition, _ballRadius);
        _pointerDownCanvasLocal = event.localPosition;
        _tapCancelledByMovement = false;

        clearQueue();
        addToQueue(PositionWithTime(downPosition, now));

        controller.stop();

            final int? hitOnDown = _pickItemAt(event.localPosition, dpr);
            if (hitOnDown != null) {
              points[hitOnDown].pressScale = RotationBallPoint.kPressScaleDown;
              setState(() {});
            }
          },
          onPointerMove: (PointerMoveEvent event) {
        final int now = DateTime.now().millisecondsSinceEpoch;
        final Offset? downCanvas = _pointerDownCanvasLocal;
        if (downCanvas != null && !_tapCancelledByMovement) {
          final double moveFromDown =
              (event.localPosition - downCanvas).distance;
          if (moveFromDown > _cancelMoveFromDownPx) {
            _tapCancelledByMovement = true;
            setState(() {
              _resetAllPressScales();
            });
          }
        }

        final Offset currentPostion =
            _convertCoordinate(event.localPosition, _ballRadius);

        addToQueue(PositionWithTime(currentPostion, now));

        final Offset delta = Offset(
          currentPostion.dx - lastPosition.dx,
          currentPostion.dy - lastPosition.dy,
        );
        final double distance = sqrt(delta.dx * delta.dx + delta.dy * delta.dy);

        lastPosition = currentPostion;

        if (distance < 1e-8) return;

        setState(() {
          final int br = max(1, _ballRadius);
          double radian = distance / br;
          if (radian > pi / 4) {
            radian = pi / 4;
          }
          axisVector = _axisVector(delta);
          for (int i = 0; i < points.length; i++) {
            _rotatePoint(axisVector, points[i], radian);
          }
        });
      },
      onPointerUp: (PointerUpEvent event) {
        final int now = DateTime.now().millisecondsSinceEpoch;
        final Offset upPosition =
            _convertCoordinate(event.localPosition, _ballRadius);

        addToQueue(PositionWithTime(upPosition, now));

        final Offset velocity = getVelocity();
        if (widget.isAnimate) {
          if (sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy) >=
              1) {
            currentRadian = 0;
            controller.fling();
          } else {
            currentRadian = 0;
            controller.forward(from: 0.0);
          }
        }

        final Offset? downCanvas = _pointerDownCanvasLocal;
        const double tapSlop = 10.0;
        final bool shortMovement = downCanvas != null &&
            (event.localPosition - downCanvas).distance < tapSlop;
        final bool treatAsTap = shortMovement && !_tapCancelledByMovement;

        final int? hitIndex =
            treatAsTap ? _pickItemAt(event.localPosition, dpr) : null;

        final int t = DateTime.now().millisecondsSinceEpoch;

        if (hitIndex != null) {
          if (t - lastHitTime > _tapCallbackDebounceMs) {
            lastHitTime = t;
            widget.onItemTap?.call(hitIndex);
          }
        }

        final bool hadPressFeedback =
            points.any((RotationBallPoint p) => p.pressScale != 1.0);
        if (hadPressFeedback) {
          setState(() {
            _resetAllPressScales();
          });
        } else {
          _resetAllPressScales();
        }
        _pointerDownCanvasLocal = null;
        _tapCancelledByMovement = false;
      },
      onPointerCancel: (_) {
        _pointerDownCanvasLocal = null;
        _tapCancelledByMovement = false;
        final bool hadPressFeedback =
            points.any((RotationBallPoint p) => p.pressScale != 1.0);
        if (hadPressFeedback) {
          setState(() {
            _resetAllPressScales();
          });
        } else {
          _resetAllPressScales();
        }
        currentRadian = 0;
        if (widget.isAnimate) {
          controller.forward(from: 0.0);
        }
      },
      child: RepaintBoundary(
        child: ClipOval(
          child: SizedBox(
            width: 2.0 * layoutR,
            height: 2.0 * layoutR,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (layoutR == _ballRadius)
                  for (final i in order) _buildItem(context, i, snap),
              ],
            ),
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildItem(BuildContext context, int i, double Function(double) snap) {
    final RotationBallPoint point = points[i];
    final List<double> xy = _transformCoordinate(point, _ballRadius);
    final double tx = xy[0];
    final double ty = xy[1];

    final double ax = snap(tx);
    final double ay = snap(ty);

    final double z = point.z;
    double depthScale =
        RotationBallViewUtil.depthScaleFromZ(z, layoutRadius: _ballRadius);
    depthScale = (depthScale * 256).round() / 256.0;
    final double effectiveScale = depthScale * point.pressScale;

    final Size? measured = _itemSizes[i];
    final bool hasMeasured =
        measured != null && measured.width > 1 && measured.height > 1;
    final Size box = hasMeasured
        ? measured
        : Size(
            (_ballRadius * 0.9).clamp(80.0, 280.0),
            (_ballRadius * 0.45).clamp(56.0, 200.0),
          );
    final double w = box.width;
    final double h = box.height;

    final double op = RotationBallViewUtil.getPointOpacity(
      z,
      layoutRadius: _ballRadius,
    ).clamp(0.0, 1.0);

    final double bw = max(w * effectiveScale, 1.0);
    final double bh = max(h * effectiveScale, 1.0);

    return Positioned(
      left: ax - bw / 2,
      top: ay - bh / 2,
      width: bw,
      height: bh,
      child: Opacity(
        opacity: op,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: _MeasureSize(
            onChange: (Size s) => _onItemSize(i, s),
            child: widget.itemBuilder(context, i),
          ),
        ),
      ),
    );
  }

  final Queue<PositionWithTime> queue = Queue();

  void addToQueue(PositionWithTime p) {
    const int lengthOfQueue = 5;
    if (queue.length >= lengthOfQueue) {
      queue.removeFirst();
    }
    queue.add(p);
  }

  void clearQueue() {
    queue.clear();
  }

  Offset getVelocity() {
    if (queue.length < 2) return Offset.zero;
    final PositionWithTime first = queue.first;
    final PositionWithTime last = queue.last;
    return Offset(
      (last.position.dx - first.position.dx) / (last.time - first.time),
      (last.position.dy - first.position.dy) / (last.time - first.time),
    );
  }
}

class _MeasureSize extends StatefulWidget {
  const _MeasureSize({
    required this.onChange,
    required this.child,
  });

  final ValueChanged<Size> onChange;
  final Widget child;

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  final GlobalKey _key = GlobalKey();
  Size _last = Size.zero;

  void _measure() {
    final RenderBox? box =
        _key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final Size s = box.size;
      if (s != _last) {
        _last = s;
        widget.onChange(s);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return KeyedSubtree(
      key: _key,
      child: widget.child,
    );
  }
}

void _rotatePoint(
  RotationBallPoint axis,
  RotationBallPoint point,
  double radian,
) {
  final double x = cos(radian) * point.x +
      (1 - cos(radian)) *
          (axis.x * point.x + axis.y * point.y + axis.z * point.z) *
          axis.x +
      sin(radian) * (axis.y * point.z - axis.z * point.y);

  final double y = cos(radian) * point.y +
      (1 - cos(radian)) *
          (axis.x * point.x + axis.y * point.y + axis.z * point.z) *
          axis.y +
      sin(radian) * (axis.z * point.x - axis.x * point.z);

  final double z = cos(radian) * point.z +
      (1 - cos(radian)) *
          (axis.x * point.x + axis.y * point.y + axis.z * point.z) *
          axis.z +
      sin(radian) * (axis.x * point.y - axis.y * point.x);

  point.x = x;
  point.y = y;
  point.z = z;
}

List<double> _transformCoordinate(RotationBallPoint point, int ballRadius) {
  return [
    ballRadius + point.x,
    ballRadius - point.y,
    point.z
  ];
}

Offset _convertCoordinate(Offset offset, int ballRadius) {
  return Offset(
    offset.dx - ballRadius,
    ballRadius - offset.dy,
  );
}

RotationBallPoint _axisVector(Offset scrollVector) {
  final double x = -scrollVector.dy;
  final double y = scrollVector.dx;
  final double module = sqrt(x * x + y * y);
  if (module < 1e-10) {
    return RotationBallPoint(0, 1, 0, -1);
  }
  return RotationBallPoint(x / module, y / module, 0, -1);
}

class PositionWithTime {
  PositionWithTime(this.position, this.time);

  Offset position;
  int time;
}

class RotationBallPoint {
  RotationBallPoint(this.x, this.y, this.z, this.index);

  double x;
  double y;
  double z;
  final int index;

  double pressScale = 1.0;

  static const double kPressScaleDown = 0.88;
}

/// 深度与透明度插值；若自行调用，请传入与球一致的 [layoutRadius]（默认 150 仅作兜底）。
class RotationBallViewUtil {
  RotationBallViewUtil._();

  static double nameHalfSize = 6;

  static double getNameFontsize(
    double z, {
    double? halfSize,
    int layoutRadius = 150,
  }) {
    halfSize ??= nameHalfSize;
    return _getDisplaySize(z, halfSize, layoutRadius);
  }

  static double depthScaleFromZ(double z, {int layoutRadius = 150}) {
    final double maxFont = 2.0 * nameHalfSize;
    if (maxFont <= 0) return 1.0;
    return (getNameFontsize(z, layoutRadius: layoutRadius) / maxFont)
        .clamp(0.5, 1.0);
  }

  static double getPointOpacity(
    double z, {
    double halfOpacity = 0.5,
    int layoutRadius = 150,
  }) {
    return _getDisplaySize(z, halfOpacity, layoutRadius);
  }

  static double _getDisplaySize(
    double z,
    double halfValue,
    int layoutRadius,
  ) {
    return halfValue +
        halfValue * (z + layoutRadius) / (2 * layoutRadius);
  }
}
