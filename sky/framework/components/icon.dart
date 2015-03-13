// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../fn.dart';

// TODO(eseidel): This should use package:.
const String kAssetBase = '/packages/sky/assets/material-design-icons';

class Icon extends Component {
  Style style;
  int size;
  String type;

  Icon({
    String key,
    Events events,
    this.style,
    this.size,
    this.type: ''
  }) : super(key: key, events: events);

  Node build() {
    String category = '';
    String subtype = '';
    List<String> parts = type.split('/');
    if (parts.length == 2) {
      category = parts[0];
      subtype = parts[1];
    }

    return new Image(
      style: style,
      width: size,
      height: size,
      src: '${kAssetBase}/${category}/2x_web/ic_${subtype}_${size}dp.png'
    );
  }
}
