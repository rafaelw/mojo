// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library fn;

import 'dart:async';
import 'dart:collection';
import 'dart:sky' as sky;
import 'reflect.dart' as reflect;

bool _initIsInCheckedMode() {
  String testFn(i) { double d = i; return d.toString(); }
  try {
    testFn('not a double');
  } catch (ex) {
    return true;
  }
  return false;
}

final bool _isInCheckedMode = _initIsInCheckedMode();
final bool _shouldLogRenderDuration = false;

class EventHandler {
  final String type;
  final sky.EventListener listener;

  EventHandler(this.type, this.listener);
}

class EventMap {
  final List<EventHandler> _handlers = new List<EventHandler>();

  void listen(String type, sky.EventListener listener) {
    assert(listener != null);
    _handlers.add(new EventHandler(type, listener));
  }

  void addAll(EventMap events) {
    _handlers.addAll(events._handlers);
  }
}

class Style {
  final String _className;
  static final Map<String, Style> _cache = new HashMap<String, Style>();

  static int _nextStyleId = 1;

  static String _getNextClassName() { return "style${_nextStyleId++}"; }

  Style extend(Style other) {
    var className = "$_className ${other._className}";

    return _cache.putIfAbsent(className, () {
      return new Style._internal(className);
    });
  }

  factory Style(String styles) {
    return _cache.putIfAbsent(styles, () {
      var className = _getNextClassName();
      sky.Element styleNode = sky.document.createElement('style');
      styleNode.setChild(new sky.Text(".$className { $styles }"));
      sky.document.appendChild(styleNode);
      return new Style._internal(className);
    });
  }

  Style._internal(this._className);
}

void _parentInsertBefore(sky.ParentNode parent,
                         sky.Node node,
                         sky.Node ref) {
  if (ref != null) {
    ref.insertBefore([node]);
  } else {
    parent.appendChild(node);
  }
}

/*
 * All Effen nodes derive from Node. All nodes have a _parent, a _key and
 * can be sync'd.
 */
abstract class Node {
  String _key;
  Node _parent;
  sky.Node _root;

  // TODO(abarth): Both Elements and Components have |events| but |Text|
  // doesn't. Should we add a common base class to contain |events|?
  final EventMap events = new EventMap();

  Node({ Object key }) {
    _key = key == null ? "$runtimeType" : "$runtimeType-$key";
  }

  bool _willSync(Node old) => false;

  void _sync(Node old, sky.ParentNode host, sky.Node insertBefore);

  void _remove();

  Node _syncChild(Node node, Node oldNode, sky.ParentNode host,
      sky.Node insertBefore) {
    if (node == oldNode)
      return node; // Nothing to do. Subtrees must be identical.

    // TODO(rafaelw): This eagerly removes the old DOM. It may be that a
    // new component was built that could re-use some of it. Consider
    // syncing the new VDOM against the old one.
    if (oldNode != null && node._key != oldNode._key) {
      oldNode._remove();
      oldNode = null;
    }

    if (node._willSync(oldNode)) {
      oldNode._sync(node, host, insertBefore);
      assert(oldNode._root is sky.Node);
      return oldNode;
    }

    node._parent = this;
    node._sync(oldNode, host, insertBefore);
    assert(node._root is sky.Node);
    return node;
  }
}

/*
 * RenderNodes correspond to a desired state of a sky.Node. They are fully
 * immutable, with one exception: A Node which is a Component which lives within
 * an Element's children list, may be replaced with the "old" instance if it
 * has become stateful.
 */
abstract class RenderNode extends Node {

  RenderNode({ Object key }) : super(key: key);

  RenderNode get _emptyNode;

  sky.Node _createNode();

  void _sync(Node old, sky.ParentNode host, sky.Node insertBefore) {
    if (old == null) {
      _root = _createNode();
      _parentInsertBefore(host, _root, insertBefore);
      old = _emptyNode;
    } else {
      _root = old._root;
    }

    _syncNode(old);
  }

  void _syncNode(RenderNode old);

  void _remove() {
    assert(_root != null);
    _root.remove();
    _root = null;
  }
}

class Text extends RenderNode {
  final String data;

  // Text nodes are special cases of having non-unique keys (which don't need
  // to be assigned as part of the API). Since they are unique in not having
  // children, there's little point to reordering, so we always just re-assign
  // the data.
  Text(this.data) : super(key:'*text*');

  static Text _emptyText = new Text(null);

  RenderNode get _emptyNode => _emptyText;

  sky.Node _createNode() {
    return new sky.Text(data);
  }

  void _syncNode(RenderNode old) {
    if (old == _emptyText)
      return; // we set inside _createNode();

    (_root as sky.Text).data = data;
  }
}

final List<Node> _emptyList = new List<Node>();

abstract class Element extends RenderNode {

  String get _tagName;

  sky.Node _createNode() => sky.document.createElement(_tagName);

  final String inlineStyle;

  final List<Node> _children;
  final String _class;

  Element({
    Object key,
    List<Node> children,
    Style style,
    this.inlineStyle
  }) : _class = style == null ? '' : style._className,
       _children = children == null ? _emptyList : children,
       super(key:key) {

    if (_isInCheckedMode) {
      _debugReportDuplicateIds();
    }
  }

  void _remove() {
    super._remove();
    if (_children != null) {
      for (var child in _children) {
        child._remove();
      }
    }
  }

  void _debugReportDuplicateIds() {
    var idSet = new HashSet<String>();
    for (var child in _children) {
      if (child is Text) {
        continue; // Text nodes all have the same key and are never reordered.
      }

      if (!idSet.add(child._key)) {
        throw '''If multiple (non-Text) nodes of the same type exist as children
                 of another node, they must have unique keys.''';
      }
    }
  }

  void _syncEvents([Element old]) {
    List<EventHandler> newHandlers = events._handlers;
    int newStartIndex = 0;
    int newEndIndex = newHandlers.length;

    List<EventHandler> oldHandlers = old.events._handlers;
    int oldStartIndex = 0;
    int oldEndIndex = oldHandlers.length;

    // Skip over leading handlers that match.
    while (newStartIndex < newEndIndex && oldStartIndex < oldEndIndex) {
      EventHandler newHandler = newHandlers[newStartIndex];
      EventHandler oldHandler = oldHandlers[oldStartIndex];
      if (newHandler.type != oldHandler.type
          || newHandler.listener != oldHandler.listener)
        break;
      ++newStartIndex;
      ++oldStartIndex;
    }

    // Skip over trailing handlers that match.
    while (newStartIndex < newEndIndex && oldStartIndex < oldEndIndex) {
      EventHandler newHandler = newHandlers[newEndIndex - 1];
      EventHandler oldHandler = oldHandlers[oldEndIndex - 1];
      if (newHandler.type != oldHandler.type
          || newHandler.listener != oldHandler.listener)
        break;
      --newEndIndex;
      --oldEndIndex;
    }

    sky.Element root = _root as sky.Element;

    for (int i = oldStartIndex; i < oldEndIndex; ++i) {
      EventHandler oldHandler = oldHandlers[i];
      root.removeEventListener(oldHandler.type, oldHandler.listener);
    }

    for (int i = newStartIndex; i < newEndIndex; ++i) {
      EventHandler newHandler = newHandlers[i];
      root.addEventListener(newHandler.type, newHandler.listener);
    }
  }

  void _syncNode(RenderNode old) {
    Element oldElement = old as Element;
    sky.Element root = _root as sky.Element;

    _syncEvents(oldElement);

    if (_class != oldElement._class)
      root.setAttribute('class', _class);

    if (inlineStyle != oldElement.inlineStyle)
      root.setAttribute('style', inlineStyle);

    _syncChildren(oldElement);
  }

  void _syncChildren(Element oldElement) {
    // print("---Syncing children of $_key");
    sky.Element root = _root as sky.Element;
    assert(root != null);

    var startIndex = 0;
    var endIndex = _children.length;

    var oldChildren = oldElement._children;
    var oldStartIndex = 0;
    var oldEndIndex = oldChildren.length;

    sky.Node nextSibling = null;
    Node currentNode = null;
    Node oldNode = null;

    void sync(int atIndex) {
      _children[atIndex] = _syncChild(currentNode, oldNode, _root, nextSibling);
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
      if (oldNodeIdMap != null)
        return;

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
      // print("Reparenting ${currentNode._key}");
      _parentInsertBefore(root, oldNode._root, nextSibling);
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
      oldNode = oldChildren[oldStartIndex];
      // print('> ${oldNode._key} removing from $oldEndIndex');
      oldNode._remove();
      advanceOldStartIndex();
    }
  }
}

class Container extends Element {

  String get _tagName => 'div';

  static final Container _emptyContainer = new Container();

  RenderNode get _emptyNode => _emptyContainer;

  Container({
    Object key,
    List<Node> children,
    Style style,
    String inlineStyle
  }) : super(
    key: key,
    children: children,
    style: style,
    inlineStyle: inlineStyle
  );
}

class Image extends Element {

  String get _tagName => 'img';

  static final Image _emptyImage = new Image();

  RenderNode get _emptyNode => _emptyImage;

  final String src;
  final int width;
  final int height;

  Image({
    Object key,
    List<Node> children,
    Style style,
    String inlineStyle,
    this.width,
    this.height,
    this.src
  }) : super(
    key: key,
    children: children,
    style: style,
    inlineStyle: inlineStyle
  );

  void _syncNode(Node old) {
    super._syncNode(old);

    Image oldImage = old as Image;
    sky.HTMLImageElement skyImage = _root as sky.HTMLImageElement;

    if (src != oldImage.src)
      skyImage.src = src;

    if (width != oldImage.width)
      skyImage.style['width'] = '${width}px';

    if (height != oldImage.height)
      skyImage.style['height'] = '${height}px';
  }
}

class Anchor extends Element {

  String get _tagName => 'a';

  static final Anchor _emptyAnchor = new Anchor();

  Node get _emptyNode => _emptyAnchor;

  final String href;
  final int width;
  final int height;

  Anchor({
    Object key,
    List<Node> children,
    Style style,
    String inlineStyle,
    this.width,
    this.height,
    this.href
  }) : super(
    key: key,
    children: children,
    style: style,
    inlineStyle: inlineStyle
  );

  void _syncNode(Node old) {
    super._syncNode(old);

    Anchor oldAnchor = old as Anchor;
    sky.HTMLAnchorElement skyAnchor = _root as sky.HTMLAnchorElement;

    if (href != oldAnchor.href)
      skyAnchor.href = href;
  }
}

List<Component> _dirtyComponents = new List<Component>();
bool _buildScheduled = false;
bool _inRenderDirtyComponents = false;

void _buildDirtyComponents() {
  try {
    _inRenderDirtyComponents = true;
    Stopwatch sw = new Stopwatch()..start();

    _dirtyComponents.sort((a, b) => a._order - b._order);
    for (var comp in _dirtyComponents) {
      comp._buildIfDirty();
    }

    _dirtyComponents.clear();
    _buildScheduled = false;

    sw.stop();
    if (_shouldLogRenderDuration)
      print("Render took ${sw.elapsedMicroseconds} microseconds");
  } finally {
    _inRenderDirtyComponents = false;
  }
}

void _scheduleComponentForRender(Component c) {
  assert(!_inRenderDirtyComponents);
  _dirtyComponents.add(c);

  if (!_buildScheduled) {
    _buildScheduled = true;
    new Future.microtask(_buildDirtyComponents);
  }
}

abstract class Component extends Node {
  bool get _dirty => _built == null;
  bool get _isBuilding => _currentlyBuilding == this;

  Node _built;
  Node _oldBuilt;
  final int _order;
  static int _currentOrder = 0;
  bool _stateful;
  static Component _currentlyBuilding;
  bool _defunct = false;

  Component({ Object key, bool stateful })
      : _stateful = stateful != null ? stateful : false,
        _order = _currentOrder + 1,
        super(key:key);

  void didMount() {}
  void didUnmount() {}

  // TODO(rafaelw): It seems wrong to expose DOM at all. This is presently
  // needed to get sizing info.
  sky.Node getRoot() => _root;

  void _remove() {
    assert(_built != null);
    assert(_root != null);
    _built._remove();
    _built = null;
    _root = null;
    _defunct = true;
    didUnmount();
  }

  bool _willSync(Node old) {
    Component oldComponent = old as Component;
    if (oldComponent == null || !oldComponent._stateful)
      return false;

    // Make |this| the "old" Component
    _stateful = false;
    _built = oldComponent._built;

    // Make |oldComponent| the "new" component
    reflect.copyPublicFields(this, oldComponent);
    oldComponent._built = null;

    return true;
  }

  void _sync(Node old, sky.ParentNode host, sky.Node insertBefore) {
    assert(_built == null);

    Component oldComponent = old as Component;

    if (oldComponent != null) {
      _oldBuilt = oldComponent._built;
      oldComponent._defunct = true;
    }

    bool willMount = _oldBuilt == null;
    int lastOrder = _currentOrder;
    _currentOrder = _order;
    _currentlyBuilding = this;
    _built = build();
    _currentlyBuilding = null;
    _currentOrder = lastOrder;
    _built = _syncChild(_built, _oldBuilt, host, insertBefore);
	_built.events.addAll(events);
    _root = _built._root;

    if (willMount)
      didMount();
  }

  void _buildIfDirty() {
    if (_defunct || !_dirty)
      return;

    assert(_root != null);
    _sync(null, _root.parentNode, _root.nextSibling);
  }

  void setState(Function fn()) {
    assert(!_dirty || _defunct); // cannot setState before mounting.
    _stateful = true;
    fn();
    if (_defunct || _dirty || _isBuilding)
      return;

    assert(_oldBuilt == null);
    _oldBuilt = _built;
    _built = null;
    _scheduleComponentForRender(this);
  }

  Node build();
}

abstract class App extends Component {
  sky.Node _host = null;
  App() : super(stateful: true) {
    _host = sky.document.createElement('div');
    sky.document.appendChild(_host);

    new Future.microtask(() {
      Stopwatch sw = new Stopwatch()..start();

      _sync(null, _host, null);
      assert(_root is sky.Node);

      sw.stop();
      if (_shouldLogRenderDuration)
        print("Initial build: ${sw.elapsedMicroseconds} microseconds");
    });
  }
}
