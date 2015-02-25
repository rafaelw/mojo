import 'fn.dart';
import 'widgets.dart';
import 'companylist.dart';
import 'stockrow.dart';

class Stocklist extends Component {

  List<Stock> stocks;

  double _scrollOffset = 0.0;

  static Style _scrollAreaStyle = new Style('''
    position:relative;
    will-change: transform;'''
  );

  Stocklist(this.stocks) : super(key:'Stocklist');

  Node render() {
    int itemHeight = 60;
    int displayHeight = 800;
    int drawCount = (displayHeight / itemHeight).round();

    double alignmentDelta = - _scrollOffset % itemHeight;
    if (alignmentDelta != 0.0)
      alignmentDelta -= itemHeight;

    double drawStart = _scrollOffset + alignmentDelta;

    int itemNumber = (drawStart / itemHeight).floor();
    print(itemNumber);

    var items = [];
    for (var i = 0; i < drawCount; i++) {
      items.add(new StockRow(stock: stocks[itemNumber]));
      itemNumber++;
    }

    var transformStyle =
        'transform: translateY(${(alignmentDelta).toStringAsFixed(2)}px)';

    return new Scroller(
      key: 'Stocklist',
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
    if (newOffset < 0.0) {
      return;
    }

    setState(() {
      _scrollOffset = newOffset;
    });
  }
}
