import 'fn.dart';
import 'widgets.dart';

class ScrollTest extends Component {

  String label;

  ScrollTracker _scrollTracker;
  double _scrollOffset = 0.0;

  ScrollTest({ Object key, this.label }) : super(key:key) {
    _scrollTracker = new ScrollTracker(_scrollChanged);
  }

  Node render() {
    int itemHeight = 25;
    int displayHeight = 800;
    int drawCount = (displayHeight / itemHeight).round();
    double alignmentDelta = - _scrollOffset % itemHeight - itemHeight;
    double drawStart = _scrollOffset + alignmentDelta;

    int itemNumber = (drawStart / itemHeight).floor();

    // print('drawCount: $drawCount');
    // print('_scrollOffset: $_scrollOffset');
    // print('alignmentDelta: $alignmentDelta');

    // print('drawStart: $drawStart');
    // print('startItem: $itemNumber');

    var items = [];
    for (var i = 0; i < drawCount; i++) {
      items.add(new Container(
        key: itemNumber,
        children: [new Text("Thinger $itemNumber")]
      ));
      itemNumber++;
    }

    return new Container(
      key: 'ScrollTest',
      onFlingStart: _scrollTracker.handleFlingStart,
      onFlingCancel: _scrollTracker.handleFlingCancel,
      onScrollUpdate: _scrollTracker.handleScrollUpdate,
      onWheel: _scrollTracker.handleWheel,
      children: items
    );
  }

  _scrollChanged(double newOffset) {
    setState(() {
      _scrollOffset = newOffset;
    });
  }
}
