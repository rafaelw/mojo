// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
import 'fn.dart';
import 'button.dart';
import 'item.dart';

class MyApp extends App {
  List<int> _numbers = [];
  int _counter = 0;

  MyApp() : super() {

  }

  Node render() {
    var children = [new Button(
      content: new Text('Add one'),
      onClick: clicked
    )]..addAll(
      _numbers.map((val) => new Item(key: val, label: "Number: $val"))
    );

    return new Container(
      key: "MyApp",
      children: [new Container(children: children, key: 'Numbers')],
      style: new Style('font-size: 20px; color: red')
    );
  }

  void clicked(e) {
    setState(() {
      _numbers.add(_counter++);
    });
  }
}
