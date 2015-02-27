// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
import 'companylist.dart';
import 'dart:sky' as sky;
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
            new Icon(key: 'menu', size: 24, type: 'navigation/menu_white', onClick: _toggleDrawer),
            new Text('I am a stocks app'),
            new Icon(key: 'search', size: 24, type: 'action/search_white'),
            new Icon(key: 'more_white', size: 24, type: 'navigation/more_vert_white')
          ]
        ),
        new Stocklist(oracle.stocks)
      ]
    );
  }

  _toggleDrawer(sky.Event event) {
    print('drawer toggled');
  }
}
