// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../animation/fling-curve.dart';
import '../fn.dart';
import 'dart:sky' as sky;

abstract class FixedHeightScrollable extends Component {
  // TODO(rafaelw): This component really shouldn't have an opinion
  // about how it is sized. The owning component should decide whether
  // it's explicitly sized or flexible or whatever...
  static final Style _style = new Style('''
    overflow: hidden;
    position: relative;'''
  );

  static final Style _scrollAreaStyle = new Style('''
    position:relative;'''
  );

  int minItem;
  int maxItem;

  double _minOffset;
  double _maxOffset;
  double _scrollOffset = 0.0;
  FlingCurve _flingCurve;
  int _flingAnimationId;
  double _height = 0.0;
  double _itemHeight;

  Style style;

  FixedHeightScrollable({
    Object key,
    this.minItem,
    this.maxItem,
    this.style
  }) : super(key: key) {
    events.listen('gestureflingstart', _handleFlingStart);
    events.listen('gestureflingcancel', _handleFlingCancel);
    events.listen('gesturescrollupdate', _handleScrollUpdate);
    events.listen('wheel', _handleWheel);
  }

  List<Node> buildItems(int start, int count);

  void didMount() {
    var root = getRoot();
    var item = root.firstChild.firstChild;
    sky.ClientRect scrollRect = root.getBoundingClientRect();
    sky.ClientRect itemRect = item.getBoundingClientRect();
    assert(scrollRect.height > 0);
    assert(itemRect.height > 0);

    setState(() {
      _height = scrollRect.height;
      _itemHeight = itemRect.height;

      if (minItem != null) {
        _minOffset = minItem * _itemHeight;
      }
      if (maxItem != null) {
        _maxOffset = (maxItem - 1) * _itemHeight - _height;
      }
    });
  }

  Node build() {
    var itemNumber = 0;
    var drawCount = 1;
    var transformStyle = '';

    if (_height > 0.0) {
      drawCount = (_height / _itemHeight).round() + 1;
      double alignmentDelta = -_scrollOffset % _itemHeight;
      if (alignmentDelta != 0.0) {
        alignmentDelta -= _itemHeight;
      }

      double drawStart = _scrollOffset + alignmentDelta;
      itemNumber = (drawStart / _itemHeight).floor();

      transformStyle =
          'transform: translateY(${(alignmentDelta).toStringAsFixed(2)}px)';
    }

    return new Container(
      styles: style != null ? [style, _style] : [_style],
      children: [
        new Container(
          styles: [_scrollAreaStyle],
          inlineStyle: transformStyle,
          children: buildItems(itemNumber, drawCount)
        )
      ]
    );
  }

  void didUnmount() {
    _stopFling();
  }

  bool _scrollBy(double scrollDelta) {
    var newScrollOffset = _scrollOffset + scrollDelta;
    if (_minOffset != null && newScrollOffset < _minOffset) {
      newScrollOffset = _minOffset;
    } else if (_maxOffset != null && newScrollOffset > _maxOffset) {
      newScrollOffset = _maxOffset;
    }
    if (newScrollOffset == _scrollOffset) {
      return false;
    }

    setState(() {
      _scrollOffset = newScrollOffset;
    });
    return true;
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
    if (!_scrollBy(scrollDelta))
      return _stopFling();
    _scheduleFlingUpdate();
  }

  void _handleScrollUpdate(sky.GestureEvent event) {
    _scrollBy(-event.dy);
  }

  void _handleFlingStart(sky.GestureEvent event) {
    setState(() {
      _flingCurve = new FlingCurve(-event.velocityY, event.timeStamp);
      _scheduleFlingUpdate();
    });
  }

  void _handleFlingCancel(sky.GestureEvent event) {
    _stopFling();
  }

  void _handleWheel(sky.WheelEvent event) {
    _scrollBy(-event.offsetY);
  }
}
