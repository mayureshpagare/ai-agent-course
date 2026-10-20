import 'package:agent_ui_mobile/core/utils/qr_link_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parsePairingLink', () {
    test('reads the address and token from a login URL', () {
      final link = parsePairingLink('http://192.168.1.20:8000/api/login?token=abc_DEF-123')!;
      expect(link.baseUrl.toString(), 'http://192.168.1.20:8000');
      expect(link.token, 'abc_DEF-123');
    });

    test('keeps a non-default port such as the Vite dev port', () {
      final link = parsePairingLink('  http://10.0.0.5:5173/api/login?token=t  ')!;
      expect(link.baseUrl.port, 5173);
      expect(link.baseUrl.host, '10.0.0.5');
    });

    test('decodes a percent-encoded token', () {
      expect(parsePairingLink('http://h:8000/api/login?token=a%2Bb')!.token, 'a+b');
    });

    test('supports IPv6 hosts', () {
      final link = parsePairingLink('http://[fe80::1]:8000/api/login?token=t')!;
      expect(link.baseUrl.host, 'fe80::1');
      expect(link.baseUrl.toString(), 'http://[fe80::1]:8000');
      expect(displayAddress(link.baseUrl), '[fe80::1]:8000');
    });

    test('supports host names and https with a path prefix', () {
      final link = parsePairingLink('https://my-pc.tail1234.ts.net/agents/api/login?token=t')!;
      expect(link.baseUrl.toString(), 'https://my-pc.tail1234.ts.net/agents');
    });

    test('rejects a link without a token', () {
      expect(parsePairingLink('http://192.168.1.20:8000/api/login'), isNull);
      expect(parsePairingLink('http://192.168.1.20:8000/api/login?token=  '), isNull);
    });

    test('rejects garbage and unrelated URLs', () {
      expect(parsePairingLink(''), isNull);
      expect(parsePairingLink('hello world'), isNull);
      expect(parsePairingLink('WIFI:S:home;T:WPA;P:secret;;'), isNull);
      expect(parsePairingLink('http://192.168.1.20:8000/other?token=t'), isNull);
      expect(parsePairingLink('ftp://h/api/login?token=t'), isNull);
    });
  });

  group('parseServerAddress', () {
    test('adds http and the default port', () {
      expect(parseServerAddress('192.168.1.20').toString(), 'http://192.168.1.20:8000');
    });

    test('keeps a typed port and scheme, and drops a trailing slash', () {
      expect(parseServerAddress('192.168.1.20:5173').toString(), 'http://192.168.1.20:5173');
      expect(parseServerAddress('http://my-pc.local:8000/').toString(), 'http://my-pc.local:8000');
      expect(parseServerAddress('https://pc.ts.net').toString(), 'https://pc.ts.net');
    });

    test('supports bracketed IPv6', () {
      expect(parseServerAddress('[fe80::1]:8000')!.host, 'fe80::1');
    });

    test('rejects invalid input', () {
      expect(parseServerAddress(''), isNull);
      expect(parseServerAddress('   '), isNull);
      expect(parseServerAddress('192.168.1.20:port'), isNull);
      expect(parseServerAddress('two words'), isNull);
      expect(parseServerAddress('ftp://h'), isNull);
      expect(parseServerAddress('http://h:8000/?token=x'), isNull);
    });
  });
}
