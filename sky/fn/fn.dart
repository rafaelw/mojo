library fn;

import 'dart:sky' as sky;
import 'dart:collection';

/*
 * Simplifying assumptions (for now)
 * 1) Components must return a single, non-component Node as their root
 */

class Style {
  final String _className;
  static Map<String, Style> _cache = null;

  static int nextStyleId = 1;
  static sky.Document document = null;

  static void _initializeStyleCache(sky.Document doc) {
    document = doc;
  }

  static String nextClassName(String styles) {
    assert(document != null);
    var className = "style$nextStyleId";
    nextStyleId++;

    var styleNode = document.createElement('style');
    styleNode.append(new sky.Text(".$className { $styles }"));
    document.querySelector('body').append(styleNode);

    return className;
  }

  factory Style(String styles) {
    if (_cache == null) {
      _cache = new HashMap<String, Style>();
    }

    var style = _cache[styles];
    if (style == null) {
      style = new Style._internal(nextClassName(styles));
      _cache[styles] = style;
    }

    return style;
  }

  Style._internal(this._className);
}

abstract class Node {
  String _key = null;
  sky.Node _root = null;

  Node({ Object key: '' }) {
    _key = "$runtimeType-$key";
  }

  // Return true IFF the old node has *become* the new node (should be retained because it is stateful)
  bool _sync(Node old, sky.Node host, sky.Node insertBefore);
}

class Text extends Node {
  String data;

  Text(this.data, { Object key }) : super(key:key);

  bool _sync(Node old, sky.Node host, sky.Node insertBefore) {
    if (old == null) {
      _root = new sky.Text(data);
      host.insertBefore(_root, insertBefore);
      return false;
    }

    _root = old._root;
//    old._root = null;
    (_root as sky.Text).data = data;

    return false;
  }
}

typedef void EventHandler(sky.Event e);

class Container extends Node {
  EventHandler onClick;

  LinkedHashMap<String, Node> _children = null;
  String className = '';

  Container({
      Object key,
      Iterable<Node> children,
      Style style,
      this.onClick}) : super(key:key) {

    if (style != null)
      className = style._className;

    if (children == null)
      return;

    _children = new LinkedHashMap<String, Node>();
    for (var child in children) {
      bool didPut = false;
      _children.putIfAbsent(child._key, () { didPut = true; return child; });
      assert(didPut); // No two children of the same type can have the same key.
    }
  }

  bool _sync(Node old, sky.Node host, sky.Node insertBefore) {
    if (old == null) {
      _root = sky.document.createElement('div');
      sky.Element root = _root as sky.Element;
      root.setAttribute('class', className);

      if (onClick != null) {
        // TODO(rafaelw): requires cleanup.
        // TODO(rafaelw): consider event delegation.
        // TODO(rafaelw): reduce the boilerplate that this requires.
        root.onClick.listen(onClick);
      }

      for (var key in _children.keys) {
        var child = _children[key];
        child._sync(null, _root, null);
      }

      host.insertBefore(_root, insertBefore);
      return false;
    }

    _root = old._root;
    old._root = null;
    sky.Element root = _root;
    if ((old as Container).className != className)
      root.setAttribute('class', className);
    if ((old as Container).onClick != onClick)
      root.onClick.listen(onClick); // TODO(rafaelw): Cleanup old listener

    // Note: rendering anew is like syncing to a Node that how zero previous children.
    LinkedHashMap<String, Node> oldChildren = (old as Container)._children;
    Iterator<String> oldKeys = oldChildren.keys.iterator;

    sky.Node nextSibling = _root.firstChild;
    Node currentNode = null;
    String currentKey = null;
    Node oldNode = null;
    String oldKey = null;

    // Skips over null positions being created by moving items from later
    // in the collection.
    bool advanceOldPointer() {
      if (!oldKeys.moveNext()) {
        oldNode = null;
        oldKey = null;
        return false;
      }

      oldKey = oldKeys.current;
      oldNode = oldChildren[oldKey];
      if (oldNode == null)
        return advanceOldPointer();

      return true;
    }
    advanceOldPointer();

    void sync() {
      if (currentNode._sync(oldNode, _root, nextSibling)) {
        // oldNode was stateful and must be retained.
        _children[currentKey] = oldNode;
        oldChildren[currentKey] = null;
      }
    }

    for (currentKey in _children.keys) {
      currentNode = _children[currentKey];

      if (currentKey == oldKey) {
        assert(currentNode.runtimeType == oldNode.runtimeType);
        nextSibling = nextSibling.nextNode;
        sync();
        advanceOldPointer();
        continue;
      }

      oldNode = oldChildren[currentKey];
      if (oldNode != null) {
        // Re-order of existing node.
        oldChildren[currentKey] = null;
        _root.insertBefore(oldNode._root, nextSibling);
      }

      currentNode._sync(oldNode, _root, nextSibling);
    }

    while (advanceOldPointer()) {
      oldNode._root.remove();
      // TODO(rafaelw): oldNode._unmount();
    }

    return false;
  }
}

abstract class Component extends Node {
  bool _dirty = false;
  Node _rendered = null;
  bool _stateful = false;

  Component({ Object key }) : super(key:key);

  bool _sync(Node old, sky.Node host, sky.Node insertBefore) {
    if (old == null) {
      _rendered = render();
      _rendered._sync(null, host, insertBefore);
      return false; // new rendering
    }

    Component oldComponent = old as Component;
    if (oldComponent == this) {
      return false;  // Component reused in a new components rendered (e.g. was provided as an argument).
    }

    if (oldComponent != null && oldComponent._stateful) {
      assert(!_stateful);
      oldComponent._copyPublicFields(this);
      this._rendered = oldComponent._rendered;
      oldComponent._rendered = null;
      oldComponent._sync(this, host, insertBefore);
      return true;  // Must retain old component
    }

    _rerender(oldComponent._rendered, host, insertBefore);
    return false;
  }

  void _rerender(Node oldRendered, sky.Node host, sky.Node insertBefore) {
    _rendered = render();
    assert(_rendered is! Component);
    assert(_rendered.runtimeType == oldRendered.runtimeType);
    _rendered._sync(oldRendered, host, insertBefore);
  }

  void _copyPublicFields(Component other) {
    // Not implemented.
    assert(false);
  }

  void setState(Function fn()) {
    // TODO(rafaelw): Enter into a queue of tree-depth-ordered, pending work and batch all dirties until the end of microtask.
    _stateful = true;
    fn();
    _rerender(_rendered, _rendered._root.parentNode, _rendered._root.nextNode);
  }

  Node render();
}

initialize(sky.Document document) {
  Style._initializeStyleCache(document);
}

render(sky.Node host, Component root) {
  var st = new Stopwatch();
  st.start();
  root._sync(null, host, null);
  st.stop();
  print(st.elapsedMilliseconds);
}
