part of widgets;

typedef ScrollChanged(double newOffset);

// TODO(rafaelw): This component wants to initially & permentantly stateful
class Scroller extends Component {

  static Style _style = new Style('''
    overflow: hidden;
    position: relative;
    will-change: transform;'''
  );

  ScrollChanged scrollChanged;
  double scrollOffset;
  List<Node> children;

  FlingCurve _flingCurve;
  int _flingAnimationId;

  Scroller({
    Object key,
    this.scrollOffset,
    this.scrollChanged,
    this.children
  }) : super(key:key, stateful: true) {}

  Node render() {
    return new Container(
      key: 'Scroller',
      style: _style,
      onFlingStart: _handleFlingStart,
      onFlingCancel: _handleFlingCancel,
      onScrollUpdate: _handleScrollUpdate,
      onWheel: _handleWheel,
      children: children
    );
  }

  bool _scrollBy(double scrollDelta) {
    scrollOffset += scrollDelta;
    scrollChanged(scrollOffset);
    return scrollDelta != 0;
  }

  void _scheduleFlingUpdate() {
    _flingAnimationId = sky.window.requestAnimationFrame(_updateFling);
  }

  void _stopFling() {
    if (_flingAnimationId == null) {
      return;
    }

    sky.window.cancelAnimationFrame(_flingAnimationId);
    _flingCurve = null;
    _flingAnimationId = null;
  }

  void _updateFling(double timeStamp) {
    double scrollDelta = _flingCurve.update(timeStamp);
    if (scrollDelta == 0 || !_scrollBy(scrollDelta))
      return _stopFling();
    _scheduleFlingUpdate();
  }

  void _handleScrollUpdate(sky.Event event) {
    _scrollBy(-event.dy);
  }

  void _handleFlingStart(sky.Event event) {
    _flingCurve = new FlingCurve(-event.velocityY, event.timeStamp);
    _scheduleFlingUpdate();
  }

  void _handleFlingCancel(sky.Event event) {
    _stopFling();
  }

  void _handleWheel(sky.Event event) {
    _scrollBy(-event.offsetY);
  }
}
