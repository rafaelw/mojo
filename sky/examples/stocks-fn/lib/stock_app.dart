s// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sky/framework/components/action_bar.dart';
import 'package:sky/framework/components/drawer.dart';
import 'package:sky/framework/components/drawer_header.dart';
import 'package:sky/framework/components/floating_action_button.dart';
import 'package:sky/framework/components/icon.dart';
import 'package:sky/framework/components/input.dart';
import 'package:sky/framework/components/menu_divider.dart';
import 'package:sky/framework/components/menu_item.dart';
import 'package:sky/framework/fn.dart';
import 'package:sky/framework/theme/typography.dart' as typography;
import 'stock_data.dart';
import 'stock_list.dart';
import 'stock_menu.dart';

class StocksApp extends App {

  DrawerController _DrawerController = new DrawerController();

  static Style _style = new Style('''
    display: flex;
    flex-direction: column;
    height: -webkit-fill-available;
    ${typography.typeface};
    ${typography.black.body1};'''
  );

  static Style _iconStyle = new Style('''
    padding: 8px;'''
  );

  static Style _titleStyle = new Style('''
    padding-left: 24px;
    flex: 1;
    ${typography.white.title};'''
  );

  List<Stock> _sortedStocks;
  bool _isSearching = false;
  bool _isShowingMenu = false;
  String _searchQuery;

  StocksApp() : super() {
    _sortedStocks = oracle.stocks;
    _sortedStocks.sort((a, b) => a.symbol.compareTo(b.symbol));
  }

  void _handleSearchClick(_) {
    setState(() {
      _isSearching = !_isSearching;
    });
  }

  void _handleMenuClick(_) {
    setState(() {
      _isShowingMenu = !_isShowingMenu;
    });
  }

  void _handleSearchQueryChanged(query) {
    setState(() {
      _searchQuery = query;
    });
  }

  Node build() {
    var drawer = new Drawer(
      controller: _DrawerController,
      level: 3,
      children: [
        new DrawerHeader(
          children: [new Text('Stocks')]
        ),
        new MenuItem(
          key: 'Inbox',
          icon: 'content/inbox',
          children: [new Text('Inbox')]
        ),
        new MenuDivider(
        ),
        new MenuItem(
          key: 'Drafts',
          icon: 'content/drafts',
          children: [new Text('Drafts')]
        ),
        new MenuItem(
          key: 'Settings',
          icon: 'action/settings',
          children: [new Text('Settings')]
        ),
        new MenuItem(
          key: 'Help & Feedback',
          icon: 'action/help',
          children: [new Text('Help & Feedback')]
        )
      ]
    );

    Node title;
    if (_isSearching) {
      title = new Input(focused: true, placeholder: 'Search stocks',
          onChanged: _handleSearchQueryChanged);
    } else {
      title = new Text('Stocks');
    }

    var toolbar = new ActionBar(
      children: [
        new GestureEvents(
          new Icon(key: 'menu', style: _iconStyle,
              size: 24,
              type: 'navigation/menu_white'),
          onTap: _DrawerController.toggle
        ),
        new Container(
          style: _titleStyle,
          children: [title]
        ),
        new GestureEvents(
          new Icon(key: 'search', style: _iconStyle,
              size: 24,
              type: 'action/search_white'),
          onTap: _handleSearchClick
        ),
        new GestureEvents(
          new Icon(key: 'more_white', style: _iconStyle,
              size: 24,
              type: 'navigation/more_vert_white'),
          onTap: _handleMenuClick
        )
      ]
    );

    var list = new Stocklist(stocks: _sortedStocks, query: _searchQuery);

    var fab = new FloatingActionButton(content: new Icon(
      type: 'content/add_white', size: 24), level: 3);

    var children = [
      new Container(
        key: 'Content',
        style: _style,
        children: [toolbar, list]
      ),
      fab,
      drawer
    ];

    if (_isShowingMenu) {
      children.add(new GestureEvents(new StockMenu(), onTap: (_) {
        setState(() {
          _isShowingMenu = false;
        });
      }));
    }

    return new Container(key: 'StocksApp', children: children);
  }
}
