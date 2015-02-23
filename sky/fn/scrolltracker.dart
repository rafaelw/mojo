part of widgets;

typedef ScrollChanged(double newPosition);

class ScrollTracker {

  ScrollChanged scrollChanged;

  double _scrollOffset = 0.0;
  FlingCurve _flingCurve;
  int _flingAnimationId;

  ScrollTracker(this.scrollChanged);

  bool _scrollBy(double scrollDelta) {
    _scrollOffset += scrollDelta;
    scrollChanged(_scrollOffset);
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

  void handleScrollUpdate(sky.Event event) {
    _scrollBy(-event.dy);
  }

  void handleFlingStart(sky.Event event) {
    _flingCurve = new FlingCurve(-event.velocityY, event.timeStamp);
    _scheduleFlingUpdate();
  }

  void handleFlingCancel(sky.Event event) {
    _stopFling();
  }

  void handleWheel(sky.Event event) {
    _scrollBy(-event.offsetY);
  }
}
