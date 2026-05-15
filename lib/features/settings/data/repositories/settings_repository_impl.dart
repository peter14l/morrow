import 'package:oasis/core/result/result.dart';
import 'package:oasis/features/settings/domain/models/user_settings_entity.dart';
import 'package:oasis/features/settings/domain/repositories/settings_repository.dart';
import 'package:oasis/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:oasis/features/settings/data/datasources/settings_remote_datasource.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDatasource _localDatasource;
  final SettingsRemoteDatasource _remoteDatasource;

  SettingsRepositoryImpl({
    SettingsLocalDatasource? localDatasource,
    SettingsRemoteDatasource? remoteDatasource,
  }) : _localDatasource = localDatasource ?? SettingsLocalDatasource(),
       _remoteDatasource = remoteDatasource ?? SettingsRemoteDatasource();

  @override
  Future<Result<UserSettingsEntity>> getSettings() async {
    try {
      // First try remote if possible (for cross-device sync on login)
      final remoteSettings = await _remoteDatasource.fetchSettings();
      if (remoteSettings != null) {
        await _localDatasource.saveSettings(remoteSettings);
        return Result.success(remoteSettings);
      }

      final settings = await _localDatasource.getSettings();
      return Result.success(settings);
    } catch (e, stackTrace) {
      return Result.failure(
        message: e.toString(),
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Result<bool>> saveSettings(UserSettingsEntity settings) async {
    try {
      final success = await _localDatasource.saveSettings(settings);
      // Automatically trigger a sync when saving locally
      await _remoteDatasource.syncSettings(settings);
      return Result.success(success);
    } catch (e, stackTrace) {
      return Result.failure(
        message: e.toString(),
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Result<bool>> syncSettings(UserSettingsEntity settings) async {
    try {
      final success = await _remoteDatasource.syncSettings(settings);
      return Result.success(success);
    } catch (e, stackTrace) {
      return Result.failure(
        message: e.toString(),
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }
}
