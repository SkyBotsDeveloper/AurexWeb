// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart';

Future<void> main() async {
  final env = _loadEnvFile('.env');
  final url = env['SUPABASE_URL']?.trim();
  final key = (env['SUPABASE_PUBLISHABLE_KEY'] ?? env['SUPABASE_ANON_KEY'])
      ?.trim();

  if (url == null || url.isEmpty || key == null || key.isEmpty) {
    throw StateError('Supabase URL or publishable key is missing.');
  }

  final stamp = DateTime.now().millisecondsSinceEpoch;
  final initialPassword = 'AurexVerify!$stamp';
  final updatedPassword = 'AurexUpdated!$stamp';
  final report = <String, Object?>{
    'emailPasswordAuthVerified': false,
    'sessionRecoveryVerified': false,
    'roomCreateJoinVerified': false,
    'roomRealtimeChatVerified': false,
    'roomRealtimePlaybackVerified': false,
    'roomRealtimeHostTransferVerified': false,
    'hostOnlyPlaybackWriteVerified': false,
    'roomHostTransferVerified': false,
    'roomAutoHostTransferVerified': false,
    'passwordResetVerified': false,
    'details': <String, Object?>{},
  };

  final authOptions = const AuthClientOptions(
    autoRefreshToken: false,
    authFlowType: AuthFlowType.implicit,
  );
  final clientOne = SupabaseClient(url, key, authOptions: authOptions);
  final clientTwo = SupabaseClient(url, key, authOptions: authOptions);
  final sessionProbe = SupabaseClient(url, key, authOptions: authOptions);
  final mailClient = _MailTmClient();

  try {
    stderr.writeln('create temporary inboxes');
    final inboxOne = await _withTimeout(
      mailClient.createInbox('aurexverifyone$stamp'),
      const Duration(seconds: 45),
    );
    final inboxTwo = await _withTimeout(
      mailClient.createInbox('aurexverifytwo$stamp'),
      const Duration(seconds: 45),
    );

    stderr.writeln('sign up first user');
    final authOne = await _withTimeout(
      _signUpAndAuthenticate(
        clientOne,
        mailClient: mailClient,
        inbox: inboxOne,
        password: initialPassword,
      ),
      const Duration(minutes: 2),
    );

    stderr.writeln('recover persisted session for first user');
    final sessionJson = jsonEncode(authOne.session?.toJson());
    await _withTimeout(
      sessionProbe.auth.recoverSession(sessionJson),
      const Duration(seconds: 45),
    );

    report['emailPasswordAuthVerified'] = authOne.session != null;
    report['sessionRecoveryVerified'] =
        sessionProbe.auth.currentUser?.email == inboxOne.address;
    report['details'] = {
      ...(report['details'] as Map<String, Object?>),
      'userOneEmail': inboxOne.address,
      'userOneId': authOne.user?.id,
    };

    stderr.writeln('sign up second user');
    final authTwo = await _withTimeout(
      _signUpAndAuthenticate(
        clientTwo,
        mailClient: mailClient,
        inbox: inboxTwo,
        password: initialPassword,
      ),
      const Duration(minutes: 2),
    );

    report['emailPasswordAuthVerified'] =
        report['emailPasswordAuthVerified'] == true && authTwo.session != null;
    report['details'] = {
      ...(report['details'] as Map<String, Object?>),
      'userTwoEmail': inboxTwo.address,
      'userTwoId': authTwo.user?.id,
    };

    try {
      stderr.writeln('create room and subscribe to realtime streams');
      final room = Map<String, dynamic>.from(
        await _withTimeout(
              clientOne.rpc(
                'create_room',
                params: {'p_name': 'Verification Room $stamp'},
              ),
              const Duration(seconds: 45),
            )
            as Map,
      );
      final roomId = room['id'] as String;
      final roomCode = room['code'] as String;

      final listenerMessage = 'listener verification message $stamp';
      final playbackSequence = stamp % 100000;

      final chatRealtime = _firstMatchingEvent<List<Map<String, dynamic>>>(
        clientOne
            .from('room_messages')
            .stream(primaryKey: ['id'])
            .eq('room_id', roomId)
            .order('created_at'),
        (rows) => rows.any((row) => row['message'] == listenerMessage),
      );

      final playbackRealtime = _firstMatchingEvent<List<Map<String, dynamic>>>(
        clientTwo
            .from('room_playback_states')
            .stream(primaryKey: ['room_id'])
            .eq('room_id', roomId),
        (rows) => rows.any((row) => row['sequence'] == playbackSequence),
      );

      final roomRealtime = _firstMatchingEvent<List<Map<String, dynamic>>>(
        clientOne.from('rooms').stream(primaryKey: ['id']).eq('id', roomId),
        (rows) => rows.any((row) => row['host_user_id'] == authTwo.user?.id),
      );

      stderr.writeln('join room and exchange chat');
      await _withTimeout(
        clientTwo.rpc('join_room', params: {'p_code': roomCode}),
        const Duration(seconds: 45),
      );
      await _withTimeout(
        clientOne.from('room_messages').insert({
          'room_id': roomId,
          'user_id': authOne.user!.id,
          'display_name': inboxOne.address,
          'message': 'host verification message $stamp',
          'kind': 'message',
        }),
        const Duration(seconds: 45),
      );
      await _withTimeout(
        clientTwo.from('room_messages').insert({
          'room_id': roomId,
          'user_id': authTwo.user!.id,
          'display_name': inboxTwo.address,
          'message': listenerMessage,
          'kind': 'message',
        }),
        const Duration(seconds: 45),
      );

      final roomMembersBeforeTransfer = List<Map<String, dynamic>>.from(
        await _withTimeout(
          clientOne
              .from('room_members')
              .select('user_id, role, left_at')
              .eq('room_id', roomId),
          const Duration(seconds: 45),
        ),
      );
      final roomMessages = List<Map<String, dynamic>>.from(
        await _withTimeout(
          clientOne
              .from('room_messages')
              .select('user_id, message, kind')
              .eq('room_id', roomId)
              .order('created_at'),
          const Duration(seconds: 45),
        ),
      );

      stderr.writeln('sync playback as host');
      await _withTimeout(
        clientOne.from('room_playback_states').upsert({
          'room_id': roomId,
          'host_user_id': authOne.user!.id,
          'track_json': {'id': 'track-$stamp', 'title': 'Verification Track'},
          'queue_json': [
            {'id': 'track-$stamp', 'title': 'Verification Track'},
          ],
          'queue_index': 0,
          'position_ms': 12000,
          'is_playing': true,
          'sequence': playbackSequence,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }),
        const Duration(seconds: 45),
      );

      stderr.writeln('verify listener cannot write playback');
      var listenerWriteBlocked = false;
      try {
        await _withTimeout(
          clientTwo.from('room_playback_states').upsert({
            'room_id': roomId,
            'host_user_id': authTwo.user!.id,
            'track_json': {
              'id': 'listener-track-$stamp',
              'title': 'Blocked Track',
            },
            'queue_json': const [],
            'queue_index': 0,
            'position_ms': 0,
            'is_playing': false,
            'sequence': playbackSequence + 1,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }),
          const Duration(seconds: 45),
        );
      } on PostgrestException {
        listenerWriteBlocked = true;
      } on AuthException {
        listenerWriteBlocked = true;
      }

      stderr.writeln('transfer host and verify auto-transfer');
      await _withTimeout(
        clientOne.rpc(
          'transfer_room_host',
          params: {'p_room_id': roomId, 'p_new_host_user_id': authTwo.user!.id},
        ),
        const Duration(seconds: 45),
      );

      final roomAfterTransferDirect = Map<String, dynamic>.from(
        await _withTimeout(
          clientOne
              .from('rooms')
              .select('id, code, host_user_id, is_active')
              .eq('id', roomId)
              .single(),
          const Duration(seconds: 45),
        ),
      );

      List<Map<String, dynamic>>? roomAfterTransferRealtime;
      Object? roomRealtimeError;
      try {
        roomAfterTransferRealtime = await _withTimeout(
          roomRealtime,
          const Duration(seconds: 30),
        );
      } catch (error) {
        roomRealtimeError = error;
      }

      final playbackState = Map<String, dynamic>.from(
        await _withTimeout(
          clientOne
              .from('room_playback_states')
              .select('room_id, host_user_id, sequence, is_playing')
              .eq('room_id', roomId)
              .single(),
          const Duration(seconds: 45),
        ),
      );

      await _withTimeout(
        clientTwo.rpc('leave_room', params: {'p_room_id': roomId}),
        const Duration(seconds: 45),
      );

      final roomAfterAutoTransfer = Map<String, dynamic>.from(
        await _withTimeout(
          clientOne
              .from('rooms')
              .select('id, code, host_user_id, is_active')
              .eq('id', roomId)
              .single(),
          const Duration(seconds: 45),
        ),
      );

      List<Map<String, dynamic>>? chatRows;
      Object? chatRealtimeError;
      try {
        chatRows = await _withTimeout(
          chatRealtime,
          const Duration(seconds: 30),
        );
      } catch (error) {
        chatRealtimeError = error;
      }

      List<Map<String, dynamic>>? playbackRows;
      Object? playbackRealtimeError;
      try {
        playbackRows = await _withTimeout(
          playbackRealtime,
          const Duration(seconds: 30),
        );
      } catch (error) {
        playbackRealtimeError = error;
      }

      final activeMemberIds = roomMembersBeforeTransfer
          .where((row) => row['left_at'] == null)
          .map((row) => row['user_id'] as String)
          .toSet();
      final roomChatVerified = roomMessages.any(
        (row) => row['message'] == listenerMessage,
      );

      report['roomCreateJoinVerified'] = activeMemberIds.containsAll({
        authOne.user!.id,
        authTwo.user!.id,
      });
      report['roomRealtimeChatVerified'] =
          chatRows?.any((row) => row['message'] == listenerMessage) ?? false;
      report['roomRealtimePlaybackVerified'] =
          playbackRows?.any((row) => row['sequence'] == playbackSequence) ??
          false;
      report['roomRealtimeHostTransferVerified'] =
          roomAfterTransferRealtime?.any(
            (row) => row['host_user_id'] == authTwo.user!.id,
          ) ??
          false;
      report['hostOnlyPlaybackWriteVerified'] =
          listenerWriteBlocked &&
          playbackState['sequence'] == playbackSequence &&
          playbackState['host_user_id'] == authOne.user!.id;
      report['roomHostTransferVerified'] =
          roomAfterTransferDirect['host_user_id'] == authTwo.user!.id &&
          roomChatVerified;
      report['roomAutoHostTransferVerified'] =
          roomAfterAutoTransfer['host_user_id'] == authOne.user!.id &&
          roomAfterAutoTransfer['is_active'] == true;
      report['details'] = {
        ...(report['details'] as Map<String, Object?>),
        'roomId': roomId,
        'roomCode': roomCode,
        'roomMessageCount': roomMessages.length,
        'roomPlaybackHostUserId': playbackState['host_user_id'],
        'roomPlaybackSequence': playbackState['sequence'],
        'roomActiveMemberCount': activeMemberIds.length,
        'roomChatVerified': roomChatVerified,
        'roomRealtimeChatRows': chatRows?.length,
        'roomRealtimePlaybackRows': playbackRows?.length,
        'hostAfterManualTransfer': roomAfterTransferDirect['host_user_id'],
        'hostAfterAutoTransfer': roomAfterAutoTransfer['host_user_id'],
        if (chatRealtimeError != null)
          'roomRealtimeChatError': chatRealtimeError.toString(),
        if (playbackRealtimeError != null)
          'roomRealtimePlaybackError': playbackRealtimeError.toString(),
        if (roomRealtimeError != null)
          'roomRealtimeHostTransferError': roomRealtimeError.toString(),
      };

      await _withTimeout(
        clientOne.rpc('leave_room', params: {'p_room_id': roomId}),
        const Duration(seconds: 45),
      );
    } catch (error, stackTrace) {
      report['details'] = {
        ...(report['details'] as Map<String, Object?>),
        'roomError': error.toString(),
        'roomStackTrace': stackTrace.toString(),
      };
    }

    stderr.writeln('request password reset and set a new password');
    final resetRequestedAt = DateTime.now().toUtc();
    await _withTimeout(
      clientOne.auth.resetPasswordForEmail(
        inboxOne.address,
        redirectTo: 'aurex://auth-callback',
      ),
      const Duration(seconds: 45),
    );

    await _withTimeout(
      _confirmFromInbox(
        client: clientOne,
        mailClient: mailClient,
        inbox: inboxOne,
        requestedAt: resetRequestedAt,
        fallbackType: OtpType.recovery,
      ),
      const Duration(minutes: 2),
    );
    await _withTimeout(
      clientOne.auth.updateUser(UserAttributes(password: updatedPassword)),
      const Duration(seconds: 45),
    );
    await _withTimeout(clientOne.auth.signOut(), const Duration(seconds: 45));
    final resetAuth = await _withTimeout(
      clientOne.auth.signInWithPassword(
        email: inboxOne.address,
        password: updatedPassword,
      ),
      const Duration(seconds: 45),
    );
    report['passwordResetVerified'] = resetAuth.session != null;

    stderr.writeln('sign out');
    await _withTimeout(clientOne.auth.signOut(), const Duration(seconds: 45));
    await _withTimeout(clientTwo.auth.signOut(), const Duration(seconds: 45));
  } catch (error, stackTrace) {
    report['details'] = {
      ...(report['details'] as Map<String, Object?>),
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
    };
  } finally {
    await clientOne.dispose();
    await clientTwo.dispose();
    await sessionProbe.dispose();
    mailClient.close();
  }

  print(const JsonEncoder.withIndent('  ').convert(report));
}

Future<void> _confirmFromInbox({
  required SupabaseClient client,
  required _MailTmClient mailClient,
  required _TempInbox inbox,
  required DateTime requestedAt,
  required OtpType fallbackType,
}) async {
  final message = await mailClient.waitForAuthMessage(
    inbox,
    receivedAfter: requestedAt,
  );
  final authLink = _extractAuthLink(message);
  if (authLink == null) {
    throw StateError('No auth link or token was found in ${message.subject}.');
  }

  final params = <String, String>{
    ...authLink.uri.queryParameters,
    ..._fragmentParameters(authLink.uri),
  };
  final type = _otpTypeFromValue(params['type']) ?? fallbackType;
  final tokenHash = params['token_hash'] ?? authLink.tokenHash;
  final token = params['token'] ?? authLink.token;

  if (tokenHash != null && tokenHash.isNotEmpty) {
    await client.auth.verifyOTP(
      email: inbox.address,
      tokenHash: tokenHash,
      type: type,
    );
    return;
  }

  if (token != null && token.isNotEmpty) {
    await client.auth.verifyOTP(email: inbox.address, token: token, type: type);
    return;
  }

  final callbackUri = await _followAuthUrl(authLink.uri);
  final callbackParams = <String, String>{
    ...callbackUri.queryParameters,
    ..._fragmentParameters(callbackUri),
  };
  final callbackTokenHash = callbackParams['token_hash'];
  final callbackToken = callbackParams['token'];

  if (callbackTokenHash != null && callbackTokenHash.isNotEmpty) {
    await client.auth.verifyOTP(
      email: inbox.address,
      tokenHash: callbackTokenHash,
      type: _otpTypeFromValue(callbackParams['type']) ?? type,
    );
    return;
  }

  if (callbackToken != null && callbackToken.isNotEmpty) {
    await client.auth.verifyOTP(
      email: inbox.address,
      token: callbackToken,
      type: _otpTypeFromValue(callbackParams['type']) ?? type,
    );
    return;
  }

  if (callbackParams.containsKey('access_token') ||
      callbackParams.containsKey('refresh_token') ||
      callbackParams.containsKey('code')) {
    await client.auth.getSessionFromUrl(callbackUri);
    return;
  }

  throw StateError('Auth callback did not include a usable session or token.');
}

Future<AuthResponse> _signUpAndAuthenticate(
  SupabaseClient client, {
  required _MailTmClient mailClient,
  required _TempInbox inbox,
  required String password,
}) async {
  final requestedAt = DateTime.now().toUtc();
  final response = await client.auth.signUp(
    email: inbox.address,
    password: password,
  );
  if (response.session != null) {
    return response;
  }

  await _confirmFromInbox(
    client: client,
    mailClient: mailClient,
    inbox: inbox,
    requestedAt: requestedAt,
    fallbackType: OtpType.signup,
  );
  return client.auth.signInWithPassword(
    email: inbox.address,
    password: password,
  );
}

Future<Uri> _followAuthUrl(Uri url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    final request = await client.getUrl(url);
    request.followRedirects = false;
    final response = await request.close();
    final location = response.headers.value(HttpHeaders.locationHeader);
    if (location == null || location.isEmpty) {
      return url;
    }
    return Uri.parse(location);
  } finally {
    client.close(force: true);
  }
}

_AuthLink? _extractAuthLink(_MailMessageDetails message) {
  final candidates = <String>[
    message.subject,
    if (message.intro != null) message.intro!,
    if (message.text != null) message.text!,
    ...message.htmlParts,
    jsonEncode(message.raw),
  ].map(_decodeHtmlEntities);

  final urlPattern = RegExp(r"""(https?|aurex):\/\/[^\s"'<>]+""");
  for (final candidate in candidates) {
    for (final match in urlPattern.allMatches(candidate)) {
      final raw = _trimUrl(candidate.substring(match.start, match.end));
      final uri = Uri.tryParse(raw);
      if (uri == null) {
        continue;
      }
      final params = <String, String>{
        ...uri.queryParameters,
        ..._fragmentParameters(uri),
      };
      if (params.containsKey('token_hash') ||
          params.containsKey('token') ||
          params['type'] != null ||
          uri.path.contains('/auth/v1/verify')) {
        return _AuthLink(
          uri: uri,
          tokenHash: params['token_hash'],
          token: params['token'],
        );
      }
    }
  }

  return null;
}

String _decodeHtmlEntities(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#x3D;', '=')
      .replaceAll('&#61;', '=')
      .replaceAll('&#x2F;', '/')
      .replaceAll('&#47;', '/');
}

String _trimUrl(String url) {
  return url.replaceAll(RegExp(r'[)>.,]+$'), '');
}

Map<String, String> _fragmentParameters(Uri uri) {
  if (uri.fragment.isEmpty) {
    return const <String, String>{};
  }
  return Uri.splitQueryString(uri.fragment);
}

OtpType? _otpTypeFromValue(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'signup':
      return OtpType.signup;
    case 'recovery':
      return OtpType.recovery;
    case 'magiclink':
      return OtpType.magiclink;
    case 'invite':
      return OtpType.invite;
    case 'email':
      return OtpType.email;
    case 'email_change':
    case 'emailchange':
      return OtpType.emailChange;
    case 'phone_change':
    case 'phonechange':
      return OtpType.phoneChange;
    case 'sms':
      return OtpType.sms;
    default:
      return null;
  }
}

Future<T> _withTimeout<T>(Future<T> future, Duration timeout) {
  return future.timeout(timeout);
}

Future<T> _firstMatchingEvent<T>(
  Stream<T> stream,
  bool Function(T event) matches,
) async {
  late final StreamSubscription<T> subscription;
  final completer = Completer<T>();
  unawaited(
    completer.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
  );

  subscription = stream.listen(
    (event) {
      if (!completer.isCompleted && matches(event)) {
        completer.complete(event);
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    },
  );

  try {
    return await completer.future;
  } finally {
    await subscription.cancel();
  }
}

Map<String, String> _loadEnvFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return const <String, String>{};
  }

  final values = <String, String>{};
  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#') || !line.contains('=')) {
      continue;
    }
    final split = line.indexOf('=');
    final key = line.substring(0, split).trim();
    final value = line.substring(split + 1).trim();
    values[key] = value;
  }
  return values;
}

class _MailTmClient {
  _MailTmClient() {
    _client.connectionTimeout = const Duration(seconds: 30);
  }

  final HttpClient _client = HttpClient();

  Future<_TempInbox> createInbox(String localPart) async {
    final safeLocalPart = localPart.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final address = '$safeLocalPart@dollicons.com';
    final password = 'TempMail!${DateTime.now().millisecondsSinceEpoch}';

    final accountResponse = await _requestJson(
      'POST',
      Uri.parse('https://api.mail.tm/accounts'),
      body: {'address': address, 'password': password},
    );
    final normalizedAddress =
        (accountResponse['address'] as String?)?.trim() ?? address;

    final tokenResponse = await _requestJson(
      'POST',
      Uri.parse('https://api.mail.tm/token'),
      body: {'address': normalizedAddress, 'password': password},
    );

    return _TempInbox(
      id: accountResponse['id'] as String,
      address: normalizedAddress,
      password: password,
      token: tokenResponse['token'] as String,
    );
  }

  Future<_MailMessageDetails> waitForAuthMessage(
    _TempInbox inbox, {
    required DateTime receivedAfter,
  }) async {
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    while (DateTime.now().isBefore(deadline)) {
      final listResponse = await _requestJson(
        'GET',
        Uri.parse('https://api.mail.tm/messages?page=1'),
        bearerToken: inbox.token,
      );
      final members =
          (listResponse['hydra:member'] as List<dynamic>? ?? const <dynamic>[])
              .cast<dynamic>();
      for (final raw in members) {
        final item = Map<String, dynamic>.from(raw as Map);
        final createdAt = DateTime.tryParse(item['createdAt'] as String? ?? '');
        if (createdAt != null &&
            createdAt.isBefore(
              receivedAfter.subtract(const Duration(seconds: 1)),
            )) {
          continue;
        }
        final detail = await _requestJson(
          'GET',
          Uri.parse('https://api.mail.tm/messages/${item['id']}'),
          bearerToken: inbox.token,
        );
        final message = _MailMessageDetails.fromJson(detail);
        if (_extractAuthLink(message) != null) {
          return message;
        }
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }

    throw TimeoutException(
      'Timed out waiting for an auth email for ${inbox.address}.',
    );
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final request = await _openRequest(
          method,
          uri,
          bearerToken: bearerToken,
        );
        if (body != null) {
          final payload = utf8.encode(jsonEncode(body));
          request.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/json; charset=utf-8',
          );
          request.contentLength = payload.length;
          request.add(payload);
        }
        final response = await request.close();
        final payload = await utf8.decoder.bind(response).join();
        if (response.statusCode >= 500 && attempt < 2) {
          await Future<void>.delayed(Duration(seconds: attempt + 1));
          continue;
        }
        if (response.statusCode >= 400) {
          throw HttpException(
            'mail.tm request failed (${response.statusCode}): $payload',
            uri: uri,
          );
        }
        final decoded = jsonDecode(payload.isEmpty ? '{}' : payload);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        if (decoded is List) {
          if (decoded.isEmpty) {
            return const <String, dynamic>{};
          }
          final first = decoded.first;
          if (first is Map) {
            return Map<String, dynamic>.from(first);
          }
          return <String, dynamic>{'items': decoded};
        }
        return <String, dynamic>{'value': decoded};
      } catch (error) {
        lastError = error;
        if (attempt == 2) {
          rethrow;
        }
        await Future<void>.delayed(Duration(seconds: attempt + 1));
      }
    }
    throw StateError('mail.tm request failed: $lastError');
  }

  Future<HttpClientRequest> _openRequest(
    String method,
    Uri uri, {
    String? bearerToken,
  }) async {
    final request = switch (method) {
      'GET' => await _client.getUrl(uri),
      'POST' => await _client.postUrl(uri),
      _ => throw UnsupportedError('Unsupported method $method'),
    };
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AurexVerifier/1.0',
    );
    if (bearerToken != null) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $bearerToken',
      );
    }
    return request;
  }

  void close() {
    _client.close(force: true);
  }
}

class _TempInbox {
  const _TempInbox({
    required this.id,
    required this.address,
    required this.password,
    required this.token,
  });

  final String id;
  final String address;
  final String password;
  final String token;
}

class _MailMessageDetails {
  const _MailMessageDetails({
    required this.raw,
    required this.subject,
    required this.intro,
    required this.text,
    required this.htmlParts,
  });

  factory _MailMessageDetails.fromJson(Map<String, dynamic> json) {
    return _MailMessageDetails(
      raw: json,
      subject: json['subject'] as String? ?? '',
      intro: json['intro'] as String?,
      text: json['text'] as String?,
      htmlParts: (json['html'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
    );
  }

  final Map<String, dynamic> raw;
  final String subject;
  final String? intro;
  final String? text;
  final List<String> htmlParts;
}

class _AuthLink {
  const _AuthLink({required this.uri, this.tokenHash, this.token});

  final Uri uri;
  final String? tokenHash;
  final String? token;
}
