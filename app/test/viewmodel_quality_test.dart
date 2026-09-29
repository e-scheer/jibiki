import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_exception.dart';
import 'package:jibiki/models/kana.dart';
import 'package:jibiki/models/word.dart';
import 'package:jibiki/repositories/dictionary_repository.dart';
import 'package:jibiki/services/dictionary_data_source.dart';
import 'package:jibiki/viewmodels/base_view_model.dart';
import 'package:jibiki/viewmodels/browse_viewmodel.dart';
import 'package:jibiki/viewmodels/kana_viewmodel.dart';
import 'package:jibiki/viewmodels/search_viewmodel.dart';

class _Guard extends BaseViewModel {
  Future<T?> run<T>(Future<T> future,
          {bool silent = false, bool concurrent = false}) =>
      runGuarded(() => future, silent: silent, allowConcurrent: concurrent);
}

class _Dictionary implements DictionaryDataSource {
  final requests = <String, Completer<SearchResults>>{};
  final kanaResult = Completer<List<KanaEntry>>();
  final pageOffsets = <int>[];
  bool failNextPage = false;

  @override
  Future<List<WordEntry>> words(
      {bool common = false, int? jlpt, int limit = 60, int offset = 0}) async {
    pageOffsets.add(offset);
    if (failNextPage) {
      failNextPage = false;
      throw ApiException('Page unavailable');
    }
    return List.generate(offset == 0 ? limit : 3,
        (i) => WordEntry.fromJson({'id': offset + i, 'headword': '語'}));
  }

  @override
  Future<SearchResults> search(String q,
          {String lang = 'en', int limit = 25}) =>
      (requests[q] = Completer<SearchResults>()).future;

  @override
  Future<List<KanaEntry>> kana({String? script}) => kanaResult.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SearchResults _result(int id, String text) => SearchResults(words: [
      WordEntry.fromJson({'id': id, 'headword': text}),
    ], names: []);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a completed background operation does not unlock a foreground write',
      () async {
    final vm = _Guard();
    final foreground = Completer<int>();
    final active = vm.run(foreground.future);
    await vm.run(Future.value(2), silent: true);
    expect(vm.isLoading, isTrue);
    foreground.complete(1);
    expect(await active, 1);
    expect(vm.isLoading, isFalse);
    vm.dispose();
  });

  test('an older failed request cannot replace a newer successful state',
      () async {
    final vm = _Guard();
    final old = Completer<int>();
    final active = vm.run(old.future);
    await vm.run(Future.value(2), concurrent: true);
    old.completeError(ApiException('Old failure'));
    await active;
    expect(vm.error, isNull);
    vm.dispose();
  });

  test('search accepts new input while the previous lookup is in flight',
      () async {
    final source = _Dictionary();
    final vm =
        SearchViewModel(DictionaryRepository(source), glossLanguage: 'en');
    final old = vm.submit('water');
    final current = vm.submit('fire');
    expect(source.requests.keys, containsAll(['water', 'fire']));
    source.requests['fire']!.complete(_result(2, '火'));
    await current;
    source.requests['water']!.complete(_result(1, '水'));
    await old;
    expect(vm.results.single.headword, '火');
    vm.dispose();
  });

  test('a kana load notifies after the visible list has been assembled',
      () async {
    final source = _Dictionary();
    final vm = KanaViewModel(DictionaryRepository(source));
    var lastVisibleCount = -1;
    vm.addListener(() => lastVisibleCount = vm.current.length);
    final load = vm.load();
    source.kanaResult.complete([
      KanaEntry.fromJson({'char': 'あ', 'romaji': 'a', 'script': 'hiragana'}),
    ]);
    await load;
    expect(lastVisibleCount, 1);
    vm.dispose();
  });

  test('clearing a search also discards a late failure', () async {
    final source = _Dictionary();
    final vm =
        SearchViewModel(DictionaryRepository(source), glossLanguage: 'en');
    final active = vm.submit('water');
    vm.onQueryChanged('');
    source.requests['water']!.completeError(ApiException('Late failure'));
    await active;
    expect(vm.error, isNull);
    expect(vm.results, isEmpty);
    vm.dispose();
  });

  test('browse keeps the first page on error and retries the same next page',
      () async {
    final source = _Dictionary();
    final vm = BrowseViewModel(DictionaryRepository(source),
        const BrowseSpec.words(title: 'Common', common: true));
    await vm.load();
    expect(vm.words, hasLength(60));
    expect(vm.hasMore, isTrue);
    source.failNextPage = true;
    await vm.loadMore();
    expect(vm.words, hasLength(60));
    expect(vm.hasError, isTrue);
    await vm.loadMore();
    expect(source.pageOffsets, [0, 60, 60]);
    expect(vm.words, hasLength(63));
    expect(vm.hasMore, isFalse);
    expect(vm.hasError, isFalse);
    await vm.loadMore();
    expect(source.pageOffsets, hasLength(3));
    vm.dispose();
  });

  test('a late search result after leaving its screen is harmless', () async {
    final source = _Dictionary();
    final vm =
        SearchViewModel(DictionaryRepository(source), glossLanguage: 'en');
    final active = vm.submit('water');
    vm.dispose();
    source.requests['water']!.complete(_result(1, '水'));
    await active;
  });
}
