// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This app is run by examples/dart/hello_world/hello.

import 'dart:mojo_application';
import 'dart:mojo_bindings';
import 'dart:mojo_core';

class World extends Application {
  World.fromHandle(MojoHandle handle) : super.fromHandle(handle);

  void initialize(List<String> args, String url) {
    print("$url World");
    close();
  }
}

main(List args) {
  MojoHandle appHandle = new MojoHandle(args[0]);
  var world = new World.fromHandle(appHandle);
  world.listen();
}
