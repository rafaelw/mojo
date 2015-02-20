
class Node {

  ParentNode parentNode;
  Node nextSibling;
  Node previousSibling;
  Node();

  void insertBefore(List<Node> nodes) {
    assert(parentNode != null);

    if (previousSibling == null) {
      parentNode.firstChild = nodes[0];
    } else {
      previousSibling.nextSibling = nodes[0];
    }

    int length = nodes.length;
    for (var i = 0; i < length - 1; i++) {
      nodes[i].nextSibling = nodes[i + 1];
      nodes[i].parentNode = parentNode;
    }

    nodes[length - 1].nextSibling = this;
    nodes[length - 1].parentNode = parentNode;
  }

  remove() {
    if (parentNode == null) {
      return;
    }

    if (nextSibling != null) {
      nextSibling.previousSibling = previousSibling;
    } else {
      parentNode.lastChild = previousSibling;
    }

    if (previousSibling != null) {
      previousSibling.nextSibling = nextSibling;
    } else {
      parentNode.firstChild = nextSibling;
    }

    parentNode = null;
    nextSibling = null;
    previousSibling = null;
  }
}

class Text extends Node {
  String data;
  Text(this.data) : super();
}

class ParentNode extends Node {
  Node firstChild;
  Node lastChild;

  ParentNode() : super();

  Node setChild(Node node) {
    firstChild = node;
    lastChild = node;
    return node;
  }

  Node appendChild(Node node) {
    node.remove();

    node.parentNode = this;

    if (firstChild == null) {
      assert(lastChild == null);
      firstChild = node;
      lastChild = node;
      return node;
    }

    lastChild.nextSibling = node;
    node.previousSibling = lastChild;
    lastChild = node;
    return node;
  }
}

class Element extends ParentNode {
  Element() : super();

  void addEventListener(String type, EventListener listener, [bool useCapture = false]) {}

  void setAttribute(String name, [String value]) {}
}

class Document extends ParentNode {
  Document();
  Element createElement(String tagName) {
    return new Element();
  }
}

class Event {
  Event();
}

typedef EventListener(Event event);

Document document = new Document();

