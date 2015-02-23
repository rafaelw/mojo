import 'dart:sky' as sky;
import 'fn.dart';
import 'widgets.dart';

class ScrollTest extends Scrollable {

  String label;

  Color _color = Color.GREEN;

  Item({ Object key, this.label }) : super(key:key);

  Node render() {
    int itemHeight = 25;
    int displayHeight = 680;
    int drawCount = math.abs(displayHeight / itemHeight) + 2;
    int alignmentDelta = - _scrollOffset % itemHeight - itemHeight;
    int drawStart = _scrollOffset - alignmentDelta;

    int itemNumber = drawStart / itemHeight;
    var items = [];
    for (var i = 0; i < drawCount; i++) {
      items.add(new Container(
        key: itemNumber,
        children: new Text("Item $itemNumber")
      ));
      itemNumber++;
    }

    return new Container(
      key: 'ScrollTest',
      onFlingStart: _handleFlingStart,
      onFlingCancel: _handleFlingCancel,
      onScrollUpdate: _handleScrollUpdate,
      onWheel: _handleWheel,
      children: [
        new Container(
          key: ScrollArea,

          children: items
        )
      ]
    );
  }

  void changed(Object value) {
    setState(() {
      _color = value;
    });
  }
}
