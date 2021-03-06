import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'animations.dart';

typedef ForwardCallback(int index);
typedef BackCallback(int index);
typedef EndCallback();

/// 卡片控制器
class TCardController {
  _TCardState _state;

  void _bindState(_TCardState state) {
    this._state = state;
  }

  int get index => _state?._frontCardIndex ?? 0;

  forward() {
    _state._runChangeOrderAnimation();
  }

  back() {
    _state._runReverseOrderAnimation();
  }

  reset() {
    _state._reset();
  }

  void dispose() {
    _state = null;
  }
}

/// 卡片列表
class TCard extends StatefulWidget {
  /// 卡片尺寸
  final Size size;

  /// 卡片列表
  final List<Widget> cards;

  /// 向前回调方法
  final ForwardCallback onForward;

  /// 向后回调方法
  final BackCallback onBack;

  /// 结束回调方法
  final EndCallback onEnd;

  /// 卡片控制器
  final TCardController controller;

  const TCard({
    @required this.cards,
    this.controller,
    this.onForward,
    this.onBack,
    this.onEnd,
    this.size = const Size(380, 400),
  })  : assert(cards != null),
        assert(cards.length > 0);

  @override
  _TCardState createState() => _TCardState();
}

class _TCardState extends State<TCard> with TickerProviderStateMixin {
  //  初始的卡片列表
  final List<Widget> _cards = [];
  //  最前面卡片的索引
  int _frontCardIndex = 0;
  // 最前面卡片的位置
  Alignment _frontCardAlignment = CardAlignments.front;
  // 最前面卡片的旋转角度
  double _frontCardRotation = 0.0;
  // 卡片位置变换动画控制器
  AnimationController _cardChangeController;
  // 卡片位置恢复动画控制器
  AnimationController _cardReverseController;
  // 卡片回弹动画
  Animation<Alignment> _reboundAnimation;
  // 卡片回弹动画控制器
  AnimationController _reboundController;
  // 是否向左滑
  bool _isSwipLeft = false;

  //  前面的卡片
  Widget _frontCard(BoxConstraints constraints) {
    Widget child =
        _frontCardIndex < _cards.length ? _cards[_frontCardIndex] : Container();
    bool forward = _cardChangeController.status == AnimationStatus.forward;
    bool reverse = _cardReverseController.status == AnimationStatus.forward;

    Widget rotate = Transform.rotate(
      angle: (math.pi / 180.0) * _frontCardRotation,
      child: SizedBox.fromSize(
        size: CardSizes.front(constraints),
        child: child,
      ),
    );

    if (reverse) {
      return Align(
        alignment: CardReverseAnimations.frontCardShowAnimation(
          _cardReverseController,
          CardAlignments.front,
          _isSwipLeft,
        ).value,
        child: rotate,
      );
    }

    if (forward) {
      return Align(
        alignment: CardAnimations.frontCardDisappearAnimation(
          _cardChangeController,
          _frontCardAlignment,
        ).value,
        child: rotate,
      );
    }

    return Align(
      alignment: _frontCardAlignment,
      child: rotate,
    );
  }

  // 中间的卡片
  Widget _middleCard(BoxConstraints constraints) {
    Widget child = _frontCardIndex < _cards.length - 1
        ? _cards[_frontCardIndex + 1]
        : Container();
    bool forward = _cardChangeController.status == AnimationStatus.forward;
    bool reverse = _cardReverseController.status == AnimationStatus.forward;

    if (reverse) {
      return Align(
        alignment: CardReverseAnimations.middleCardAlignmentAnimation(
          _cardReverseController,
        ).value,
        child: SizedBox.fromSize(
          size: CardReverseAnimations.middleCardSizeAnimation(
            _cardReverseController,
            constraints,
          ).value,
          child: child,
        ),
      );
    }

    if (forward) {
      return Align(
        alignment: CardAnimations.middleCardAlignmentAnimation(
          _cardChangeController,
        ).value,
        child: SizedBox.fromSize(
          size: CardAnimations.middleCardSizeAnimation(
            _cardChangeController,
            constraints,
          ).value,
          child: child,
        ),
      );
    }

    return Align(
      alignment: CardAlignments.middle,
      child: SizedBox.fromSize(
        size: CardSizes.middle(constraints),
        child: child,
      ),
    );
  }

  // 后面的卡片
  Widget _backCard(BoxConstraints constraints) {
    Widget child = _frontCardIndex < _cards.length - 2
        ? _cards[_frontCardIndex + 2]
        : Container();
    bool forward = _cardChangeController.status == AnimationStatus.forward;
    bool reverse = _cardReverseController.status == AnimationStatus.forward;

    if (reverse) {
      return Align(
        alignment: CardReverseAnimations.backCardAlignmentAnimation(
          _cardReverseController,
        ).value,
        child: SizedBox.fromSize(
          size: CardReverseAnimations.backCardSizeAnimation(
            _cardReverseController,
            constraints,
          ).value,
          child: child,
        ),
      );
    }

    if (forward) {
      return Align(
        alignment: CardAnimations.backCardAlignmentAnimation(
          _cardChangeController,
        ).value,
        child: SizedBox.fromSize(
          size: CardAnimations.backCardSizeAnimation(
            _cardChangeController,
            constraints,
          ).value,
          child: child,
        ),
      );
    }

    return Align(
      alignment: CardAlignments.back,
      child: SizedBox.fromSize(
        size: CardSizes.back(constraints),
        child: child,
      ),
    );
  }

  // 判断是否在进行动画
  bool _isAnimating() {
    return _cardChangeController.status == AnimationStatus.forward ||
        _cardReverseController.status == AnimationStatus.forward;
  }

  // 运行卡片回弹动画
  void _runReboundAnimation(Offset pixelsPerSecond, Size size) {
    _reboundAnimation = _reboundController.drive(
      AlignmentTween(
        begin: _frontCardAlignment,
        end: CardAlignments.front,
      ),
    );

    final double unitsPerSecondX = pixelsPerSecond.dx / size.width;
    final double unitsPerSecondY = pixelsPerSecond.dy / size.height;
    final unitsPerSecond = Offset(unitsPerSecondX, unitsPerSecondY);
    final unitVelocity = unitsPerSecond.distance;
    const spring = SpringDescription(mass: 30, stiffness: 1, damping: 1);
    final simulation = SpringSimulation(spring, 0, 1, -unitVelocity);

    _reboundController.animateWith(simulation);
    _return();
  }

  // 运行卡片向前动画
  void _runChangeOrderAnimation() {
    if (_isAnimating()) {
      return;
    }

    _cardChangeController.reset();
    _cardChangeController.forward();
  }

  // 运行卡片后退动画
  void _runReverseOrderAnimation() {
    if (_isAnimating()) {
      return;
    }

    _cardReverseController.reset();
    _cardReverseController.forward();
  }

  // 向前动画完成后执行
  void _forward() {
    _frontCardIndex++;
    _return();
    if (widget.onForward != null && widget.onForward is Function) {
      widget.onForward(_frontCardIndex);
    }

    if (widget.onEnd != null &&
        widget.onEnd is Function &&
        _frontCardIndex >= _cards.length) {
      widget.onEnd();
    }
  }

  // 后退完成后执行
  void _back() {
    _return();
    if (widget.onBack != null && widget.onBack is Function) {
      widget.onBack(_frontCardIndex);
    }
  }

  // 重置最前面卡片的位置
  void _return() {
    _frontCardRotation = 0.0;
    _frontCardAlignment = CardAlignments.front;
    setState(() {});
  }

  // 重置所有卡片
  void _reset() {
    _cards.clear();
    _cards.addAll(widget.cards);
    _frontCardIndex = 0;
    _return();
  }

  // 手指按下停止所有运行中的动画
  void _stop() {
    _reboundController.stop();
    _cardChangeController.stop();
    _cardReverseController.stop();
  }

  // 更新最前面卡片的位置
  void _updateFrontCardAlignment(DragUpdateDetails details, Size size) {
    // 移动的速度
    final double speed = 10.0;

    _frontCardAlignment += Alignment(
      details.delta.dx / (size.width / 2) * speed,
      details.delta.dy / (size.height / 2) * speed,
    );
    // 设置最前面卡片的旋转角度
    _frontCardRotation = _frontCardAlignment.x;
    setState(() {});
  }

  // 判断是否进行动画
  void _judgeRunAnimation(DragEndDetails details, Size size) {
    // 卡片横轴距离限制
    final double limit = 10.0;
    final bool isBeyondXLimit =
        _frontCardAlignment.x > limit || _frontCardAlignment.x < -limit;

    if (_frontCardAlignment.x < -2.0) {
      _isSwipLeft = true;
    } else {
      _isSwipLeft = false;
    }

    // 判断是否运行向前的动画，否则回弹
    if (isBeyondXLimit) {
      _runChangeOrderAnimation();
    } else {
      _runReboundAnimation(details.velocity.pixelsPerSecond, size);
    }
  }

  @override
  void initState() {
    super.initState();

    // 初始化所有传入的卡片
    _cards.addAll(widget.cards);

    // 绑定控制器
    if (widget.controller != null && widget.controller is TCardController) {
      widget.controller._bindState(this);
    }

    // 初始化向前的动画控制器
    _cardChangeController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _forward();
        }
      });

    // 初始化向后的动画控制器
    _cardReverseController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.forward) {
          _frontCardIndex--;
        }
        if (status == AnimationStatus.completed) {
          _back();
        }
      });

    // 初始化回弹的动画控制器
    _reboundController = AnimationController(vsync: this)
      ..addListener(() {
        setState(() {
          _frontCardAlignment = _reboundAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _cardReverseController.dispose();
    _cardChangeController.dispose();
    _reboundController.dispose();
    if (widget.controller != null) {
      widget.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: widget.size,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // 使用 LayoutBuilder 获取容器的尺寸，传个子项计算卡片尺寸
          final Size size = MediaQuery.of(context).size;

          return Stack(
            children: <Widget>[
              _backCard(constraints),
              _middleCard(constraints),
              _frontCard(constraints),
              // 使用一个 SizedBox 覆盖父元素整个区域
              _cardChangeController.status != AnimationStatus.forward
                  ? SizedBox.expand(
                      child: GestureDetector(
                        onPanDown: (DragDownDetails details) {
                          _stop();
                        },
                        onPanUpdate: (DragUpdateDetails details) {
                          _updateFrontCardAlignment(details, size);
                        },
                        onPanEnd: (DragEndDetails details) {
                          _judgeRunAnimation(details, size);
                        },
                      ),
                    )
                  : IgnorePointer(),
            ],
          );
        },
      ),
    );
  }
}
