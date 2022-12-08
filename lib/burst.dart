library burst;

import 'dart:async';
import 'dart:isolate';

import 'package:thread/thread.dart';

typedef Future<void> BurstRunner();

class MultiBurst extends Burst {
  int _cursor = 0;
  List<Thread> threads;
  bool _closed = false;
  List<Future<void>> _queues = [];

  MultiBurst({int threadCount = 4})
      : threads = List.generate(
            threadCount,
            (index) => Thread((e) {
                  Burst burst = Burst();
                  e.on("q", (BurstRunner runner) {
                    burst.queue(runner);
                    e.emit("k");
                  });
                  e.on("f",
                      (data) => burst.flush().then((value) => e.emit("k")));
                  e.on("ff",
                      (data) => burst.fullFlush().then((value) => e.emit("k")));
                }, start: true)),
        super();

  bool isClosed() => _closed;

  void close() {
    if (_closed) {
      throw new Exception("Already closed");
    }

    _closed = true;
    threads
        .forEach((element) => element.stop(priority: Isolate.beforeNextEvent));
  }

  Future<void> flush() => _signal("f");

  Future<void> fullFlush() => _signal("ff");

  Future<void> _signal(String command) {
    if (isClosed()) {
      throw new Exception("Already closed");
    }

    Future.wait(_queues).then((value) => _queues.clear());

    List<Future> f = [];
    for (Thread i in threads) {
      Completer<void> c = Completer();
      i.emit(command);
      i.once("k", (data) => c.complete());
      f.add(c.future);
    }

    return Future.wait(f);
  }

  void queue(BurstRunner r) {
    if (isClosed()) {
      throw new Exception("Already closed");
    }

    Completer<void> c = Completer();
    Thread t = threads[_cursor++ % threads.length];
    t.emit("q", r);
    t.once("k", (data) => c.complete());
    _queues.add(c.future);
  }
}

class Burst {
  List<Future<void>> _queue = [];
  int _active = 0;
  int _total = 0;
  int _completed = 0;

  void queue(BurstRunner runner) {
    _active++;
    _total++;
    _queue.add(runner().then((value) {
      _active--;
      _completed++;
    }));
  }

  int getTotal() => _total;

  int getCompleted() => _completed;

  int getActive() => _active;

  void queueAll(List<BurstRunner> runners) => runners.forEach((e) => queue(e));

  Future<void> flush() => Future.wait(_queue).then((value) => _queue.clear());

  Future<void> fullFlush() async {
    while (_queue.isNotEmpty) {
      await flush();
    }
  }
}
