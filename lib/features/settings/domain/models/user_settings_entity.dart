import 'package:equatable/equatable.dart';
import 'package:oasis/models/feed_layout_strategy.dart';

enum LiquidGlassMode {
  disabled,
  fake,
  real,
}

class UserSettingsEntity extends Equatable {
  final bool dataSaver;
  final double fontSizeFactor;
  final bool highContrast;
  final int dailyLimitMinutes;
  final bool windDownEnabled;
  final bool micaEnabled;
  final String windowEffect;
  final String fontFamily;
  final FeedLayoutType feedLayout;
  final bool meshEnabled;
  final LiquidGlassMode liquidGlassMode;

  const UserSettingsEntity({
    this.dataSaver = false,
    this.fontSizeFactor = 1.0,
    this.highContrast = false,
    this.dailyLimitMinutes = 0,
    this.windDownEnabled = false,
    this.micaEnabled = false,
    this.windowEffect = 'mica',
    this.fontFamily = 'Inter',
    this.feedLayout = FeedLayoutType.classic,
    this.meshEnabled = true,
    this.liquidGlassMode = LiquidGlassMode.disabled,
  });

  UserSettingsEntity copyWith({
    bool? dataSaver,
    double? fontSizeFactor,
    bool? highContrast,
    int? dailyLimitMinutes,
    bool? windDownEnabled,
    bool? micaEnabled,
    String? windowEffect,
    String? fontFamily,
    FeedLayoutType? feedLayout,
    bool? meshEnabled,
    LiquidGlassMode? liquidGlassMode,
  }) {
    return UserSettingsEntity(
      dataSaver: dataSaver ?? this.dataSaver,
      fontSizeFactor: fontSizeFactor ?? this.fontSizeFactor,
      highContrast: highContrast ?? this.highContrast,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      windDownEnabled: windDownEnabled ?? this.windDownEnabled,
      micaEnabled: micaEnabled ?? this.micaEnabled,
      windowEffect: windowEffect ?? this.windowEffect,
      fontFamily: fontFamily ?? this.fontFamily,
      feedLayout: feedLayout ?? this.feedLayout,
      meshEnabled: meshEnabled ?? this.meshEnabled,
      liquidGlassMode: liquidGlassMode ?? this.liquidGlassMode,
    );
  }

  @override
  List<Object?> get props => [
    dataSaver,
    fontSizeFactor,
    highContrast,
    dailyLimitMinutes,
    windDownEnabled,
    micaEnabled,
    windowEffect,
    fontFamily,
    feedLayout,
    meshEnabled,
    liquidGlassMode,
  ];
}
