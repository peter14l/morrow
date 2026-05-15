import 'package:oasis/core/result/result.dart';
import 'package:oasis/features/settings/domain/models/user_settings_entity.dart';

abstract class SettingsRepository {
  Future<Result<UserSettingsEntity>> getSettings();

  Future<Result<bool>> saveSettings(UserSettingsEntity settings);

  Future<Result<bool>> syncSettings(UserSettingsEntity settings);
}
