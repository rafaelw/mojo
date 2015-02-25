import 'companylist.dart';
import 'dart:collection';
import 'dart:math';
import 'dart:sky' as sky;
import 'fn.dart';
import 'stockarrow.dart';
import 'widgets.dart';

class StockRow extends Component {

  Stock stock;
  LinkedHashSet<SplashAnchor> _splashes;

  static Style _style = new Style('''
    transform: translateX(0);
    max-height: 48px;
    display: flex;
    align-items: center;
    border-bottom: 1px solid #F4F4F4;
    padding-top: 16px;
    padding-left: 16px;
    padding-right: 16px;
    padding-bottom: 20px;'''
  );

  static Style _tickerStyle = new Style('''
    flex: 1;
    font-family: 'Roboto Medium', 'Helvetica';'''
  );

  static Style _lastSaleStyle = new Style('''
    text-align: right;
    padding-right: 16px;'''
  );

  static Style _changeStyle = new Style('''
    color: #8A8A8A;
    text-align: right;'''
  );

  StockRow({ Stock stock }) : super(key:stock.symbol) {
    this.stock = stock;
  }

  void willUnmount() {
    if (_splashes != null) {
      _splashes.forEach((splash) { splash.stop(); });
      _splashes = null;
    }
  }

  Node render() {
    String lastSale = "\$${stock.lastSale.toStringAsFixed(2)}";

    String changeInPrice = "${stock.percentChange.toStringAsFixed(2)}%";
    if (stock.percentChange > 0)
      changeInPrice = "+" + changeInPrice;

    List<Node> children = [
      new StockArrow(
        key: 'StockArrow',
        percentChange: stock.percentChange
      ),
      new Container(
        key: 'Ticker',
        style: _tickerStyle,
        children: [new Text(stock.symbol)]
      ),
      new Container(
        key: 'LastSale',
        style: _lastSaleStyle,
        children: [new Text(lastSale)]
      ),
      new Container(
        key: 'Change',
        style: _changeStyle,
        children: [new Text(changeInPrice)]
      )
    ];

    if (_splashes != null) {
      _splashes.forEach((splash) {
        children.add(new InkSplash(
          anchor: splash,
          completed: _splashCompleted
        ));
      });
    }

    return new Container(
      key: 'StockRow',
      style: _style,
      onPointerDown: _handlePointerDown,
      children: children
    );
  }

  sky.ClientRect _getBoundingRect() => getRoot().getBoundingClientRect();

  void _handlePointerDown(sky.Event event) {
    setState(() {
      if (_splashes == null) {
        _splashes = new LinkedHashSet<SplashAnchor>();
      }

      _splashes.add(new SplashAnchor(_getBoundingRect(), event.x, event.y));
    });
  }

  void _splashCompleted(SplashAnchor splash) {
    setState(() {
      _splashes.remove(splash);
      if (_splashes.length == 0) {
        _splashes = null;
      }
    });
  }
}
