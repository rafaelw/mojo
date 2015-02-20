library fn;

import 'dart:sky' as sky;
import 'dart:collection';
import 'dart:async';

/*
 * Simplifying assumptions (for now)
 * 1) Components must return a single, non-component Node as their root
 */

void parentInsertBefore(sky.ParentNode parent,
                                    sky.Node node,
                                    sky.Node ref) {
  if (ref != null) {
    ref.insertBefore([node]);
  } else {
    parent.appendChild(node);
  }
}

class Style {
  final String _className;
  static Map<String, Style> _cache = null;

  static int nextStyleId = 1;

  static String nextClassName(String styles) {
    assert(sky.document != null);
    var className = "style$nextStyleId";
    nextStyleId++;

    var styleNode = sky.document.createElement('style');
    styleNode.setChild(new sky.Text(".$className { $styles }"));
    sky.document.appendChild(styleNode);

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

  // Return true IFF the old node has *become* the new node (should be
  // retained because it is stateful)
  bool _sync(Node old, sky.ParentNode host, sky.Node insertBefore);
}

class Text extends Node {
  String data;

  Text(this.data, { Object key }) : super(key:key);

  bool _sync(Node old, sky.ParentNode host, sky.Node insertBefore) {
    if (old == null) {
      _root = new sky.Text(data);
      parentInsertBefore(host, _root, insertBefore);
      return false;
    }

    _root = old._root;
//    old._root = null;
    (_root as sky.Text).data = data;

    return false;
  }
}

class Container extends Node {
  sky.EventListener onClick;

  // TODO(make children an Iterable and keep a seperate HashMap of
  // key->Node.
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
      // No two children of the same type can have the same key.
      assert(didPut);
    }
  }

  bool _sync(Node old, sky.ParentNode host, sky.Node insertBefore) {
    if (old == null) {
      _root = sky.document.createElement('div');
      sky.Element root = _root as sky.Element;
      root.setAttribute('class', className);

      if (onClick != null) {
        // TODO(rafaelw): requires cleanup.
        // TODO(rafaelw): consider event delegation.
        // TODO(rafaelw): reduce the boilerplate that this requires.
        root.addEventListener('click', onClick);
      }

      for (var key in _children.keys) {
        var child = _children[key];
        child._sync(null, _root, null);
      }

      parentInsertBefore(host, _root, insertBefore);
      return false;
    }

    _root = old._root;
    old._root = null;
    sky.Element root = (_root as sky.Element);
    if ((old as Container).className != className) {
      root.setAttribute('class', className);
    }
    if ((old as Container).onClick != onClick) {
      // TODO(rafaelw): Cleanup old listener
      root.addEventListener('click', onClick);
    }

    // Note: rendering anew is like syncing to a Node that how zero
    // previous children.
    LinkedHashMap<String, Node> oldChildren = (old as Container)._children;
    Iterator<String> oldKeys = oldChildren.keys.iterator;

    sky.Node nextSibling = root.firstChild;
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
      if (currentNode._sync(oldNode, root, nextSibling)) {
        // oldNode was stateful and must be retained.
        _children[currentKey] = oldNode;
        oldChildren[currentKey] = null;
      }
    }

    for (currentKey in _children.keys) {
      currentNode = _children[currentKey];
      if (currentKey == oldKey) {
        assert(currentNode.runtimeType == oldNode.runtimeType);
        nextSibling = nextSibling.nextSibling;
        sync();
        advanceOldPointer();
        continue;
      }

      oldNode = oldChildren[currentKey];
      if (oldNode != null) {
        // Re-order of existing node.
        oldChildren[currentKey] = null;
        parentInsertBefore(root, oldNode._root, nextSibling);
      }

      currentNode._sync(oldNode, root, nextSibling);
    }

    while (advanceOldPointer()) {
      oldNode._root.remove();
      // TODO(rafaelw): oldNode._unmount();
    }

    return false;
  }
}

List<Component> _dirtyComponents = new List<Component>();
bool _renderScheduled = false;

void _renderDirtyComponents() {
  _dirtyComponents.sort((a, b) => a._order - b._order);
  for (var comp in _dirtyComponents) {
    comp._renderIfDirty();
  }

  _dirtyComponents.clear();
  _renderScheduled = false;
}

void _scheduleComponentForRender(Component c) {
  _dirtyComponents.add(c);

  if (!_renderScheduled) {
    _renderScheduled = true;
    new Future.microtask(_renderDirtyComponents);
  }
}

abstract class Component extends Node {
  bool _dirty = true;
  Node _rendered = null;
  int _order;
  static int _currentOrder = 0;

  // TODO(rafaelw): For now, treat all components as stateful so that we
  // don't have to proxy event handlers.
  bool _stateful = true;

  Component({ Object key })
      : _order = _currentOrder + 1,
        super(key:key) {
  }

  bool _sync(Node old, sky.Node host, sky.Node insertBefore) {
    Component oldComponent = old as Component;

    if (oldComponent == null || oldComponent == this) {
      _renderInternal(host, insertBefore);
      return false;
    }

    assert(oldComponent != null);
    assert(_dirty);
    assert(_rendered == null);

    if (oldComponent._stateful) {
      // assert(!_stateful); // TODO(rafaelw): Remove. See above.
      oldComponent._copyPublicFields(this);
      oldComponent._dirty = true;

      _dirty = false;
      _stateful = false;

      oldComponent._renderInternal(host, insertBefore);
      return true;  // Must retain old component
    }

    _rendered = oldComponent._rendered;
    _renderInternal(host, insertBefore);
    return false;
  }

  void _renderInternal(sky.Node host, sky.Node insertBefore) {
    if (!_dirty) {
      assert(_rendered != null);
      return;
    }

    var oldRendered = _rendered;
    int lastOrder = _currentOrder;
    _currentOrder = _order;
    _rendered = render();
    _currentOrder = lastOrder;

    _dirty = false;

    assert(_rendered is! Component);
    assert(oldRendered == null ||
              _rendered.runtimeType == oldRendered.runtimeType);
    _rendered._sync(oldRendered, host, insertBefore);
  }

  void _copyPublicFields(Component other) {
    // TODO(rafaelw): Not implemented.
  }

  void _renderIfDirty() {
    assert(_rendered != null);
    _renderInternal(_rendered._root.parentNode,
                           _rendered._root.nextSibling);
  }

  void setState(Function fn()) {
    _dirty = true;
    // TODO(rafaelw): Enter into a queue of tree-depth-ordered, pending
    // work and batch all dirties until the end of microtask.
    _stateful = true;
    fn();
    _scheduleComponentForRender(this);
  }

  Node render();
}

abstract class App extends Component {
  sky.Node _host = null;
  App() : super(key:'App') {
    _host = sky.document.createElement('div');
    sky.document.appendChild(_host);

    new Future.microtask(() {
      _sync(null, _host, null);
    });
  }
}
