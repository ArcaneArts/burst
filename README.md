Lots of threading tools for executing jobs in parallel in various ways.

## Usage

```dart
MultiBurst burst = MultiBurst(threadCount: 8);
burst.queue(() => expensiveCall());
burst.queue(() => expensiveCall());
burst.queue(() => expensiveCall());

burst.flush();

// Keep flushing until all jobs are done.
burst.flushAll();

// Stop threads
burst.close();
```