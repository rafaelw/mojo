/*
 * Copyright (C) 1999 Lars Knoll (knoll@kde.org)
 *           (C) 1999 Antti Koivisto (koivisto@kde.org)
 *           (C) 2001 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2004, 2005, 2006, 2007, 2008, 2009, 2013 Apple Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#include "sky/engine/config.h"
#include "sky/engine/core/dom/ContainerNode.h"

#include "sky/engine/bindings/exception_state.h"
#include "sky/engine/core/dom/ChildListMutationScope.h"
#include "sky/engine/core/dom/ElementTraversal.h"
#include "sky/engine/core/dom/ExceptionCode.h"
#include "sky/engine/core/dom/NodeRareData.h"
#include "sky/engine/core/dom/NodeRenderStyle.h"
#include "sky/engine/core/dom/NodeTraversal.h"
#include "sky/engine/core/dom/SelectorQuery.h"
#include "sky/engine/core/dom/StaticNodeList.h"
#include "sky/engine/core/dom/StyleEngine.h"
#include "sky/engine/core/dom/shadow/ElementShadow.h"
#include "sky/engine/core/dom/shadow/ShadowRoot.h"
#include "sky/engine/core/rendering/InlineTextBox.h"
#include "sky/engine/core/rendering/RenderText.h"
#include "sky/engine/core/rendering/RenderView.h"
#include "sky/engine/platform/EventDispatchForbiddenScope.h"
#include "sky/engine/platform/ScriptForbiddenScope.h"

namespace blink {

#if ENABLE(ASSERT)
unsigned EventDispatchForbiddenScope::s_count = 0;
#endif

static void collectChildrenAndRemoveFromOldParent(Node& node, NodeVector& nodes, ExceptionState& exceptionState)
{
    if (node.isDocumentFragment()) {
        DocumentFragment& fragment = toDocumentFragment(node);
        appendChildNodes(fragment, nodes);
        fragment.removeChildren();
        return;
    }
    nodes.append(&node);
    if (ContainerNode* oldParent = node.parentNode())
        oldParent->removeChild(&node, exceptionState);
}

void ContainerNode::removeDetachedChildren()
{
    ASSERT(needsAttach());
    removeDetachedChildrenInContainer(*this);
}

ContainerNode::~ContainerNode()
{
    ASSERT(needsAttach());
    willBeDeletedFromDocument();
    removeDetachedChildren();
}

bool ContainerNode::containsConsideringHostElements(const Node& newChild) const
{
    if (isInShadowTree() || document().isTemplateDocument())
        return newChild.containsIncludingHostElements(*this);
    return newChild.contains(this);
}

void ContainerNode::checkAcceptChildType(const Node* newChild, ExceptionState& exceptionState) const
{
    if (!newChild) {
        exceptionState.ThrowDOMException(NotFoundError, "The new child element is null.");
        return;
    }

    if (newChild->isTreeScope()) {
        exceptionState.ThrowDOMException(HierarchyRequestError, "Nodes of type '" + newChild->nodeName() + "' may not be inserted inside nodes of type '" + nodeName() + "'.");
        return;
    }
}

void ContainerNode::checkAcceptChildHierarchy(const Node& newChild, const Node* oldChild, ExceptionState& exceptionState) const
{
    if (containsConsideringHostElements(newChild)) {
        exceptionState.ThrowDOMException(HierarchyRequestError, "The new child element contains the parent.");
        return;
    }
}

PassRefPtr<Node> ContainerNode::insertBefore(PassRefPtr<Node> newChild, Node* refChild, ExceptionState& exceptionState)
{
    // Check that this node is not "floating".
    // If it is, it can be deleted as a side effect of sending mutation events.
    ASSERT(refCount() || parentOrShadowHostNode());

    RefPtr<Node> protect(this);

    // insertBefore(node, 0) is equivalent to appendChild(node)
    if (!refChild) {
        return appendChild(newChild, exceptionState);
    }

    checkAcceptChildType(newChild.get(), exceptionState);
    if (exceptionState.had_exception())
        return nullptr;

    checkAcceptChildHierarchy(*newChild, 0, exceptionState);
    if (exceptionState.had_exception())
        return nullptr;

    ASSERT(newChild);

    // NotFoundError: Raised if refChild is not a child of this node
    if (refChild->parentNode() != this) {
        exceptionState.ThrowDOMException(NotFoundError, "The node before which the new node is to be inserted is not a child of this node.");
        return nullptr;
    }

    // nothing to do
    if (refChild->previousSibling() == newChild || refChild == newChild)
        return newChild;

    RefPtr<Node> next = refChild;

    NodeVector targets;
    collectChildrenAndRemoveFromOldParent(*newChild, targets, exceptionState);
    if (exceptionState.had_exception())
        return nullptr;
    if (targets.isEmpty())
        return newChild;

    // Must check this again beacuse focus events might run synchronously when
    // removing children.
    checkAcceptChildHierarchy(*newChild, 0, exceptionState);
    if (exceptionState.had_exception())
        return nullptr;

    ChildListMutationScope mutation(*this);
    for (NodeVector::const_iterator it = targets.begin(); it != targets.end(); ++it) {
        ASSERT(*it);
        Node& child = **it;

        // Due to arbitrary code running in response to a DOM mutation event it's
        // possible that "next" is no longer a child of "this".
        // It's also possible that "child" has been inserted elsewhere.
        // In either of those cases, we'll just stop.
        if (next->parentNode() != this)
            break;
        if (child.parentNode())
            break;

        treeScope().adoptIfNeeded(child);

        insertBeforeCommon(*next, child);

        updateTreeAfterInsertion(child);
    }

    return newChild;
}

void ContainerNode::insertBeforeCommon(Node& nextChild, Node& newChild)
{
    EventDispatchForbiddenScope assertNoEventDispatch;
    ScriptForbiddenScope forbidScript;

    ASSERT(!newChild.parentNode()); // Use insertBefore if you need to handle reparenting (and want DOM mutation events).
    ASSERT(!newChild.nextSibling());
    ASSERT(!newChild.previousSibling());
    ASSERT(!newChild.isShadowRoot());

    Node* prev = nextChild.previousSibling();
    ASSERT(m_lastChild != prev);
    nextChild.setPreviousSibling(&newChild);
    if (prev) {
        ASSERT(firstChild() != nextChild);
        ASSERT(prev->nextSibling() == nextChild);
        prev->setNextSibling(&newChild);
    } else {
        ASSERT(firstChild() == nextChild);
        m_firstChild = &newChild;
    }
    newChild.setParentOrShadowHostNode(this);
    newChild.setPreviousSibling(prev);
    newChild.setNextSibling(&nextChild);
}

void ContainerNode::appendChildCommon(Node& child)
{
    child.setParentOrShadowHostNode(this);

    if (m_lastChild) {
        child.setPreviousSibling(m_lastChild);
        m_lastChild->setNextSibling(&child);
    } else {
        setFirstChild(&child);
    }

    setLastChild(&child);
}

PassRefPtr<Node> ContainerNode::replaceChild(PassRefPtr<Node> newChild, PassRefPtr<Node> oldChild, ExceptionState& exceptionState)
{
    // Check that this node is not "floating".
    // If it is, it can be deleted as a side effect of sending mutation events.
    ASSERT(refCount() || parentOrShadowHostNode());

    RefPtr<Node> protect(this);

    if (oldChild == newChild) // nothing to do
        return oldChild;

    if (!oldChild) {
        exceptionState.ThrowDOMException(NotFoundError, "The node to be replaced is null.");
        return nullptr;
    }

    RefPtr<Node> child = oldChild;

    checkAcceptChildType(newChild.get(), exceptionState);
    if (exceptionState.had_exception())
        return nullptr;

    checkAcceptChildHierarchy(*newChild, child.get(), exceptionState);
    if (exceptionState.had_exception())
        return nullptr;

    // NotFoundError: Raised if oldChild is not a child of this node.
    if (child->parentNode() != this) {
        exceptionState.ThrowDOMException(NotFoundError, "The node to be replaced is not a child of this node.");
        return nullptr;
    }

    ChildListMutationScope mutation(*this);

    RefPtr<Node> next = child->nextSibling();

    // Remove the node we're replacing
    removeChild(child, exceptionState);
    if (exceptionState.had_exception())
        return nullptr;

    if (next && (next->previousSibling() == newChild || next == newChild)) // nothing to do
        return child;

    NodeVector targets;
    collectChildrenAndRemoveFromOldParent(*newChild, targets, exceptionState);
    if (exceptionState.had_exception())
        return nullptr;

    // Must check this again beacuse focus events might run synchronously when
    // removing children.
    checkAcceptChildHierarchy(*newChild, child.get(),exceptionState);
    if (exceptionState.had_exception())
        return nullptr;

    // Add the new child(ren)
    for (NodeVector::const_iterator it = targets.begin(); it != targets.end(); ++it) {
        ASSERT(*it);
        Node& child = **it;

        // Due to arbitrary code running in response to a DOM mutation event it's
        // possible that "next" is no longer a child of "this".
        // It's also possible that "child" has been inserted elsewhere.
        // In either of those cases, we'll just stop.
        if (next && next->parentNode() != this)
            break;
        if (child.parentNode())
            break;

        treeScope().adoptIfNeeded(child);

        // Add child before "next".
        {
            EventDispatchForbiddenScope assertNoEventDispatch;
            if (next)
                insertBeforeCommon(*next, child);
            else
                appendChildCommon(child);
        }

        updateTreeAfterInsertion(child);
    }

    return child;
}

void ContainerNode::willRemoveChild(Node& child)
{
    ASSERT(child.parentNode() == this);
    ChildListMutationScope(*this).willRemoveChild(child);
    child.notifyMutationObserversNodeWillDetach();
    document().nodeWillBeRemoved(child); // e.g. mutation event listener can create a new range.
}

void ContainerNode::willRemoveChildren()
{
    NodeVector children;
    appendChildNodes(*this, children);

    ChildListMutationScope mutation(*this);
    for (NodeVector::const_iterator it = children.begin(); it != children.end(); ++it) {
        ASSERT(*it);
        Node& child = **it;
        mutation.willRemoveChild(child);
        child.notifyMutationObserversNodeWillDetach();
    }
}

void ContainerNode::removeDetachedChildrenInContainer(ContainerNode& container)
{
    // List of nodes to be deleted.
    Node* head = 0;
    Node* tail = 0;

    addChildNodesToDeletionQueue(head, tail, container);

    Node* n;
    Node* next;
    while ((n = head) != 0) {
        ASSERT_WITH_SECURITY_IMPLICATION(n->m_deletionHasBegun);

        next = n->nextSibling();
        n->setNextSibling(0);

        head = next;
        if (next == 0)
            tail = 0;

        if (n->hasChildren())
            addChildNodesToDeletionQueue(head, tail, toContainerNode(*n));

        delete n;
    }
}

void ContainerNode::addChildNodesToDeletionQueue(Node*& head, Node*& tail, ContainerNode& container)
{
    // We have to tell all children that their parent has died.
    Node* next = 0;
    for (Node* n = container.firstChild(); n; n = next) {
        ASSERT_WITH_SECURITY_IMPLICATION(!n->m_deletionHasBegun);

        next = n->nextSibling();
        n->setNextSibling(0);
        n->setParentOrShadowHostNode(0);
        container.setFirstChild(next);
        if (next)
            next->setPreviousSibling(0);

        if (!n->refCount()) {
#if ENABLE(SECURITY_ASSERT)
            n->m_deletionHasBegun = true;
#endif
            // Add the node to the list of nodes to be deleted.
            // Reuse the nextSibling pointer for this purpose.
            if (tail)
                tail->setNextSibling(n);
            else
                head = n;

            tail = n;
        } else {
            RefPtr<Node> protect(n); // removedFromDocument may remove all references to this node.
            container.document().adoptIfNeeded(*n);
            if (n->inDocument())
                container.notifyNodeRemoved(*n);
        }
    }

    container.setLastChild(0);
}

PassRefPtr<Node> ContainerNode::removeChild(PassRefPtr<Node> oldChild, ExceptionState& exceptionState)
{
    // Check that this node is not "floating".
    // If it is, it can be deleted as a side effect of sending mutation events.
    ASSERT(refCount() || parentOrShadowHostNode());

    RefPtr<Node> protect(this);
    RefPtr<Node> child = oldChild;

    document().removeFocusedElementOfSubtree(child.get());

    // Events fired when blurring currently focused node might have moved this
    // child into a different parent.
    if (child->parentNode() != this) {
        exceptionState.ThrowDOMException(NotFoundError, "The node to be removed is no longer a child of this node. Perhaps it was moved in a 'blur' event handler?");
        return nullptr;
    }

    willRemoveChild(*child);

    // Mutation events might have moved this child into a different parent.
    if (child->parentNode() != this) {
        exceptionState.ThrowDOMException(NotFoundError, "The node to be removed is no longer a child of this node. Perhaps it was moved in response to a mutation?");
        return nullptr;
    }

    Node* prev = child->previousSibling();
    Node* next = child->nextSibling();
    removeBetween(prev, next, *child);
    notifyNodeRemoved(*child);
    childrenChanged(ChildrenChange::forRemoval(*child, ChildrenChangeSourceAPI));

    return child;
}

void ContainerNode::removeBetween(Node* previousChild, Node* nextChild, Node& oldChild)
{
    EventDispatchForbiddenScope assertNoEventDispatch;

    ASSERT(oldChild.parentNode() == this);

    if (!oldChild.needsAttach())
        oldChild.detach();

    if (nextChild)
        nextChild->setPreviousSibling(previousChild);
    if (previousChild)
        previousChild->setNextSibling(nextChild);
    if (m_firstChild == &oldChild)
        m_firstChild = nextChild;
    if (m_lastChild == &oldChild)
        m_lastChild = previousChild;

    oldChild.setPreviousSibling(0);
    oldChild.setNextSibling(0);
    oldChild.setParentOrShadowHostNode(0);

    document().adoptIfNeeded(oldChild);
}

// this differs from other remove functions because it forcibly removes all the children,
// regardless of read-only status or event exceptions, e.g.
void ContainerNode::removeChildren()
{
    if (!m_firstChild)
        return;

    // The container node can be removed from event handlers.
    RefPtr<ContainerNode> protect(this);

    // Do any prep work needed before actually starting to detach
    // and remove... e.g. stop loading frames, fire unload events.
    willRemoveChildren();

    {
        // Exclude this node when looking for removed focusedElement since only
        // children will be removed.
        // This must be later than willRemoveChildren, which might change focus
        // state of a child.
        document().removeFocusedElementOfSubtree(this, true);

        // Removing a node from a selection can cause widget updates.
        document().nodeChildrenWillBeRemoved(*this);
    }

    // FIXME: Remove this NodeVector. Right now WebPluginContainerImpl::m_element is a
    // raw ptr which means the code below can drop the last ref to a plugin element and
    // then the code in UpdateSuspendScope::performDeferredWidgetTreeOperations will
    // try to destroy the plugin which will be a use-after-free. We should use a RefPtr
    // in the WebPluginContainerImpl instead.
    NodeVector removedChildren;
    {
        EventDispatchForbiddenScope assertNoEventDispatch;
        ScriptForbiddenScope forbidScript;

        removedChildren.reserveInitialCapacity(countChildren());

        while (RefPtr<Node> child = m_firstChild) {
            removeBetween(0, child->nextSibling(), *child);
            removedChildren.append(child.get());
            notifyNodeRemoved(*child);
        }

        ChildrenChange change = {AllChildrenRemoved, ChildrenChangeSourceAPI};
        childrenChanged(change);
    }
}

PassRefPtr<Node> ContainerNode::appendChild(PassRefPtr<Node> newChild, ExceptionState& exceptionState)
{
    RefPtr<ContainerNode> protect(this);

    // Check that this node is not "floating".
    // If it is, it can be deleted as a side effect of sending mutation events.
    ASSERT(refCount() || parentOrShadowHostNode());

    checkAcceptChildType(newChild.get(), exceptionState);
    if (exceptionState.had_exception())
        return nullptr;

    checkAcceptChildHierarchy(*newChild, 0, exceptionState);
    if (exceptionState.had_exception())
        return nullptr;

    ASSERT(newChild);

    if (newChild == m_lastChild) // nothing to do
        return newChild;

    NodeVector targets;
    collectChildrenAndRemoveFromOldParent(*newChild, targets, exceptionState);
    if (exceptionState.had_exception())
        return nullptr;

    if (targets.isEmpty())
        return newChild;

    // Must check this again beacuse focus events might run synchronously when
    // removing children.
    checkAcceptChildHierarchy(*newChild, 0, exceptionState);
    if (exceptionState.had_exception())
        return nullptr;

    // Now actually add the child(ren)
    ChildListMutationScope mutation(*this);
    for (NodeVector::const_iterator it = targets.begin(); it != targets.end(); ++it) {
        ASSERT(*it);
        Node& child = **it;

        // If the child has a parent again, just stop what we're doing, because
        // that means someone is doing something with DOM mutation -- can't re-parent
        // a child that already has a parent.
        if (child.parentNode())
            break;

        {
            EventDispatchForbiddenScope assertNoEventDispatch;
            ScriptForbiddenScope forbidScript;

            treeScope().adoptIfNeeded(child);
            appendChildCommon(child);
        }

        updateTreeAfterInsertion(child);
    }

    return newChild;
}

void ContainerNode::parserAppendChild(PassRefPtr<Node> newChild)
{
    ASSERT(newChild);
    ASSERT(!newChild->parentNode()); // Use appendChild if you need to handle reparenting (and want DOM mutation events).
    ASSERT(!newChild->isDocumentFragment());
    ASSERT(!isHTMLTemplateElement(this));

    RefPtr<Node> protect(this);

    if (document() != newChild->document())
        document().adoptNode(newChild.get(), ASSERT_NO_EXCEPTION);

    {
        EventDispatchForbiddenScope assertNoEventDispatch;
        ScriptForbiddenScope forbidScript;

        treeScope().adoptIfNeeded(*newChild);
        appendChildCommon(*newChild);
        ChildListMutationScope(*this).childAdded(*newChild);
    }

    notifyNodeInserted(*newChild, ChildrenChangeSourceParser);
}

void ContainerNode::notifyNodeInserted(Node& root, ChildrenChangeSource source)
{
    ASSERT(!EventDispatchForbiddenScope::isEventDispatchForbidden());
    ASSERT(!root.isShadowRoot());

    RefPtr<Node> protect(this);
    RefPtr<Node> protectNode(root);

    notifyNodeInsertedInternal(root);

    childrenChanged(ChildrenChange::forInsertion(root, source));
}

void ContainerNode::notifyNodeInsertedInternal(Node& root)
{
    EventDispatchForbiddenScope assertNoEventDispatch;
    ScriptForbiddenScope forbidScript;

    for (Node* node = &root; node; node = NodeTraversal::next(*node, &root)) {
        // As an optimization we don't notify leaf nodes when when inserting
        // into detached subtrees.
        if (!inDocument() && !node->isContainerNode())
            continue;
        node->insertedInto(this);
        if (ShadowRoot* shadowRoot = node->shadowRoot())
            notifyNodeInsertedInternal(*shadowRoot);
    }
}

void ContainerNode::notifyNodeRemoved(Node& root)
{
    ScriptForbiddenScope forbidScript;
    EventDispatchForbiddenScope assertNoEventDispatch;

    for (Node* node = &root; node; node = NodeTraversal::next(*node, &root)) {
        // As an optimization we skip notifying Text nodes and other leaf nodes
        // of removal when they're not in the Document tree since the virtual
        // call to removedFrom is not needed.
        if (!node->inDocument() && !node->isContainerNode())
            continue;
        node->removedFrom(this);
        if (ShadowRoot* shadowRoot = node->shadowRoot())
            notifyNodeRemoved(*shadowRoot);
    }
}

void ContainerNode::attach(const AttachContext& context)
{
    attachChildren(context);
    clearChildNeedsStyleRecalc();
    Node::attach(context);
}

void ContainerNode::detach(const AttachContext& context)
{
    detachChildren(context);
    clearChildNeedsStyleRecalc();
    Node::detach(context);
}

void ContainerNode::childrenChanged(const ChildrenChange& change)
{
    if (!change.byParser && change.type != TextChanged)
        document().updateRangesAfterChildrenChanged(this);
    if (change.isChildInsertion() && !childNeedsStyleRecalc()) {
        setChildNeedsStyleRecalc();
        markAncestorsWithChildNeedsStyleRecalc();
    }
}

void ContainerNode::cloneChildNodes(ContainerNode *clone)
{
    TrackExceptionState exceptionState;
    for (Node* n = firstChild(); n && !exceptionState.had_exception(); n = n->nextSibling())
        clone->appendChild(n->cloneNode(true), exceptionState);
}


bool ContainerNode::getUpperLeftCorner(FloatPoint& point) const
{
    if (!renderer())
        return false;
    // What is this code really trying to do?
    RenderObject* o = renderer();

    if (!o->isInline() || o->isReplaced()) {
        point = o->localToAbsolute(FloatPoint(), UseTransforms);
        return true;
    }

    // find the next text/image child, to get a position
    while (o) {
        RenderObject* p = o;
        if (RenderObject* oFirstChild = o->slowFirstChild()) {
            o = oFirstChild;
        } else if (o->nextSibling()) {
            o = o->nextSibling();
        } else {
            RenderObject* next = 0;
            while (!next && o->parent()) {
                o = o->parent();
                next = o->nextSibling();
            }
            o = next;

            if (!o)
                break;
        }
        ASSERT(o);

        if (!o->isInline() || o->isReplaced()) {
            point = o->localToAbsolute(FloatPoint(), UseTransforms);
            return true;
        }

        if (p->node() && p->node() == this && o->isText() && !toRenderText(o)->firstTextBox()) {
            // do nothing - skip unrendered whitespace that is a child or next sibling of the anchor
        } else if (o->isText() || o->isReplaced()) {
            point = FloatPoint();
            if (o->isText() && toRenderText(o)->firstTextBox()) {
                point.move(toRenderText(o)->linesBoundingBox().x(), toRenderText(o)->firstTextBox()->root().lineTop().toFloat());
            } else if (o->isBox()) {
                RenderBox* box = toRenderBox(o);
                point.moveBy(box->location());
            }
            point = o->container()->localToAbsolute(point, UseTransforms);
            return true;
        }
    }

    // If the target doesn't have any children or siblings that could be used to calculate the scroll position, we must be
    // at the end of the document. Scroll to the bottom. FIXME: who said anything about scrolling?
    if (!o && document().view()) {
        point = FloatPoint(0, document().view()->height());
        return true;
    }
    return false;
}

bool ContainerNode::getLowerRightCorner(FloatPoint& point) const
{
    if (!renderer())
        return false;

    RenderObject* o = renderer();
    if (!o->isInline() || o->isReplaced()) {
        RenderBox* box = toRenderBox(o);
        point = o->localToAbsolute(LayoutPoint(box->size()), UseTransforms);
        return true;
    }

    // find the last text/image child, to get a position
    while (o) {
        if (RenderObject* oLastChild = o->slowLastChild()) {
            o = oLastChild;
        } else if (o->previousSibling()) {
            o = o->previousSibling();
        } else {
            RenderObject* prev = 0;
        while (!prev) {
            o = o->parent();
            if (!o)
                return false;
            prev = o->previousSibling();
        }
        o = prev;
        }
        ASSERT(o);
        if (o->isText() || o->isReplaced()) {
            point = FloatPoint();
            if (o->isText()) {
                RenderText* text = toRenderText(o);
                IntRect linesBox = text->linesBoundingBox();
                if (!linesBox.maxX() && !linesBox.maxY())
                    continue;
                point.moveBy(linesBox.maxXMaxYCorner());
            } else {
                RenderBox* box = toRenderBox(o);
                point.moveBy(box->frameRect().maxXMaxYCorner());
            }
            point = o->container()->localToAbsolute(point, UseTransforms);
            return true;
        }
    }
    return true;
}

// FIXME: This override is only needed for inline anchors without an
// InlineBox and it does not belong in ContainerNode as it reaches into
// the render and line box trees.
// https://code.google.com/p/chromium/issues/detail?id=248354
LayoutRect ContainerNode::boundingBox() const
{
    FloatPoint upperLeft, lowerRight;
    bool foundUpperLeft = getUpperLeftCorner(upperLeft);
    bool foundLowerRight = getLowerRightCorner(lowerRight);

    // If we've found one corner, but not the other,
    // then we should just return a point at the corner that we did find.
    if (foundUpperLeft != foundLowerRight) {
        if (foundUpperLeft)
            lowerRight = upperLeft;
        else
            upperLeft = lowerRight;
    }

    return enclosingLayoutRect(FloatRect(upperLeft, lowerRight.expandedTo(upperLeft) - upperLeft));
}

// This is used by FrameSelection to denote when the active-state of the page has changed
// independent of the focused element changing.
void ContainerNode::focusStateChanged()
{
    // If we're just changing the window's active state and the focused node has no
    // renderer we can just ignore the state change.
    if (!renderer())
        return;

    if (styleChangeType() < SubtreeStyleChange) {
        if (renderStyle()->affectedByFocus())
            setNeedsStyleRecalc(LocalStyleChange);
    }
}

void ContainerNode::setFocus(bool received)
{
    if (focused() == received)
        return;

    Node::setFocus(received);

    focusStateChanged();

    if (renderer() || received)
        return;

    setNeedsStyleRecalc(LocalStyleChange);
}

void ContainerNode::setActive(bool down)
{
    if (down == active())
        return;

    Node::setActive(down);

    // FIXME: Why does this not need to handle the display: none transition like :hover does?
    if (renderer()) {
        if (styleChangeType() < SubtreeStyleChange) {
            if (renderStyle()->affectedByActive())
                setNeedsStyleRecalc(LocalStyleChange);
        }
    }
}

void ContainerNode::setHovered(bool over)
{
    if (over == hovered())
        return;

    Node::setHovered(over);

    // If :hover sets display: none we lose our hover but still need to recalc our style.
    if (!renderer()) {
        if (over)
            return;
        setNeedsStyleRecalc(LocalStyleChange);
        return;
    }

    if (styleChangeType() < SubtreeStyleChange) {
        if (renderStyle()->affectedByHover())
            setNeedsStyleRecalc(LocalStyleChange);
    }
}

Element* ContainerNode::firstElementChild() const
{
    return ElementTraversal::firstChild(*this);
}

Element* ContainerNode::lastElementChild() const
{
    return ElementTraversal::lastChild(*this);
}

Vector<RefPtr<Node>> ContainerNode::getChildNodes() const
{
    Vector<RefPtr<Node>> result;
    for (Node* node = firstChild(); node; node = node->nextSibling())
        result.append(node);
    return result;
}

Vector<RefPtr<Element>> ContainerNode::getChildElements() const
{
    Vector<RefPtr<Element>> result;
    for (Element* element = ElementTraversal::firstWithin(*this); element; element = ElementTraversal::next(*element, this))
        result.append(element);
    return result;
}

void ContainerNode::append(Vector<RefPtr<Node>>& nodes, ExceptionState& es)
{
    RefPtr<ContainerNode> protect(this);
    for (auto& node : nodes) {
        appendChild(node.release(), es);
        if (es.had_exception())
            return;
    }
}

void ContainerNode::prepend(Vector<RefPtr<Node>>& nodes, ExceptionState& es)
{
    RefPtr<ContainerNode> protect(this);
    RefPtr<Node> refChild = m_firstChild;
    for (auto& node : nodes) {
        insertBefore(node.release(), refChild.get(), es);
        if (es.had_exception())
            return;
    }
}

PassRefPtr<Node> ContainerNode::prependChild(PassRefPtr<Node> node, ExceptionState& es)
{
    return insertBefore(node, m_firstChild, es);
}

PassRefPtr<Node> ContainerNode::setChild(PassRefPtr<Node> node, ExceptionState& es)
{
    RefPtr<ContainerNode> protect(this);
    removeChildren();
    return appendChild(node, es);
}

void ContainerNode::setChildren(Vector<RefPtr<Node>>& nodes, ExceptionState& es)
{
    RefPtr<ContainerNode> protect(this);
    removeChildren();
    append(nodes, es);
}

unsigned ContainerNode::countChildren() const
{
    unsigned count = 0;
    Node *n;
    for (n = firstChild(); n; n = n->nextSibling())
        count++;
    return count;
}

PassRefPtr<Element> ContainerNode::querySelector(const AtomicString& selectors, ExceptionState& exceptionState)
{
    if (selectors.isEmpty()) {
        exceptionState.ThrowDOMException(SyntaxError, "The provided selector is empty.");
        return nullptr;
    }

    SelectorQuery* selectorQuery = document().selectorQueryCache().add(selectors, document(), exceptionState);
    if (!selectorQuery)
        return nullptr;
    return selectorQuery->queryFirst(*this);
}

PassRefPtr<StaticElementList> ContainerNode::querySelectorAll(const AtomicString& selectors, ExceptionState& exceptionState)
{
    if (selectors.isEmpty()) {
        exceptionState.ThrowDOMException(SyntaxError, "The provided selector is empty.");
        return nullptr;
    }

    SelectorQuery* selectorQuery = document().selectorQueryCache().add(selectors, document(), exceptionState);
    if (!selectorQuery)
        return nullptr;

    return selectorQuery->queryAll(*this);
}

void ContainerNode::updateTreeAfterInsertion(Node& child)
{
    ASSERT(refCount());
    ASSERT(child.refCount());

    ChildListMutationScope(*this).childAdded(child);

    notifyNodeInserted(child);
}

Element* ContainerNode::getElementById(const AtomicString& id) const
{
    if (isInTreeScope()) {
        // Fast path if we are in a tree scope: call getElementById() on tree scope
        // and check if the matching element is in our subtree.
        Element* element = treeScope().getElementById(id);
        if (!element)
            return 0;
        if (element->isDescendantOf(this))
            return element;
    }

    // Fall back to traversing our subtree. In case of duplicate ids, the first element found will be returned.
    for (Element* element = ElementTraversal::firstWithin(*this); element; element = ElementTraversal::next(*element, this)) {
        if (element->getIdAttribute() == id)
            return element;
    }
    return 0;
}

#if ENABLE(ASSERT)
bool childAttachedAllowedWhenAttachingChildren(ContainerNode* node)
{
    if (node->isShadowRoot())
        return true;

    if (node->isInsertionPoint())
        return true;

    if (node->isElementNode() && toElement(node)->shadow())
        return true;

    return false;
}
#endif

} // namespace blink
