part of stocksapp;

class Stocklist extends FixedHeightScrollable {
  String query;
  List<Stock> stocks;

  Stocklist({
    Object key,
    List<Stock> stocks,
    this.query,
    Style style
  }) : this.stocks = stocks,
       super(minItem: 0, maxItem: stocks.length, style: style);

  List<Node> buildItems(int start, int count) {
    return stocks
      .skip(start)
      .where((stock) => query == null || stock.symbol.contains(
          new RegExp(query, caseSensitive: false)))
      .take(count)
      .map((stock) => new StockRow(stock: stock))
      .toList(growable: false);
  }
}
