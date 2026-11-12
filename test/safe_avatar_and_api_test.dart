import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connekt/config/api_config.dart';
import 'package:connekt/models/user_model.dart';
import 'package:connekt/services/api_service.dart';
import 'package:connekt/widgets/safe_avatar.dart';

void main() {
  group('Avatar URL resolution', () {
    setUp(() {
      ApiConfig.currentHost = '192.168.29.98:5000';
    });

    test('resolves relative backend upload paths against ApiConfig.rootUrl', () {
      expect(
        resolveAvatarUrl('/uploads/avatars/avatar-123.jpg'),
        'http://192.168.29.98:5000/uploads/avatars/avatar-123.jpg',
      );
      expect(
        resolveAvatarUrl('uploads/avatars/avatar-456.png'),
        'http://192.168.29.98:5000/uploads/avatars/avatar-456.png',
      );
    });

    test('supports HTTPS tunnel hosts and rejects invalid URLs', () {
      ApiConfig.currentHost = 'https://tame-paws-smell.loca.lt';
      expect(
        resolveAvatarUrl('/uploads/avatars/a.webp'),
        'https://tame-paws-smell.loca.lt/uploads/avatars/a.webp',
      );
      expect(
        resolveAvatarUrl('https://cdn.example.com/avatar.png'),
        'https://cdn.example.com/avatar.png',
      );
      expect(resolveAvatarUrl(null), isNull);
      expect(resolveAvatarUrl(''), isNull);
      expect(resolveAvatarUrl('not-a-valid-path'), isNull);
      expect(resolveAvatarUrl('file:///tmp/photo.png'), isNull);
    });
  });

  group('ApiService.logout & UserModel.copyWith', () {
    test('clears stored token and cached user immediately even when server is unreachable', () async {
      ApiConfig.currentHost = '127.0.0.1:59999';
      SharedPreferences.setMockInitialValues({
        'connekt_jwt_token': 'test-jwt-token',
        'connekt_cached_user': '{"id":"u1","username":"koushiki","email":"k@connekt.me","phone":"9999999999","current_mode":"common","role":"user"}',
      });

      expect(await ApiService.getToken(), 'test-jwt-token');
      expect(await ApiService.getCachedUser(), isNotNull);

      await ApiService.logout(timeout: const Duration(milliseconds: 200));

      expect(await ApiService.getToken(), isNull);
      expect(await ApiService.getCachedUser(), isNull);
    });

    test('copyWith updates PersonalProfile avatarUrl immutably', () {
      final original = UserModel(
        id: 'u1',
        phone: '1234567890',
        username: 'kou12',
        email: 'kou12@connekt.me',
        currentMode: 'common',
        role: 'user',
        personalProfile: PersonalProfile(
          fullName: 'Koushiki',
          displayName: 'Koushiki',
          avatarUrl: '',
          bio: 'Bio',
          location: 'Kolkata',
          website: '',
        ),
      );

      final updated = original.copyWith(
        personalProfile: original.personalProfile!.copyWith(
          avatarUrl: '/uploads/avatars/new.png',
        ),
      );

      expect(original.personalProfile!.avatarUrl, '');
      expect(updated.personalProfile!.avatarUrl, '/uploads/avatars/new.png');
      expect(updated.username, 'kou12');
    });
  });
}
