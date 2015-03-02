library fn;

import 'dart:sky' as sky;
import 'dart:collection';
import 'dart:async';
import 'reflect.dart' as reflect;

bool _debugCheckingEnabled = false;

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

  void _remove() {
    assert(_root != null);
    _root.remove();
    _root = null;
  }
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
    (_root as sky.Text).data = data;
    return false;
  }
}

var _emptyList = new List<Node>();

abstract class Element extends Node {

  String get _tagName;

  Element get _emptyElement;

  String inlineStyle;

  sky.EventListener onClick;
  sky.EventListener onFlingCancel;
  sky.EventListener onFlingStart;
  sky.EventListener onGestureTap;
  sky.EventListener onPointerCancel;
  sky.EventListener onPointerDown;
  sky.EventListener onPointerMove;
  sky.EventListener onPointerUp;
  sky.EventListener onScrollEnd;
  sky.EventListener onScrollStart;
  sky.EventListener onScrollUpdate;
  sky.EventListener onWheel;

  List<Node> _children = null;
  String _className = '';

  Element({
    Object key,
    List<Node> children,
    Style style,

    this.inlineStyle,

    // Events
    this.onClick,
    this.onFlingCancel,
    this.onFlingStart,
    this.onGestureTap,
    this.onPointerCancel,
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onScrollEnd,
    this.onScrollStart,
    this.onScrollUpdate,
    this.onWheel
  }) : super(key:key) {

    _className = style == null ? '': style._className;
    _children = children == null ? _emptyList : children;

    if (_debugCheckingEnabled) {
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
    _children = null;
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

  void _syncEvent(String eventName, sky.EventListener listener,
                  sky.EventListener oldListener) {
    sky.Element root = _root as sky.Element;
    if (listener == oldListener)
      return;

    if (oldListener != null) {
      root.removeEventListener(eventName, oldListener);
    }

    if (listener != null) {
      root.addEventListener(eventName, listener);
    }
  }

  void _syncEvents([Element old]) {
    _syncEvent('click', onClick, old.onClick);
    _syncEvent('gestureflingcancel', onFlingCancel, old.onFlingCancel);
    _syncEvent('gestureflingstart', onFlingStart, old.onFlingStart);
    _syncEvent('gesturescrollend', onScrollEnd, old.onScrollEnd);
    _syncEvent('gesturescrollstart', onScrollStart, old.onScrollStart);
    _syncEvent('gesturescrollupdate', onScrollUpdate, old.onScrollUpdate);
    _syncEvent('gesturetap', onGestureTap, old.onGestureTap);
    _syncEvent('pointercancel', onPointerCancel, old.onPointerCancel);
    _syncEvent('pointerdown', onPointerDown, old.onPointerDown);
    _syncEvent('pointermove', onPointerMove, old.onPointerMove);
    _syncEvent('pointerup', onPointerUp, old.onPointerUp);
    _syncEvent('wheel', onWheel, old.onWheel);
  }

  void _syncNode([Element old]) {
    if (old == null) {
      old = _emptyElement;
    }

    _syncEvents(old);

    sky.Element root = _root as sky.Element;
    if (_className != old._className) {
      root.setAttribute('class', _className);
    }

    if (inlineStyle != old.inlineStyle) {
      root.setAttribute('style', inlineStyle);
    }
  }

  bool _sync(Node old, sky.ParentNode host, sky.Node insertBefore) {
    // print("---Syncing children of $_key");

    Element oldElement = old as Element;

    if (oldElement == null) {
      // print("...no oldElement, initial render");

      _root = sky.document.createElement(_tagName);
      _syncNode();

      for (var child in _children) {
        child._sync(null, _root, null);
        assert(child._root is sky.Node);
      }

      parentInsertBefore(host, _root, insertBefore);
      return false;
    }

    _root = oldElement._root;
    oldElement._root = null;
    sky.Element root = (_root as sky.Element);

    _syncNode(oldElement);

    var startIndex = 0;
    var endIndex = _children.length;

    var oldChildren = oldElement._children;
    var oldStartIndex = 0;
    var oldEndIndex = oldChildren.length;

    sky.Node nextSibling = null;
    Node currentNode = null;
    Node oldNode = null;

    void sync(int atIndex) {
      if (currentNode._sync(oldNode, root, nextSibling)) {
        // oldNode was stateful and must be retained.
        assert(oldNode != null);
        currentNode = oldNode;
        _children[atIndex] = currentNode;
      }
      assert(currentNode._root is sky.Node);
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
      oldNode = oldChildren[oldStartIndex];
      // print('> ${oldNode._key} removing from $oldEndIndex');
      oldNode._remove();
      advanceOldStartIndex();
    }

    oldElement._children = null;
    return false;
  }
}

class Container extends Element {

  String get _tagName => 'div';

  static Container _emptyContainer = new Container();

  Element get _emptyElement => _emptyContainer;

  Container({
    Object key,
    List<Node> children,
    Style style,
    String inlineStyle,
    sky.EventListener onClick,
    sky.EventListener onFlingCancel,
    sky.EventListener onFlingStart,
    sky.EventListener onGestureTap,
    sky.EventListener onPointerCancel,
    sky.EventListener onPointerDown,
    sky.EventListener onPointerMove,
    sky.EventListener onPointerUp,
    sky.EventListener onScrollEnd,
    sky.EventListener onScrollStart,
    sky.EventListener onScrollUpdate,
    sky.EventListener onWheel
  }) : super(
    key: key,
    children: children,
    style: style,
    inlineStyle: inlineStyle,
    onClick: onClick,
    onFlingCancel: onFlingCancel,
    onFlingStart: onFlingStart,
    onGestureTap: onGestureTap,
    onPointerCancel: onPointerCancel,
    onPointerDown: onPointerDown,
    onPointerMove: onPointerMove,
    onPointerUp: onPointerUp,
    onScrollEnd: onScrollEnd,
    onScrollStart: onScrollStart,
    onScrollUpdate: onScrollUpdate,
    onWheel: onWheel
  );
}

class Image extends Element {

  String get _tagName => 'img';

  static Image _emptyImage = new Image();
  Element get _emptyElement => _emptyImage;

  String src;
  int width;
  int height;

  Image({
    Object key,
    List<Node> children,
    Style style,
    String inlineStyle,
    sky.EventListener onClick,
    sky.EventListener onFlingCancel,
    sky.EventListener onFlingStart,
    sky.EventListener onGestureTap,
    sky.EventListener onPointerCancel,
    sky.EventListener onPointerDown,
    sky.EventListener onPointerMove,
    sky.EventListener onPointerUp,
    sky.EventListener onScrollEnd,
    sky.EventListener onScrollStart,
    sky.EventListener onScrollUpdate,
    sky.EventListener onWheel,
    this.width,
    this.height,
    this.src
  }) : super(
    key: key,
    children: children,
    style: style,
    inlineStyle: inlineStyle,
    onClick: onClick,
    onFlingCancel: onFlingCancel,
    onFlingStart: onFlingStart,
    onGestureTap: onGestureTap,
    onPointerCancel: onPointerCancel,
    onPointerDown: onPointerDown,
    onPointerMove: onPointerMove,
    onPointerUp: onPointerUp,
    onScrollEnd: onScrollEnd,
    onScrollStart: onScrollStart,
    onScrollUpdate: onScrollUpdate,
    onWheel: onWheel
  );

  void _syncNode([Element old]) {
    super._syncNode(old);

    Image oldImage = old != null ? old : _emptyImage;
    sky.HTMLImageElement skyImage = _root as sky.HTMLImageElement;
    if (src != oldImage.src) {
      skyImage.src = src;
    }

    if (width != oldImage.width) {
      skyImage.style['width'] = '${width}px';
    }
    if (height != oldImage.height) {
      skyImage.style['height'] = '${height}px';
    }
  }
}

class Anchor extends Element {

  String get _tagName => 'a';

  static Anchor _emptyAnchor = new Anchor();

  String href;

  Anchor({
    Object key,
    List<Node> children,
    Style style,
    String inlineStyle,
    sky.EventListener onClick,
    sky.EventListener onFlingCancel,
    sky.EventListener onFlingStart,
    sky.EventListener onGestureTap,
    sky.EventListener onPointerCancel,
    sky.EventListener onPointerDown,
    sky.EventListener onPointerMove,
    sky.EventListener onPointerUp,
    sky.EventListener onScrollEnd,
    sky.EventListener onScrollStart,
    sky.EventListener onScrollUpdate,
    sky.EventListener onWheel,
    this.width,
    this.height,
    this.href
  }) : super(
    key: key,
    children: children,
    style: style,
    inlineStyle: inlineStyle,
    onClick: onClick,
    onFlingCancel: onFlingCancel,
    onFlingStart: onFlingStart,
    onGestureTap: onGestureTap,
    onPointerCancel: onPointerCancel,
    onPointerDown: onPointerDown,
    onPointerMove: onPointerMove,
    onPointerUp: onPointerUp,
    onScrollEnd: onScrollEnd,
    onScrollStart: onScrollStart,
    onScrollUpdate: onScrollUpdate,
    onWheel: onWheel
  );

  void _syncNode([Element old]) {
    Anchor oldAnchor = old != null ? old as Anchor : _emptyAnchor;
    super._syncNode(oldAnchor);

    sky.HTMLAnchorElement skyAnchor = _root as sky.HTMLAnchorElement;
    if (href != oldAnchor.href) {
      skyAnchor.href = href;
    }
  }
}

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

enum MountState { UNMOUNTED, MOUNTING, MOUNTED, UNMOUNTING, REMOVED }

abstract class Component extends Node {
  bool _dirty = true; // components begin dirty because they haven't rendered.
  Node _rendered = null;
  int _order;
  static int _currentOrder = 0;
  bool _stateful;
  MountState _mountState = MountState.UNMOUNTED;

  Component({ Object key, bool stateful })
      : _stateful = stateful != null ? stateful : false,
        _order = _currentOrder + 1,
        super(key:key);

  void didMount() {}
  void willUnmount() {}

  void _remove() {
    assert(_rendered != null);
    assert(_root != null);
    _mountState = MountState.UNMOUNTING;
    willUnmount();
    _mountState = MountState.REMOVED;
    _rendered._remove();
    _rendered = null;
    _root = null;
  }

  // TODO(rafaelw): It seems wrong to expose DOM at all. This is presently
  // needed to get sizing info.
  sky.Node getRoot() => _root;

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
      _stateful = false; // prevent iloop from _renderInternal below.

      reflect.copyPublicFields(this, oldComponent);

      oldComponent._dirty = true;
      _dirty = false;

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

    if (_mountState == MountState.UNMOUNTED) {
      _mountState = MountState.MOUNTING;
    }

    var oldRendered = _rendered;
    int lastOrder = _currentOrder;
    _currentOrder = _order;
    _rendered = render();
    _currentOrder = lastOrder;

    _dirty = false;

    // TODO(rafaelw): This prevents components from returning different node
    // types as their root node at different times. Consider relaxing.
    assert(oldRendered == null ||
           _rendered.runtimeType == oldRendered.runtimeType);

    if (_rendered._sync(oldRendered, host, insertBefore)) {
      _rendered = oldRendered; // retain stateful component
    }
    _root = _rendered._root;
    assert(_rendered._root is sky.Node);
    if (_mountState == MountState.MOUNTING) {
      didMount();
      _mountState = MountState.MOUNTED;
    }
  }

  void _renderIfDirty() {
    if (_mountState == MountState.UNMOUNTING ||
        _mountState == MountState.REMOVED) {
      return;
    }

    assert(_rendered != null);
    var rendered = _rendered;
    while (rendered is Component) {
      rendered = rendered._rendered;
    }
    sky.Node root = rendered._root;

    _renderInternal(root.parentNode, root.nextSibling);
  }

  void setState(Function fn()) {
    assert(_mountState == MountState.MOUNTED);
    assert(_rendered != null); // cannot setState before mounting.
    _dirty = true;
    _stateful = true;
    fn();
    _scheduleComponentForRender(this);
  }

  Node render();
}

abstract class App extends Component {
  sky.Node _host = null;
  App({ bool devMode : false })
    : super(key:'App', stateful: true) {

    _debugCheckingEnabled = devMode;
    _host = sky.document.createElement('div');
    sky.document.appendChild(_host);

    new Future.microtask(() {
      Stopwatch sw = new Stopwatch()..start();
      didMount();
      _sync(null, _host, null);
      assert(_root is sky.Node);
      sw.stop();
      print("Initial render: ${sw.elapsedMicroseconds} microseconds");
    });
  }
}
