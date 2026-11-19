import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thulium/auth/secure_auth_session_store.dart';
import 'package:thulium_auth/thulium_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'default stores share the session coordination identity and retain persisted credentials',
    () async {
      const session = AuthSession(
        userId: '1234567890',
        fingerprint: 'stable-device',
        cookies: {},
        fingerGenPrint: 'trusted-device',
      );
      FlutterSecureStorage.setMockInitialValues({
        'thulium.auth.session': session.encode(),
        'thulium.auth.credentials':
            '{"userId":"1234567890","password":"saved-password"}',
        'thulium.auth.fingerprint': 'stable-device',
      });
      final home = SecureAuthSessionStore();
      final calendar = SecureAuthSessionStore();
      final documents = SecureAuthSessionStore();
      expect(identical(home, calendar), isTrue);
      expect(identical(calendar, documents), isTrue);
      expect((await documents.read())!.fingerGenPrint, 'trusted-device');
      expect((await calendar.readCredentials())!.password, 'saved-password');
      expect(await home.getOrCreateFingerprint(), 'stable-device');

      await home.clear();
      expect(await calendar.read(), isNull);
      expect((await documents.readCredentials())!.password, 'saved-password');
      await home.clearCredentials();
      expect(await documents.readCredentials(), isNull);
      expect(await home.getOrCreateFingerprint(), 'stable-device');
    },
  );
}
