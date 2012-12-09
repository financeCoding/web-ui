library dart2js_builder;

import 'dart:io' as io;
import 'dart:collection' show SplayTreeMap;
import 'package:html5lib/dom.dart';
import 'package:html5lib/parser.dart';
import 'file_system.dart';
import 'file_system/path.dart';
import 'files.dart';
import 'info.dart';
import 'messages.dart';
import 'options.dart';

class Dart2jsBuilder {
  final String dart2js; 
  final FileSystem fileSystem;
  final CompilerOptions options;
  final Messages messages;
  Path _mainPath;
  PathInfo _pathInfo;
   
  Dart2jsBuilder(this.fileSystem, this.options, this.messages, {String currentDir: null, this.dart2js: "dart2js"}) {
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
        messages.error('internal error: could not normalize paths. Please make '
            'the input, base, and output paths all absolute or relative, or '
            'specify "currentDir" to the Compiler constructor', null);
        return;
      }
      var currentPath = new Path(currentDir);
      if (!_mainPath.isAbsolute) _mainPath = currentPath.join(_mainPath);
      if (!basePath.isAbsolute) basePath = currentPath.join(basePath);
      if (!outputPath.isAbsolute) outputPath = currentPath.join(outputPath);
    }
    _pathInfo = new PathInfo(basePath, outputPath, options.forceMangle);
  }
  
  Future<String> run() {
    Completer completer = new Completer();
    fileSystem.readText(_pathInfo.outputPath(_mainPath, ".html")).then((mainHtml) {
      var outputDir = _pathInfo.outputPath(_mainPath, ".html").directoryPath;
      Document doc = parse(mainHtml);
      var scripts = doc.body.queryAll("script");
      scripts.forEach((Element script) { 
        Map attributes = script.attributes;
        if (attributes.containsKey('type') && 
            attributes.containsValue('application/dart') && 
            attributes.containsKey('src')) {
          
          io.ProcessOptions processOptions = new io.ProcessOptions();
          processOptions.workingDirectory = outputDir.toNativePath();
          processOptions.environment = io.Platform.environment;
          var processArgs = ["--verbose", "-o${attributes['src']}.js", "${attributes['src']}"];
          
          io.Process.run(dart2js, processArgs, processOptions)
          ..handleException((error) {
            messages.error("Error building ${processOptions.workingDirectory}/${attributes['src']}.js", null);
            completer.complete("Error building ${processOptions.workingDirectory}/${attributes['src']}.js");
          })
          ..then((io.ProcessResult processResult) {
            completer.complete("Success building ${processOptions.workingDirectory}/${attributes['src']}.js");
          });
        }
      });
    }); 
    return completer.future;
  }
}
