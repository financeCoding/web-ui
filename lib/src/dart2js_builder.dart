library dart2js_builder;

import 'dart:io' as io;
import 'package:html5lib/dom.dart';
import 'package:html5lib/parser.dart';
import 'file_system.dart';
import 'file_system/path.dart';
import 'files.dart';
import 'info.dart';
import 'dart:collection' show SplayTreeMap;
import 'options.dart';

//import 'analyzer.dart';
//import 'code_printer.dart';
//import 'codegen.dart' as codegen;
//import 'directive_parser.dart' show parseDartCode;
//import 'emitters.dart';
//import 'file_system.dart';
//import 'file_system/path.dart';
//import 'files.dart';
//import 'html_cleaner.dart';
//import 'info.dart';
//import 'messages.dart';
//import 'options.dart';
//import 'utils.dart';

class Dart2jsBuilder {
  //String mainHtml;
  Path outputDir;
  String dart2js;
  
  final FileSystem fileSystem;
  final CompilerOptions options;
  final List<SourceFile> files = <SourceFile>[];
  final List<OutputFile> output = <OutputFile>[];

  Path _mainPath;
  PathInfo _pathInfo;

  /** Information about source [files] given their href. */
  final Map<Path, FileInfo> info = new SplayTreeMap<Path, FileInfo>();
  
  //Dart2jsBuilder(this.mainHtml, this.outputDir, {this.dart2js: "/Applications/dart/dart-sdk/bin/dart2js"}) {
  Dart2jsBuilder(this.fileSystem, this.options, {String currentDir: null, this.dart2js: "/Applications/dart/dart-sdk/bin/dart2js"}) {
    _mainPath = new Path(options.inputFile);
    var mainDir = _mainPath.directoryPath;
    var basePath =
        options.baseDir != null ? new Path(options.baseDir) : mainDir;
    var outputPath =
        options.outputDir != null ? new Path(options.outputDir) : mainDir;

    // Normalize paths - all should be relative or absolute paths.
    bool anyAbsolute = _mainPath.isAbsolute || basePath.isAbsolute ||
        outputPath.isAbsolute;
    bool allAbsolute = _mainPath.isAbsolute && basePath.isAbsolute &&
        outputPath.isAbsolute;
    if (anyAbsolute && !allAbsolute) {
      if (currentDir == null)  {
//        messages.error('internal error: could not normalize paths. Please make '
//            'the input, base, and output paths all absolute or relative, or '
//            'specify "currentDir" to the Compiler constructor', null);
        return;
      }
      var currentPath = new Path(currentDir);
      if (!_mainPath.isAbsolute) _mainPath = currentPath.join(_mainPath);
      if (!basePath.isAbsolute) basePath = currentPath.join(basePath);
      if (!outputPath.isAbsolute) outputPath = currentPath.join(outputPath);
    }
    _pathInfo = new PathInfo(basePath, outputPath, options.forceMangle);
  }
  
  Future run() {
    Completer c = new Completer();
    
    fileSystem.readText(_pathInfo.outputPath(_mainPath, ".html")).then((mainHtml) {
      outputDir = _pathInfo.outputPath(_mainPath, ".html").directoryPath;
      Document doc = parse(mainHtml);
      var scripts = doc.body.queryAll("script");
      scripts.forEach((Element script) { 
        Map attributes = script.attributes;
        if (attributes.containsKey('type') && 
            attributes.containsValue('application/dart') && 
            attributes.containsKey('src')) {
            io.ProcessOptions processOptions = new io.ProcessOptions();
            processOptions.workingDirectory = outputDir.toNativePath();
            processOptions.environment = new Map();
            print("processOptions.workingDirectory = ${processOptions.workingDirectory}");
            var processArgs = ["--verbose", "-o${attributes['src']}.js", "${attributes['src']}"];
            print("Starting build of ${processOptions.workingDirectory}/${attributes['src']}.js");
            io.Process.run(dart2js, processArgs, processOptions)
            ..handleException((error) {
              print("Error building ${processOptions.workingDirectory}/${attributes['src']}.js");
              print(error);
              c.complete("Error building ${processOptions.workingDirectory}/${attributes['src']}.js");
            })
            ..then((io.ProcessResult processResult) {
              print("Success building ${processOptions.workingDirectory}/${attributes['src']}.js");
              c.complete("Success building ${processOptions.workingDirectory}/${attributes['src']}.js");
            });        
        }
      });
   
    });
    return c.future;
  }
}
