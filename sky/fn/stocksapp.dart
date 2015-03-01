// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
import 'companylist.dart';
import 'dart:sky' as sky;
import 'fn.dart';
import 'stocklist.dart';
import 'widgets.dart';

class StocksApp extends App {

  DrawerAnimation _drawerAnimation;

  static Style _style = new Style('''
    display: flex;
    flex-direction: column;
    height: -webkit-fill-available;
    font-family: 'Roboto Regular', 'Helvetica';
    font-size: 16px;'''
  );

  StocksApp() : super();

  void didMount() {
    _drawerAnimation = new DrawerAnimation();
  }

  Node render() {
    var drawer = new Drawer(
      key: 'Drawer',
      onPositionChanged: _drawerAnimation.onPositionChanged,
      handleMaskFling: _drawerAnimation.handleFlingStart,
      handleMaskTap: _drawerAnimation.handleMaskTap,
      handlePointerCancel: _drawerAnimation.handlePointerCancel,
      handlePointerDown: _drawerAnimation.handlePointerDown,
      handlePointerMove: _drawerAnimation.handlePointerMove,
      handlePointerUp: _drawerAnimation.handlePointerUp,
      children: [
        new DrawerHeader(
          key: 'DrawerHeader',
          children: [new Text('Stocks')]
        )
      ]
    );

    var toolbar = new Toolbar(
      children: [
        new Icon(key: 'menu', onClick: _drawerAnimation.toggle,
                 size: 24, type: 'navigation/menu_white'),
        new Text('I am a stocks app'),
        new Icon(key: 'search', size: 24, type: 'action/search_white'),
        new Icon(key: 'more_white', size: 24, type: 'navigation/more_vert_white')
      ]
    );

    return new Container(
      key: 'StocksApp',
      style: _style,
      children: [drawer, toolbar, new Stocklist(oracle.stocks)]
    );
  }
}
