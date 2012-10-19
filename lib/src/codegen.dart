// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/** Collects common snippets of generated code. */
library codegen;

import 'info.dart';

/** Header with common imports, used in every generated .dart file. */
String header(String filename, String libraryName) => """
// Auto-generated from $filename.
// DO NOT EDIT.

library $libraryName;

$imports
""";

String get imports => """
import 'dart:html' as autogenerated;
import 'package:web_components/watcher.dart' as autogenerated;
""";

/** The code in .dart files generated for a web component. */
// TODO(sigmund): omit [_root] if the user already defined it.
String componentCode(
    String className,
    String extraFields,
    String createdBody,
    String insertedBody,
    String removedBody) => """
  /** Autogenerated from the template. */

  /**
   * Shadow root for this component. We use 'var' to allow simulating shadow DOM
   * on browsers that don't support this feature.
   */
  var _root;
$extraFields

  $className.forElement(e) : super.forElement(e) {
     _root = createShadowRoot();
  }

  void created_autogenerated() {
$createdBody
  }

  void inserted_autogenerated() {
$insertedBody
  }

  void removed_autogenerated() {
$removedBody
  }

  /** Original code from the component. */
""";

// TODO(jmesserly): is raw triple quote enough to escape the HTML?
/**
 * Top-level initialization code. This is the bulk of the code in the
 * main.html.dart generated file if the user inlined his code in the page, or
 * code appended to the main entry point .dart file, if the user specified an
 * enternal file in the top-level script tag.
 */
String mainDartCode(
    String originalCode,
    String topLevelFields,
    String fieldInitializers,
    String modelBinding,
    String initialPage) => """

// Original code
$originalCode

// Additional generated code

$topLevelFields

/** Create the views and bind them to models. */
void init_autogenerated() {
  // Create view.
  var _root = new autogenerated.DocumentFragment.html(_INITIAL_PAGE);

  // Initialize fields.
$fieldInitializers
  // Attach model to views.
$modelBinding

  // Attach view to the document.
  autogenerated.document.body.nodes.add(_root);
}

final String _INITIAL_PAGE = r'''
  $initialPage
''';
""";

/**
 * The code that will be used to bootstrap the application, this is inlined in
 * the main.html.html output file.
 */
String bootstrapCode(String userMainImport) => """
library bootstrap;

import '$userMainImport' as userMain;

main() {
  userMain.main();
  userMain.init_autogenerated();
}
""";

/** Generate text for a list of imports. */
String importList(List<String> imports) =>
  Strings.join(imports.map((url) => "import '$url';"), '\n');

/** Generate text for a list of export. */
String exportList(List<String> exports) =>
  Strings.join(exports.map((url) => "export '$url';"), '\n');
