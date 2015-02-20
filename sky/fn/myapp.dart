// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
import 'fn.dart';
import 'widgets.dart';
import 'item.dart';

class MyApp extends App {
  List<int> _numbers = [];
  int _counter = 0;

  MyApp() : super();

  Node render() {
    var children = [
      new Button(
        content: new Text('Add one'),
        onClick: clicked
      )
    ]..addAll(
      _numbers.map((val) => new Item(key: val, label: "$val of $_counter:"))
    );

    return new Box(
      key: "Box",
      title: "My App",
      children: [
        new Container(children: children, key: 'Numbers')
      ]
    );
  }

  void clicked(e) {
    setState(() {
      _numbers.add(_counter++);
    });
  }
}
