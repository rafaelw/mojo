// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:sky' show document;
import 'fn.dart';
import 'button.dart';

class MyApp extends Component {
  List<int> numbers = null;

  MyApp() : super() {}

  Node render() {
    return new Button(
      content: new Text('Click Me!'),
      onClick: clicked
    );
  }
  /*
  Node render() {
    return new Container(
      children: [
        new Container(
          children: [
            new Text('bar 7', key: 1),
            new Text('bar 9', key: 2),
            new Button(
              content: new Text('I am a button'),
              onClick: clicked
            )
          ],
          style: new Style('font-size: 20px; color: red')
        )
      ]
    );
  }
  */

  void clicked(e) {
    print('yay!');
  }
}

go() {
  initialize(document);
  var d = new MyApp();
  render(document.getElementById("app"), d);
}
