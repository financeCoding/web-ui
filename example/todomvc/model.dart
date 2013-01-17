// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library model;
import 'dart:html';
import 'package:objectory/objectory_browser.dart';
import 'package:web_ui/watcher.dart';

class ViewModel {
  bool isVisible(Todo todo) => todo != null &&
      ((showIncomplete && !todo.done) || (showDone && todo.done));

  bool showIncomplete = true;

  bool showDone = true;
}

final ViewModel viewModel = new ViewModel();

// The real model:

class AppModel {
  List todos = [];

  resetTodos(List value) {
    todos = value;
    dispatch();
  }

  // TODO(jmesserly): remove this once List has a remove method.
  void removeTodo(Todo todo) {
    var index = todos.indexOf(todo);
    if (index != -1) {
      todos.removeRange(index, 1);
    }
  }

  bool get allChecked => todos.length > 0 && todos.every((t) => t.done);

  set allChecked(bool value) => todos.forEach((t) { t.done = value; });

  int get doneCount {
    int res = 0;
    todos.forEach((t) { if (t.done) res++; });
    return res;
  }

  int get remaining => todos.length - doneCount;

  void clearDone() {
    todos = todos.where((t) => !t.done).toList();
  }
}

ObjectoryQueryBuilder get $Todo => new ObjectoryQueryBuilder('Todo');

var DefaultUri = window.location.host;

//final AppModel app = new AppModel();
AppModel _app;
AppModel get app {
  if (_app == null) {
    _app = new AppModel();
     objectory = new ObjectoryWebsocketBrowserImpl(DefaultUri, () =>
         objectory.registerClass('Todo',()=>new Todo('')), false); // set to true to drop models
     objectory.initDomainModel().then((_) {
       objectory.find($Todo).then((todos) {
         app.resetTodos(todos);
       });
     });
  }
  return _app;
}


class Todo extends PersistentObject {
//  String task;
//  bool done = false;

  String get task => getProperty('task');
  set task(String value) => setProperty('task',value);

  bool get done => getProperty('done');
  set done(bool value) => setProperty('done',value);


  //Todo(this.task);
  Todo(String newTask) {
    done = false;
    task = newTask;
    saveOnUpdate = true;
  }

  String toString() => "$task ${done ? '(done)' : '(not done)'}";
}
