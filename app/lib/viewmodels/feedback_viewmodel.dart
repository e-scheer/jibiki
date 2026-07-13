import 'package:flutter/foundation.dart';

import '../infrastructure/packs/pack_manager.dart';
import '../services/feedback_service.dart';
import 'app_state.dart';
import 'base_view_model.dart';

/// One kind of thing the user might want to tell us. The prompt changes with
/// it so the empty field never feels like a blank form.
enum FeedbackKind {
  idea('idea', 'Idea', 'What would make jibiki better for you?'),
  bug('bug', 'Bug', 'What happened - and what did you expect instead?'),
  love('love', 'Love', 'What do you love? (This fuels us.)'),
  other('other', 'Other', "What's on your mind?");

  const FeedbackKind(this.wire, this.label, this.prompt);

  final String wire;
  final String label;
  final String prompt;
}

class FeedbackViewModel extends BaseViewModel {
  FeedbackViewModel(this._service, this._app, this._packs);

  final FeedbackService _service;
  final AppState _app;
  final PackManager? _packs;

  FeedbackKind _kind = FeedbackKind.idea;
  String _message = '';
  String _email = '';
  bool _sent = false;

  FeedbackKind get kind => _kind;
  String get message => _message;
  bool get sent => _sent;
  bool get canSubmit => _message.trim().length >= 3 && !isLoading;

  /// Anonymous senders can leave a reply-to; signed-in users already have one.
  bool get wantsEmailField => !_app.isAuthenticated;

  void selectKind(FeedbackKind value) {
    _kind = value;
    notifyListeners();
  }

  void setMessage(String value) {
    _message = value;
    notifyListeners();
  }

  void setEmail(String value) => _email = value;

  /// What rides along with the message - shown to the user verbatim on the
  /// screen, because transparency is what makes people comfortable sending.
  Map<String, dynamic> get context => {
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'offline': _app.offline,
        'local_only': _app.localOnly,
        'mode': _app.mode.wire,
        'packs': [
          for (final p in _packs?.installed ?? const <Never>[])
            '${p.id}@${p.version}',
        ],
      };

  Future<void> submit() async {
    if (!canSubmit) return;
    await runGuarded(() => _service.send(
          kind: _kind.wire,
          message: _message.trim(),
          email: _email.trim(),
          context: context,
        ));
    if (!hasError) {
      _sent = true;
      notifyListeners();
    }
  }
}
