import 'fn.dart';
import 'widgets.dart';

class ScrollTest extends Component {

  String label;

  ScrollTracker _scrollTracker;
  double _scrollOffset = 0.0;

  static Style _style = new Style('''
    overflow: hidden;
    position: relative;
    will-change: transform;'''
  );

  static Style _scrollAreaStyle = new Style('''
    position:relative;
    will-change: transform;
''');

  static Style _itemStyle = new Style('''
    height: 22px;'''
  );

  ScrollTest({ Object key, this.label }) : super(key:key) {
    _scrollTracker = new ScrollTracker(_scrollChanged);
  }

  Node render() {
    int itemHeight = 22;
    int displayHeight = 800;
    int drawCount = (displayHeight / itemHeight).round();
    double alignmentDelta = - _scrollOffset % itemHeight - itemHeight;
    double drawStart = _scrollOffset + alignmentDelta;

    int itemNumber = (drawStart / itemHeight).floor();

    var items = [];
    for (var i = 0; i < drawCount; i++) {
      items.add(new Container(
        key: itemNumber,
        style: _itemStyle,
        children: [new Text("Thinger $itemNumber")]
      ));
      itemNumber++;
    }

    var transformStyle =
        'transform: translateY(${(alignmentDelta).toStringAsFixed(2)}px)';

    return new Container(
      key: 'ScrollTest',
      style: _style,
      onFlingStart: _scrollTracker.handleFlingStart,
      onFlingCancel: _scrollTracker.handleFlingCancel,
      onScrollUpdate: _scrollTracker.handleScrollUpdate,
      onWheel: _scrollTracker.handleWheel,
      children: [
        new Container(
          inlineStyle: transformStyle,
          key: 'ScrollArea',
          children: items
        )
      ]
    );
  }

  _scrollChanged(double newOffset) {
    setState(() {
      _scrollOffset = newOffset;
    });
  }
}
