import 'fn.dart';
import 'widgets.dart';

class ScrollTest extends FixedHeightScrollable {

  static Style _itemStyle = new Style('''
    height: 22px;'''
  );

  ScrollTest({ Object key })
    : super(
        key:key,
        itemHeight: 22.0,
        height: 800.0
      );

  List<Node> renderItems(int itemNumber, int drawCount) {
    var items = [];
    for (var i = 0; i < drawCount; i++) {
      items.add(new Container(
        key: itemNumber,
        style: _itemStyle,
        children: [new Text("Thing $itemNumber")]
      ));

      itemNumber++;
    }

    return items;
  }
}
