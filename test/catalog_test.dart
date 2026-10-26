import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/data/catalog.dart';

CatalogItem item(String title, List<String> topics, {String platform = 'LeetCode'}) =>
    CatalogItem(platform: platform, title: title, difficulty: 'Easy', topics: topics, url: 'https://x');

void main() {
  final items = [
    item('Add Two Numbers', ['Linked List', 'Math']),
    item('Two Sum', ['Array', 'Hash Table']),
    item('Two Sum II', ['Array', 'Two Pointers']),
    item('Two Sum CF', ['Math'], platform: 'Codeforces'),
  ];

  test('search puts "starts with" before "contains" and filters by platform', () {
    expect(searchCatalog(items, 'LeetCode', 'two').map((i) => i.title), ['Two Sum', 'Two Sum II', 'Add Two Numbers']);
    expect(searchCatalog(items, 'Codeforces', 'two').map((i) => i.title), ['Two Sum CF']);
    expect(searchCatalog(items, 'LeetCode', 't'), isEmpty); // needs 2+ letters
  });

  test('main topic prefers the roadmap order', () {
    expect(item('x', ['Math', 'Linked List']).mainTopic, 'Linked List');
    expect(item('x', ['Geometry']).mainTopic, 'Geometry');
  });

  test('topic choices list the roadmap first, then other tags', () {
    final choices = topicChoices(items);
    expect(choices.first, 'Array');
    expect(choices.toSet().length, choices.length);
  });

  test('bundled catalog file loads', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final catalog = await loadCatalog();
    expect(catalog.length, greaterThan(3000));
    expect(searchCatalog(catalog, 'LeetCode', 'two sum').first.title, 'Two Sum');
  });
}
