part of widgets;

const double _kSplashSize = 400.0;
const double _kSplashDuration = 500.0;

typedef SplashCompleted(SplashAnchor anchor);

class SplashAnchor {

  sky.ClientRect rect;
  double x;
  double y;
  int _id;

  static int _nextId = 1;

  AnimationController _animation;

  SplashAnchor(this.rect, this.x, this.y) : _id = _nextId++;

  void start(AnimationDelegate delegate) {
    _animation = new AnimationController(delegate);
    _animation.start(
      begin: 0.0,
      end: _kSplashSize,
      duration: _kSplashDuration,
      curve: easeOut);
  }

  void stop() {
    if (_animation != null) {
      _animation.stop();
      _animation = null;
    }
  }
}

class InkSplash extends Component implements AnimationDelegate {

  SplashAnchor anchor;
  SplashCompleted completed;

  static Style _style = new Style('''
    position: absolute;
    pointer-events: none;
    overflow: hidden;
    top: 0;
    left: 0;
    bottom: 0;
    right: 0;
  ''');

  static Style _splashStyle = new Style('''
    position: absolute;
    background-color: rgba(0, 0, 0, 0.4);
    border-radius: 0;
    top: 0;
    left: 0;
    height: 0;
    width: 0;
  ''');

  double _offsetX;
  double _offsetY;
  String _inlineStyle;

  InkSplash({
    SplashAnchor anchor,
    this.completed
  })
    : anchor = anchor,
      super(stateful: true, key:anchor._id) {
    _offsetX = anchor.x - anchor.rect.left;
    _offsetY = anchor.y - anchor.rect.top;
  }

  Node render() {
    return new Container(
      key: "InkSplash",
      style: _style,
      children: [
        new Container(
          key: "Splash",
          inlineStyle: _inlineStyle,
          style: _splashStyle
        )
      ]
    );
  }

  void didMount() {
    anchor.start(this);
  }

  void willUnmount() {
    anchor.stop();
  }

  void updateAnimation(double p) {
    if (p == _kSplashSize) {
      anchor.stop();
      completed(anchor);
      return;
    }

    setState(() {
      _inlineStyle = '''
        top: ${_offsetY - p/2}px;
        left: ${_offsetX - p/2}px;
        width: ${p}px;
        height: ${p}px;
        border-radius: ${p}px;
        opacity: ${1.0 - (p / _kSplashSize)};
      ''';
    });
  }
}
