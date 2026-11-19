import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:thulium_auth/thulium_auth.dart';
import 'package:thulium_campus/thulium_campus.dart';

void main() {
  test(
    'obsolete roaming landing falls back to the current Learn page without relogin',
    () async {
      final fixture = _Fixture()..obsoleteLanding = true;
      expect(await fixture.courses(), isNotEmpty);
      expect(fixture.landings, 2);
      expect(fixture.accountProbes, 0);
      expect(fixture.store.credentialReads, 0);
    },
  );
  test(
    'material-list permission failure leaves the main account and other services usable',
    () async {
      final fixture = _Fixture()..materialStatus = 403;
      await expectLater(fixture.materials(), throwsStateError);
      expect(await fixture.courses(), isNotEmpty);
      expect((await fixture.homework()).counts, {'course': 0});
      fixture.materialStatus = 200;
      expect((await fixture.materials()).single.materials, hasLength(1));
      expect(fixture.credentialPosts, 0);
      expect(fixture.store.credentialReads, 0);
      expect(fixture.store.clears, 0);
    },
  );

  test(
    'queued file reads reuse the repaired session without a second password login',
    () async {
      final fixture = _Fixture()..firstFileLoginPage = '<input name="i_pass">';
      final results = await Future.wait([
        fixture.download(),
        fixture.download(),
      ]);
      expect(results, hasLength(2));
      expect(fixture.fileRequests, 3);
      expect(fixture.accountProbes, 1);
      expect(fixture.store.credentialReads, 0);
    },
  );

  for (final status in [403, 404, 500]) {
    test(
      'file HTTP $status does not relogin or break subsequent courses',
      () async {
        final fixture = _Fixture()..fileStatus = status;
        await expectLater(fixture.download(), throwsStateError);
        expect(await fixture.courses(), isNotEmpty);
        expect((await fixture.homework()).counts, {'course': 0});
        expect(fixture.store.credentialReads, 0);
        expect(fixture.credentialPosts, 0);
        expect(fixture.store.clears, 0);
        expect(fixture.store.session!.fingerGenPrint, 'trusted-token');
      },
    );
  }

  for (final loginPage in [
    '<form action="/j_spring_security_check"><input name="username"></form>',
    '<a class="re_log" href="/f/login">重新登录</a>',
    '<span id="sm2publicKey">key</span>',
  ]) {
    test(
      'expired file response repairs Learn before retrying the download: $loginPage',
      () async {
        final fixture = _Fixture()..firstFileLoginPage = loginPage;
        expect(await fixture.download(), utf8.encode('%PDF-1.7\n%%EOF'));
        expect(fixture.fileRequests, 2);
        expect(fixture.landings, 2);
        expect(fixture.accountProbes, 1);
        expect(fixture.store.credentialReads, 0);
        expect(fixture.store.clears, 0);
      },
    );
  }

  test(
    'persistent Learn rejection preserves main login and stops after one retry',
    () async {
      final fixture = _Fixture()..fileStatus = 401;
      await expectLater(fixture.download(), throwsStateError);
      expect(fixture.fileRequests, 2);
      expect(fixture.credentialPosts, 0);
      expect(fixture.store.credentialReads, 0);
      expect(fixture.store.clears, 0);
      expect(await fixture.courses(), isNotEmpty);
    },
  );

  for (final jsonRejection in [false, true]) {
    test(
      'confirmed main expiry after a file error uses saved password and retries (JSON: $jsonRejection)',
      () async {
        final fixture = _Fixture()
          ..mainExpired = true
          ..jsonRejection = jsonRejection;
        expect(await fixture.download(), utf8.encode('%PDF-1.7\n%%EOF'));
        expect(fixture.fileRequests, 2);
        expect(fixture.store.credentialReads, 1);
        expect(fixture.credentialPosts, 2); // WebVPN then information portal.
        expect(fixture.store.session!.fingerGenPrint, 'trusted-token');
        expect(await fixture.courses(), isNotEmpty);
      },
    );
  }

  for (final tokenMarkup in [
    '<input value="learn-csrf" type="hidden" name="_csrf">',
    '<script>const config = {_csrf: "learn-csrf"};</script>',
    '<script>const config = {"csrfToken": "learn-csrf"};</script>',
  ]) {
    test(
      'Learn readiness accepts the reference token encoding: $tokenMarkup',
      () async {
        final fixture = _Fixture()..landingMarkup = tokenMarkup;
        expect(await fixture.courses(), isNotEmpty);
        expect(fixture.store.credentialReads, 0);
        expect(fixture.accountProbes, 0);
      },
    );
  }

  test(
    'gateway script and course text quoting login markup do not cause relogin',
    () async {
      final fixture = _Fixture()
        ..landingMarkup =
            '<script>const login = \'<input id="sm2publicKey">\';</script><input name="_csrf" value="learn-csrf">'
        ..quoteLoginMarkup = true;
      expect(await fixture.courses(), isNotEmpty);
      expect(
        (await fixture.materials()).single.materials.single.title,
        '<input id="sm2publicKey">',
      );
      expect(fixture.accountProbes, 0);
      expect(fixture.store.credentialReads, 0);
    },
  );
}

final _catalog = LearnCourseCatalog(
  userId: '1234567890',
  semester: '2026-2027-1',
  courses: const [
    LearnCourse(
      id: 'course',
      name: 'Course',
      englishName: '',
      teacherName: '',
      schedule: '',
    ),
  ],
);

final class _Fixture {
  final store = _Store();
  int fileStatus = 200;
  int materialStatus = 200;
  bool mainExpired = false;
  bool jsonRejection = false;
  bool quoteLoginMarkup = false;
  bool obsoleteLanding = false;
  String? firstFileLoginPage;
  String landingMarkup = '<input name="_csrf" value="learn-csrf">';
  int fileRequests = 0;
  int landings = 0;
  int accountProbes = 0;
  int credentialPosts = 0;
  bool _signedIn = false;
  late final transport = MockClient(_respond);

  AuthSessionRunner get runner => AuthSessionRunner(
    store,
    createClient: () => TsinghuaAuthClient(
      httpClient: transport,
      sessionStore: store,
      credentialStore: store,
    ),
  );

  Future<List<int>> download() => runner.run(
    request: (client, _) => LearnMaterialService(
      client,
    ).downloadPdf(fileId: 'file', courseId: 'course'),
  );

  Future<Map<String, dynamic>> courses() => runner.run(
    request: (client, _) =>
        LearnCourseService(client).fetchSemester('2026-2027-1'),
  );

  Future<LearnHomeworkSnapshot> homework() => runner.run(
    request: (client, _) =>
        LearnHomeworkService(client).fetchUnsubmittedHomework(_catalog),
  );

  Future<List<LearnCourseMaterials>> materials() => runner.run(
    request: (client, _) => LearnMaterialService(client).fetchCourses(_catalog),
  );

  Future<http.Response> _respond(http.Request request) async {
    final path = request.url.path;
    http.Response reply(String body, [int status = 200]) => http.Response(
      body,
      status,
      headers: {'content-type': 'text/html; charset=utf-8'},
      request: request,
    );
    if (path == '/wengine-vpn/cookie') {
      return reply('XSRF-TOKEN=portal-csrf; JSESSIONID=portal;');
    }
    if (path.endsWith('/grjbxx')) {
      accountProbes++;
      if (mainExpired && !_signedIn && jsonRejection) {
        return reply('{"code":401,"message":"login required"}');
      }
      return reply(
        '{"object":{"ryh":"1234567890"}}',
        mainExpired && !_signedIn ? 401 : 200,
      );
    }
    if (path.endsWith('onlineAppRedirect')) {
      return reply(
        jsonEncode({
          'object': {
            'roamingurl': obsoleteLanding
                ? 'https://learn.tsinghua.edu.cn/f/wlxt/index/course/student/index'
                : 'https://learn.tsinghua.edu.cn/f/wlxt/index/course/student/',
          },
        }),
      );
    }
    if (path.endsWith('/f/wlxt/index/course/student/')) {
      landings++;
      return reply(landingMarkup);
    }
    if (path.endsWith('/f/wlxt/index/course/student/index')) {
      landings++;
      return reply('Page not found', 404);
    }
    if (path.contains('/downloadPdfStream/')) {
      expect(request.url.queryParameters['_csrf'], 'learn-csrf');
      fileRequests++;
      if (mainExpired && !_signedIn) return reply('', 401);
      if (fileRequests == 1 && firstFileLoginPage != null) {
        return reply(firstFileLoginPage!);
      }
      return http.Response.bytes(
        utf8.encode('%PDF-1.7\n%%EOF'),
        fileStatus,
        headers: {'content-type': 'application/pdf'},
        request: request,
      );
    }
    if (path.contains('loadCourseBySemesterId')) {
      expect(request.url.queryParameters['_csrf'], 'learn-csrf');
      return reply(
        jsonEncode({
          'currentUser': '1234567890',
          'message': 'success',
          'resultList': [
            {
              'kcm': quoteLoginMarkup ? '<input id="sm2publicKey">' : 'Course',
              'wlkcid': 'course',
            },
          ],
        }),
      );
    }
    if (path.endsWith('/kjxxbByWlkcidAndSizeForStudent')) {
      return reply(
        jsonEncode({
          'result': 'success',
          'object': [
            {
              'kjxxid': 'material',
              'wlkcid': 'course',
              'wjid': 'file',
              'bt': quoteLoginMarkup ? '<input id="sm2publicKey">' : 'File',
            },
          ],
        }),
        materialStatus,
      );
    }
    if (path.endsWith('/zyListWj')) {
      return reply(
        '{"result":"success","object":{"iTotalRecords":0,"aaData":[]}}',
      );
    }
    // The SM2 curve generator is a valid synthetic public key; no real key or
    // account is used by this end-to-end credential recovery fixture.
    const publicKey =
        '0432c4ae2c1f1981195f9904466a39c9948fe30bbff2660be1715a4589334c74c7'
        'bc3736a2f4f6779c59bdcee36b692153d0a9877cc62a474002df32e52139f0a0';
    if (path == '/login' || path.startsWith('/do/off/ui/auth/login/form/')) {
      return reply('<span id="sm2publicKey">$publicKey</span>');
    }
    if (path == '/do/off/ui/auth/login/check') {
      credentialPosts++;
      expect(request.bodyFields['i_user'], '1234567890');
      expect(request.bodyFields['fingerGenPrint'], 'trusted-token');
      _signedIn = true;
      return reply(
        '<a href="https://id.tsinghua.edu.cn/callback">登录成功。正在重定向到</a>',
      );
    }
    if (path == '/callback' || path == '/lb-auth/lbredirect') return reply('');
    throw StateError('Unexpected synthetic request: $path');
  }
}

final class _Store implements AuthSessionStore, AuthCredentialStore {
  AuthSession? session = const AuthSession(
    userId: '1234567890',
    fingerprint: 'device',
    cookies: {},
    trustedBrowser: true,
    fingerGenPrint: 'trusted-token',
  );
  int credentialReads = 0;
  int clears = 0;
  AuthCredentials credentials = const AuthCredentials(
    userId: '1234567890',
    password: 'synthetic-password',
  );
  @override
  Future<AuthSession?> read() async => session;
  @override
  Future<void> write(AuthSession value) async => session = value;
  @override
  Future<void> clear() async {
    clears++;
    session = null;
  }

  @override
  Future<AuthCredentials?> readCredentials() async {
    credentialReads++;
    return credentials;
  }

  @override
  Future<void> writeCredentials(AuthCredentials value) async =>
      credentials = value;
  @override
  Future<void> clearCredentials() async {}
}
