// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Datatypes holding information extracted by the analyzer and used by later
 * phases of the compiler.
 */
library info;

import 'dart:coreimpl';
import 'package:html5lib/dom.dart';
import 'files.dart';
import 'utils.dart';
import 'world.dart';

/**
 * Information for any library-like input. We consider each HTML file a library,
 * and each component declaration a library as well. Hence we use this as a base
 * class for both [FileInfo] and [ComponentInfo]. Both HTML files and components
 * can have .dart code provided by the user for top-level user scripts and
 * component-level behavior code. This code can either be inlined in the HTML
 * file or included in a `<script src='url'>` tag.
 */
class LibraryInfo {

  /** Whether there is any code associated with the page/component. */
  bool get codeAttached => inlinedCode != null || externalFile != null;

  /**
   * The actual code, either inlined or from an external file, or `null` if none
   * was defined.
   */
  String get userCode {
    if (inlinedCode != null) return inlinedCode;
    if (externalCode != null) return externalCode.userCode;
    return null;
  }

  /** The inlined code, if any. */
  String inlinedCode;

  /** The name of the file sourced in a script tag, if any. */
  String externalFile;

  /** Info asscociated with [externalFile], if any. */
  FileInfo externalCode;

  /** File where the top-level code was defined. */
  abstract String get inputFilename;

  /** File that will hold any generated Dart code for this library unit. */
  abstract String get outputFilename;

  /**
   * Components used within this library unit. For [FileInfo] these are
   * components used directly in the page. For [ComponentInfo] these are
   * components used within their shadowed template.
   */
  final Map<ComponentInfo, bool> usedComponents =
      new LinkedHashMap<ComponentInfo, bool>();
}

/** Information extracted at the file-level. */
class FileInfo extends LibraryInfo {

  final String filename;

  /**
   * Whether this is the entry point of the web app, i.e. the file users
   * navigate to in their browser.
   */
  final bool isEntryPoint;

  // TODO(terry): Ensure that that the libraryName is a valid identifier:
  //              a..z || A..Z || _ [a..z || A..Z || 0..9 || _]*
  String get libraryName => filename.replaceAll('.', '_');

  /** File where the top-level code was defined. */
  String get inputFilename =>
      externalFile != null ? externalFile : file.filename;

  /** Name of the file that will hold any generated Dart code. */
  String get outputFilename =>
    '_${(externalCode != null) ? externalCode.filename : filename}.dart';

  /** Generated analysis info for all elements in the file. */
  final Map<Node, ElementInfo> elements = new Map<Node, ElementInfo>();

  /**
   * All custom element definitions in this file. This may contain duplicates.
   * Normally you should use [components] for lookup.
   */
  final List<ComponentInfo> declaredComponents = new List<ComponentInfo>();

  /**
   * All custom element definitions defined in this file or imported via
   *`<link rel='components'>` tag. Maps from the tag name to the component
   * information. This map is sorted by the tag name.
   */
  final Map<String, ComponentInfo> components =
      new SplayTreeMap<String, ComponentInfo>();

  /** Files imported with `<link rel="component">` */
  final List<String> componentLinks = <String>[];

  FileInfo([this.filename, this.isEntryPoint = false]);
}

/** Information about a web component definition. */
class ComponentInfo extends LibraryInfo {

  /** The file that declares this component. */
  final FileInfo declaringFile;

  /** The component tag name, defined with the `name` attribute on `element`. */
  final String tagName;

  /**
   * The tag name that this component extends, defined with the `extends`
   * attribute on `element`.
   */
  final String extendsTag;

  /**
   * The component info associated with the [extendsTag] name, if any.
   * This will be `null` if the component extends a built-in HTML tag, or
   * if the analyzer has not run yet.
   */
  ComponentInfo extendsComponent;

  /** The Dart class containing the component's behavior. */
  final String constructor;

  /** The declaring `<element>` tag. */
  final Node element;

  /** The component's `<template>` tag, if any. */
  final Node template;

  /** File where this component was defined. */
  String get inputFilename =>
      externalFile != null ? externalFile : declaringFile.filename;

  /**
   * Name of the file that will be generated for this component. We want to
   * generate a separate library for each component, unless their code is
   * already in an external library (e.g. [externalCode] is not null). Multiple
   * components could be defined inline within the HTML file, so we return a
   * unique file name for each component.
   */
  String get outputFilename {
    if (externalFile != null) return '_$externalFile.dart';
    var prefix = declaringFile.filename;
    var componentSegment = tagName.toLowerCase().replaceAll('-', '_');
    return '_$prefix.$componentSegment.dart';
  }

  /**
   * True if [tagName] was defined by more than one component. If this happened
   * we will skip over the component.
   */
  bool hasConflict = false;

  ComponentInfo(Element element, [this.declaringFile])
    : element = element,
      tagName = element.attributes['name'],
      extendsTag = element.attributes['extends'],
      constructor = element.attributes['constructor'],
      template = _getTemplate(element);

  static _getTemplate(element) {
    List template = element.nodes.filter((n) => n.tagName == 'template');
    return template.length == 1 ? template[0] : null;
  }
}

/** Information extracted for each node in a template. */
class ElementInfo {

  /** Id given to an element node, if any. */
  String elementId;

  /** Generated field name, if any, associated with this element. */
  // TODO(sigmund): move this to Emitter?
  String fieldName;

  /**
   * Whether code generators need to create a field to store a reference to this
   * element. This is typically true whenever we need to access the element
   * (e.g. to add event listeners, update values on data-bound watchers, etc).
   */
  bool get needsHtmlId => hasDataBinding || hasIfCondition || hasIterate
      || component != null || values.length > 0 || events.length > 0;

  /**
   * If this element is a web component instantiation (e.g. `<x-foo>`), this
   * will be set to information about the component, otherwise it will be null.
   */
  ComponentInfo component;

  /** Whether the element contains data bindings. */
  bool hasDataBinding = false;

  /** Data-bound expression used in the contents of the node. */
  String contentBinding;

  /**
   * Expression that returns the contents of the node (given it has a
   * data-bound expression in it).
   */
  // TODO(terry,sigmund): support more than 1 expression in the contents.
  String contentExpression;

  /** Generated watcher disposer that watchs for the content expression. */
  // TODO(sigmund): move somewhere else?
  String stopperName;

  // Note: we're using sorted maps so items are enumerated in a consistent order
  // between runs, resulting in less "diff" in the generated code.
  // TODO(jmesserly): An alternative approach would be to use LinkedHashMap to
  // preserve the order of the input, but we'd need to be careful about our tree
  // traversal order.

  /** Collected information for attributes, if any. */
  final Map<String, AttributeInfo> attributes =
      new SplayTreeMap<String, AttributeInfo>();

  /** Collected information for UI events on the corresponding element. */
  final Map<String, List<EventInfo>> events =
      new SplayTreeMap<String, List<EventInfo>>();

  /** Collected information about `data-value="name:value"` expressions. */
  final Map<String, String> values = new SplayTreeMap<String, String>();

  /**
   * Format [elementId] in camel case, suitable for using as a Dart identifier.
   */
  String get idAsIdentifier =>
      elementId == null ? null : '_${toCamelCase(elementId)}';

  /** Whether the template element has `iterate="... in ...". */
  bool get hasIterate => false;

  /** Whether the template element has an `instantiate="if ..."` conditional. */
  bool get hasIfCondition => false;

  String toString() => '#<ElementInfo '
      'elementId: $elementId, '
      'fieldName: $fieldName, '
      'fieldType: fieldType, '
      'needsHtmlId: $needsHtmlId, '
      'component: $component, '
      'hasIterate: $hasIterate, '
      'hasIfCondition: $hasIfCondition, '
      'hasDataBinding: $hasDataBinding, '
      'contentBinding: $contentBinding, '
      'contentExpression: $contentExpression, '
      'attributes: $attributes, '
      'idAsIdentifier: $idAsIdentifier, '
      'events: $events>';
}

/** Information extracted for each attribute in an element. */
class AttributeInfo {

  /**
   * Whether this is a `class` attribute. In which case more than one binding
   * is allowed (one per class).
   */
  bool isClass = false;

  /**
   * A value that will be monitored for changes. All attributes, except `class`,
   * have a single bound value.
   */
  String get boundValue => bindings[0];

  /** All bound values that would be monitored for changes. */
  List<String> bindings;

  AttributeInfo(String value) : bindings = [value];
  AttributeInfo.forClass(this.bindings) : isClass = true;

  String toString() => '#<AttributeInfo '
      'isClass: $isClass, values: ${Strings.join(bindings, "")}>';

  /**
   * Generated fields for watcher disposers based on the bindings of this
   * attribute.
   */
  List<String> stopperNames;
}

/** Information extracted for each declared event in an element. */
class EventInfo {
  /** Event name for attributes representing actions. */
  final String eventName;

  /** Action associated for event listener attributes. */
  final ActionDefinition action;

  /** Generated field name, if any, associated with this event. */
  String listenerField;

  EventInfo(this.eventName, this.action);

  String toString() => '#<EventInfo eventName: $eventName, action: $action>';
}

class TemplateInfo extends ElementInfo {
  /**
   * The expression that is used in `<template instantiate="if cond">
   * conditionals, or null if this there is no `instantiate="if ..."`
   * attribute.
   */
  final String ifCondition;

  /**
   * If this is a `<template iterate="item in items">`, this is the variable
   * declared on loop iterations, e.g. `item`. This will be null if it is not
   * a `<template iterate="...">`.
   */
  final String loopVariable;

  /**
   * If this is a `<template iterate="item in items">`, this is the expression
   * to get the items to iterate over, e.g. `items`. This will be null if it is
   * not a `<template iterate="...">`.
   */
  final String loopItems;

  TemplateInfo([this.ifCondition, this.loopVariable, this.loopItems]);

  bool get hasIterate => loopVariable != null;

  bool get hasIfCondition => ifCondition != null;

  String toString() => '#<TemplateInfo '
      'ifCondition: $ifCondition, '
      'loopVariable: $ifCondition, '
      'loopItems: $ifCondition>';
}


/**
 * Specifies the action to take on a particular event. Some actions need to read
 * attributes from the DOM element that has the event listener (e.g. two way
 * bindings do this). [elementVarName] stores a reference to this element, and
 * [eventArgName] stores a reference to the event parameter name.
 * They are generated outside of the analyzer (in the emitter), so they are
 * passed here as arguments.
 */
typedef String ActionDefinition(String elemVarName, String eventArgName);
