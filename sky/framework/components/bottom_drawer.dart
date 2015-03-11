import '../animation/curves.dart';
import '../animation/generator.dart';
import '../fn.dart';
import 'dart:async';
import 'dart:sky' as sky;

const double _kAnimationDuration = 250.0;

class BottomDrawerAnimation extends Animation {

  static final Cubic _kAnimationCurve = easeOut;

  double openPosition;
  double closedPosition;

  Function onOpen;
  Function onClosed;

  bool get isClosed => value == closedPosition;

  void setEndpoints(double open, double closed) {
    openPosition = open;
    closedPosition = closed;
    value = closedPosition;
  }

  void open(_) {
    _animateToPosition(openPosition).then((_) {
      if (onOpen != null)
        onOpen();
    });
  }

  void close(_) {
    _animateToPosition(closedPosition).then((_) {
      if (onClosed != null)
        onClosed();
    });
  }

  Future _animateToPosition(double targetPosition) {
    return animateTo(targetPosition, _kAnimationDuration, curve: easeOut);
  }
}

class BottomDrawer extends Component {

  static Style _style = new Style('''
    position: absolute;
    z-index: 2;
    top: 0;
    left: 0;
    bottom: 0;
    right: 0;'''
  );

  static Style _maskStyle = new Style('''
    position: absolute;
    top: 0;
    left: 0;
    bottom: 0;
    right: 0;'''
  );

  static Style _contentStyle = new Style('''
    will-change: transform;
    position: absolute;
    z-index: 3;
    top: 0;
    left: 0;
    right: 0;'''
  );

  List<Node> children;
  BottomDrawerAnimation animation;

  double _position;

  BottomDrawer({
    Object key,
    this.children,
    this.animation
  }) : super(key: key, stateful: true);

  void didMount() {
    var root = getRoot();
    var content = root.firstChild;
    sky.ClientRect viewportRect = root.getBoundingClientRect();
    sky.ClientRect contentRect = content.getBoundingClientRect();

    double open = viewportRect.height - contentRect.height;
    double closed = viewportRect.height;
    this.animation.setEndpoints(open, closed);

    this.animation.onValueChanged.listen((position) {
      setState(() {
        _position = position;
      });
    });
  }

  bool get closed => _position == null ? false : animation.isClosed;

  Node build() {
    String contentInlineStyle = 'transform: translateY(${_position}px)';
    String inlineStyle = 'display: ${closed ? 'none' : ''}';

    Container mask = new Container(
      key: 'Mask',
      styles: [_maskStyle]
    )..events.listen('gesturetap', animation.close);

    Container content = new Container(
      key: 'Content',
      styles: [_contentStyle],
      inlineStyle: contentInlineStyle,
      children: children
    );

    return new Container(
      styles: [_style],
      inlineStyle: inlineStyle,
      children: [ content, mask ]
    );
  }
}
