part of widgets;

abstract class Scrollable extends Component {

  _scrollOffset = 0;
  FlingCurve _flingCurve;
  int _flingAnimationId;

  Scrollable({ Object key }) : super(key:key);


  bool _scrollBy(int scrollDelta) {
    _scrollOffset += scrollDelta;
    return scrollDelta != 0;
  }

  void _scheduleFlingUpdate() {
    _flingAnimationId = requestAnimationFrame(_updateFling);
  }

  void _stopFling() {
    if (_flingAnimationId == null) {
      return;
    }

    cancelAnimationFrame(_flingAnimationId);
    _flingCurve = null;
    _flingAnimationId = null;
  }

  void _updateFling(int timeStamp) {
    int scrollDelta = _flingCurve.update(timeStamp);
    if (scrollDelta == 0 || !_scrollBy(scrollDelta))
      return _stopFling();
    _scheduleFlingUpdate();
  }


  void _handleScrollUpdate(sky.Event e) {
    _scrollBy(e.dy);
  }

  void _handleFlingStart(sky.Event e) {
    _flingCurve_ = new FlingCurve(-event.velocityY, event.timeStamp);
    _scheduleFlingUpdate();
  }

  void _handleFlingCancel(sky.Event e) {
    _stopFling();
  }

  void _handleWheel(sky.Event e) {
    _scrollBy(-event.offsetY);
  }
}
