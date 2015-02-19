// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:sky' show document;
import 'fn.dart';
import 'button.dart';

class MyApp extends Component {
  List<int> _numbers = [];
  int _counter = 0;

  MyApp() : super() {}

  Node render() {
    var children = [new Button(
      content: new Text('Add one'),
      onClick: clicked
    )];

    children.addAll(_numbers.map(
        (val) => new Text("Number: $val", key: val)).toList());

    return new Container(
      key: "appContainer",
      children: [new Container(children: children, key: 'numbersContainer')],
      style: new Style('font-size: 20px; color: red')
    );
  }

  void clicked(e) {
    setState(() {
      _numbers.add(_counter++);
    });
  }
}

go() {
  initialize(document);
  var d = new MyApp();
  render(document.getElementById("app"), d);
}
