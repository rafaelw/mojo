part of widgets;

const double _kSplashSize = 400.0;
const double _kSplashDuration = 500.0;

class SplashAnimation extends AnimationGenerator {
  double _offsetX;
  double _offsetY;

  Stream<String> _styleChanged;

  Stream<String> get onStyleChanged => _styleChanged;

  SplashAnimation(sky.ClientRect rect, double x, double y,
                  { AnimationDone onDone })
    : _offsetX = x - rect.left,
      _offsetY = y - rect.top,
      super(_kSplashDuration,
            end: _kSplashSize,
            curve: easeOut,
            onDone: onDone) {

    _styleChanged = super.onTick.map((p) => '''
      top: ${_offsetY - p/2}px;
      left: ${_offsetX - p/2}px;
      width: ${p}px;
      height: ${p}px;
      border-radius: ${p}px;
      opacity: ${1.0 - (p / _kSplashSize)};
    ''');
  }
}

class InkSplash extends Component {

  SplashAnimation animation;

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

  InkSplash(SplashAnimation animation)
    : animation = animation,
      super(stateful: true, key: animation.hashCode);

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
    animation.onStyleChanged.listen((style) {
      setState(() {
        _inlineStyle = style;
      });
    });
  }

  void willUnmount() {
    animation.close();
  }
}
