library item;

import 'dart:sky' as sky;
import 'fn.dart';
import 'widgets.dart';

class Item extends Component {
  String label;
  int _count = 0;
  Item({ Object key, this.label }) : super(key:key);

  Node render() {
    return new Container(
      key: 'Item',
      children: [
        new Text("$label"),
        new Button(
          content: new Text("Clicked: $_count"),
          onClick: clicked
        )
      ]
    );
  }

  void clicked(sky.Event e) {
    setState(() { _count++; });
  }
}
