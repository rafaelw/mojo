library fn;

import 'dart:sky' as sky;
import 'dart:collection';
import 'dart:async';
import 'reflect.dart' as reflect;

/*
 * Simplifying assumptions (for now)
 * 1) Components must return a single, non-component Node as their root
 */

bool _g_enableDevMode = false;

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

  // Text nodes are special cases of having non-unique keys (which don't need
  // to be assigned as part of the API). Since they are unique in not having
  // children, there's little point to reordering, so we always just re-assign
  // the data.
  Text(this.data) : super(key:'*text*');

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

var _emptyList = new List<Node>();

class Container extends Node {
  sky.EventListener onClick;


  List<Node> _children = null;
  String _className = '';

  Container({
      Object key,
      List<Node> children,
      Style style,
      this.onClick}) : super(key:key) {

    _className = style == null ? '': style._className;
    _children = children == null ? _emptyList : children;

    if (_g_enableDevMode) {
      _debugReportDuplicateIds();
    }
  }

  void _debugReportDuplicateIds() {
    var idMap = new HashMap<String, Node>();
    for (var child in _children) {
      if (child is Text) {
        continue; // Text nodes all have the same key and are never reordered.
      }

      bool didPut = false;
      idMap.putIfAbsent(child._key, () { didPut = true; return child; });
      // No two children of the same type can have the same key.
      assert(didPut);
    }
  }

  bool _sync(Node old, sky.ParentNode host, sky.Node insertBefore) {
    // print("---Syncing children of $_key");

    Container oldContainer = old as Container;

    if (oldContainer == null) {
      // print("...no oldContainer, initial render");

      _root = sky.document.createElement('div');
      sky.Element root = _root as sky.Element;
      root.setAttribute('class', _className);

      if (onClick != null) {
        // TODO(rafaelw): requires cleanup.
        // TODO(rafaelw): consider event delegation.
        // TODO(rafaelw): reduce the boilerplate that this requires.
        root.addEventListener('click', onClick);
      }

      for (var child in _children) {
        child._sync(null, _root, null);
      }

      parentInsertBefore(host, _root, insertBefore);
      return false;
    }

    _root = oldContainer._root;
    oldContainer._root = null;
    sky.Element root = (_root as sky.Element);

    if (oldContainer._className != _className) {
      root.setAttribute('class', _className);
    }
    if (oldContainer.onClick != onClick) {
      // TODO(rafaelw): Cleanup old listener
      root.addEventListener('click', onClick);
    }

    var startIndex = 0;
    var endIndex = _children.length;

    var oldChildren = oldContainer._children;
    var oldStartIndex = 0;
    var oldEndIndex = oldChildren.length;

    sky.Node nextSibling = null;
    Node currentNode = null;
    Node oldNode = null;

    void sync(int atIndex) {
      if (currentNode._sync(oldNode, root, nextSibling)) {
        // oldNode was stateful and must be retained.
        assert(oldNode != null);
        _children[atIndex] = oldNode;
      }
    }

    // Scan backwards from end of list while nodes can be directly synced
    // without reordering.
    // print("...scanning backwards");
    while (endIndex > startIndex && oldEndIndex > oldStartIndex) {
      currentNode = _children[endIndex - 1];
      oldNode = oldChildren[oldEndIndex - 1];

      if (currentNode._key != oldNode._key) {
        break;
      }

      // print('> syncing matched at: $endIndex : $oldEndIndex');
      endIndex--;
      oldEndIndex--;
      sync(endIndex);
      nextSibling = currentNode._root;
    }

    HashMap<String, Node> oldNodeIdMap = null;

    bool oldNodeReordered(String key) {
      return oldNodeIdMap != null &&
             oldNodeIdMap.containsKey(key) &&
             oldNodeIdMap[key] == null;
    }

    void advanceOldStartIndex() {
      oldStartIndex++;
      while (oldStartIndex < oldEndIndex &&
             oldNodeReordered(oldChildren[oldStartIndex]._key)) {
        oldStartIndex++;
      }
    }

    void ensureOldIdMap() {
      oldNodeIdMap = new HashMap<String, Node>();
      for (int i = oldStartIndex; i < oldEndIndex; i++) {
        var node = oldChildren[i];
        if (node is! Text) {
          oldNodeIdMap.putIfAbsent(node._key, () => node);
        }
      }
    }

    bool searchForOldNode() {
      if (currentNode is Text)
        return false; // Never re-order Text nodes.

      ensureOldIdMap();
      oldNode = oldNodeIdMap[currentNode._key];
      if (oldNode == null)
        return false;

      oldNodeIdMap[currentNode._key] = null; // mark it reordered.
      parentInsertBefore(root, oldNode._root, nextSibling);
      return true;
    }

    // Scan forwards, this time we may re-order;
    // print("...scanning forward");
    nextSibling = root.firstChild;
    while (startIndex < endIndex && oldStartIndex < oldEndIndex) {
      currentNode = _children[startIndex];
      oldNode = oldChildren[oldStartIndex];

      if (currentNode._key == oldNode._key) {
        // print('> syncing matched at: $startIndex : $oldStartIndex');
        assert(currentNode.runtimeType == oldNode.runtimeType);
        nextSibling = nextSibling.nextSibling;
        sync(startIndex);
        startIndex++;
        advanceOldStartIndex();
        continue;
      }

      oldNode = null;
      if (searchForOldNode()) {
        // print('> reordered to $startIndex');
      } else {
        // print('> inserting at $startIndex');
      }

      sync(startIndex);
      startIndex++;
    }

    // New insertions
    oldNode = null;
    // print('...processing remaining insertions');
    while (startIndex < endIndex) {
      // print('> inserting at $startIndex');
      currentNode = _children[startIndex];
      sync(startIndex);
      startIndex++;
    }

    // Removals
    // print('...processing remaining removals');
    currentNode = null;
    while (oldStartIndex < oldEndIndex) {
      // print('> removing from $oldEndIndex');
      oldNode = oldChildren[oldStartIndex];
      // TODO(rafaelw): oldNode._unmount();
      oldNode._root.remove();
      advanceOldStartIndex();
    }

    oldContainer._children = null;
    return false;
  }
}


// TODO(rafaelw): Make all of the rescheduleDirty stuff class-statics on
// Component.
List<Component> _dirtyComponents = new List<Component>();
bool _renderScheduled = false;

void _renderDirtyComponents() {
  Stopwatch sw = new Stopwatch()..start();

  _dirtyComponents.sort((a, b) => a._order - b._order);
  for (var comp in _dirtyComponents) {
    comp._renderIfDirty();
  }

  _dirtyComponents.clear();
  _renderScheduled = false;
  sw.stop();
  print("Render took ${sw.elapsedMicroseconds} microseconds");
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
      reflect.copyPublicFields(this, oldComponent);
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

    // TODO(rafaelw): This prevents components from returing different node
    // types as their root node at different times. Consider relaxing.
    assert(oldRendered == null ||
           _rendered.runtimeType == oldRendered.runtimeType);

    if (_rendered._sync(oldRendered, host, insertBefore)) {
      _rendered = oldRendered; // retain stateful component
    }
  }

  void _renderIfDirty() {
    assert(_rendered != null);
    var rendered = _rendered;
    while (rendered is Component) {
      rendered = rendered._rendered;
    }
    sky.Node root = rendered._root;

    _renderInternal(root.parentNode, root.nextSibling);
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
  App({ bool devMode : false })
    : super(key:'App') {

    _g_enableDevMode = devMode;
    _host = sky.document.createElement('div');
    sky.document.appendChild(_host);

    new Future.microtask(() {
      Stopwatch sw = new Stopwatch()..start();
      _sync(null, _host, null);
      sw.stop();
      print("Initial render: ${sw.elapsedMicroseconds} microseconds");
    });
  }
}
