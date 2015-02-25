// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
import 'companylist.dart';
import 'fn.dart';
import 'stocklist.dart';
import 'widgets.dart';

class StocksApp extends App {

  static Style _style = new Style('''
    display: flex;
    flex-direction: column;
    height: -webkit-fill-available;
    font-family: 'Roboto Regular', 'Helvetica';
    font-size: 16px;'''
  );

  StocksApp() : super();

  Node render() {
    return new Container(
      key: 'StocksApp',
      style: _style,
      children: [
        new Toolbar(
          children: [
            new Text('I am a stocks app')
          ]
        ),
        new Stocklist(oracle.stocks)
      ]
    );
  }
}
