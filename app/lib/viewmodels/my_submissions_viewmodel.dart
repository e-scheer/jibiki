import '../models/mnemonic.dart';
import '../repositories/mnemonic_repository.dart';
import 'base_view_model.dart';

/// The signed-in user's own mnemonic contributions, across every status (so a
/// held "pending" submission is never invisible to its author).
class MySubmissionsViewModel extends BaseViewModel {
  MySubmissionsViewModel(this._mnemonics);
  final MnemonicRepository _mnemonics;

  List<Mnemonic> _items = [];
  List<Mnemonic> get items => _items;

  Future<void> load() async {
    final r = await runGuarded(() => _mnemonics.mine());
    if (r != null) _items = r;
  }
}
