import 'fn.dart';
import 'widgets.dart';

class ScrollTest extends Component {

  String label;

  double _scrollOffset = 0.0;

  static Style _scrollAreaStyle = new Style('''
    position:relative;
    will-change: transform;'''
  );

  static Style _itemStyle = new Style('''
    height: 22px;'''
  );

  ScrollTest({ Object key, this.label }) : super(key:key);

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

    return new Scroller(
      key: 'ScrollTest',
      scrollOffset: _scrollOffset,
      scrollChanged: _scrollChanged,
      children: [
        new Container(
          style: _scrollAreaStyle,
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
