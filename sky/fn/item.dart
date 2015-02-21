library item;

import 'dart:sky' as sky;
import 'fn.dart';
import 'widgets.dart';

class Item extends Component {

  String label;

  bool _highlight = false;

  Item({ Object key, this.label }) : super(key:key);

  Node render() {
    return new Container(
      key: 'Item',
      children: [
        new Checkbox(
          onChanged: changed,
          checked: _highlight
        ),
        new Text("Checked: $_highlight"),
      ]
    );
  }

  void changed(bool value) {
    setState(() {
      _highlight = value;
    });
  }
}
