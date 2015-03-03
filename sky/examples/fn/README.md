FN (better name pending)
===

FN is a prototype of a functional-reactive framework for sky which takes inspiration from ReactJS. The code as you see it here is a first-draft, is unreviewed and untested. It is a proof of concept.

FN is comprised of three main parts: a virtual-dom and diffing engine, a component mechanism and a very early set of widgets for use in creating applications.

Hello World
-----------

To build an application, create a subclass of App and instantiate it.

```HTML
<!-- In hello.sky -->
<script>
import 'helloworld.dart';

main() {
  new HelloWorldApp();
}
</script>
```

```JavaScript
// In helloworld.dart
import '../fn/lib/fn.dart';

class HelloWorldApp extends App {
  Node render() {
    return new Text('Hello, World!');
  }
}
```
An app is comprised of (and is itself) a component. A component's main job is to implement `Node render()`. The idea here is that the `render` method describes the DOM of a component at all times through the lifetime of the app. In this case, our `HelloWorldApp`'s `render` method just returns a `Text` node which prints the customary line of text.

Nodes
-----
A component's `render` method must return a single `Node` which *may* have children (and so on, forming a *subtree*). FN comes with a few built-in nodes which mirror the built-in nodes/elements of sky: `Text`, 'Anchor', 'Image' and `Container` (think `div`). `render` can return a tree of Nodes comprised of any of the preceeding or four nodes or other components.


