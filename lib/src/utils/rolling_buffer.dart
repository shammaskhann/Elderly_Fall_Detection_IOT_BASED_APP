class RollingBuffer<T> {
  RollingBuffer({required this.capacity});
  final int capacity;
  final List<T> _items = <T>[];

  void add(T item) {
    _items.add(item);
    if (_items.length > capacity) {
      _items.removeAt(0);
    }
  }

  List<T> snapshot() => List<T>.unmodifiable(_items);

  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  void clear() => _items.clear();
}
