import 'companylist.dart';
import 'fn.dart';
import 'dart:math';

class StockRow extends Component {

  Stock stock;

  static Style _style = new Style('''
    // TODO(eseidel): Why does setting height here make this too big?
    height: 48px;
    display: flex;
    border-bottom: 1px solid #F4F4F4;
    padding-top: 16px;
    padding-left: 16px;
    padding-right: 16px;
    padding-bottom: 20px;'''
  );

  static Style _tickerStyle = new Style('''
    flex-grow: 1;'''
  );

  static Style _lastSaleStyle = new Style('''
    padding-right: 20px;'''
  );

  static Style _changeStyle = new Style('''
    border-radius: 5px;
    min-width: 72px;
    padding: 2px;
    padding-right: 10px;
    text-align: right;'''
  );

  StockRow({ Stock stock }) : super(key:stock.symbol) {
    this.stock = stock;
  }

  List<String> _redColors = [
    '#FFEBEE',
    '#FFCDD2',
    '#EF9A9A',
    '#E57373',
    '#EF5350',
    '#F44336',
    '#E53935',
    '#D32F2F',
    '#C62828',
    '#B71C1C',
  ];

  List<String> _greenColors = [
    '#E8F5E9',
    '#C8E6C9',
    '#A5D6A7',
    '#81C784',
    '#66BB6A',
    '#4CAF50',
    '#43A047',
    '#388E3C',
    '#2E7D32',
    '#1B5E20',
  ];

  int _colorIndexForPercentChange(double percentChange) {
    // Currently the max is 10%.
    double maxPercent = 10.0;
    return max(0, ((percentChange.abs() / maxPercent) * _greenColors.length).floor());
  }

  String _colorForPercentChange(double percentChange) {
    if (percentChange > 0)
      return _greenColors[_colorIndexForPercentChange(percentChange)];
    return _redColors[_colorIndexForPercentChange(percentChange)];
  }

  Node render() {
    String lastSale = "\$${stock.lastSale.toStringAsFixed(2)}";

    String changeInPrice = "${stock.percentChange.toStringAsFixed(2)}%";
    if (stock.percentChange > 0)
      changeInPrice = "+" + changeInPrice;

    String inlineStyle =
        'background-color: ${_colorForPercentChange(stock.percentChange)}';

    return new Container(
      key: 'StockRow',
      style: _style,
      children: [
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
          inlineStyle: inlineStyle,
          children: [new Text(changeInPrice)]
        )
      ]
    );
  }
}
