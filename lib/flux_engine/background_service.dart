import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'podcast_service.dart';
import 'notification_service.dart';
import '../flux_ui/models/podcast.dart';

class BackgroundService {
  static const int _podcastCheckAlarmId = 999;

  static Future<void> schedulePodcastChecks() async {
    await AndroidAlarmManager.periodic(
      const Duration(hours: 6),
      _podcastCheckAlarmId,
      checkNewPodcastsTask,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
    );
  }

  @pragma('vm:entry-point')
  static Future<void> checkNewPodcastsTask() async {
    // This runs in a background isolate
    debugPrint('BACKGROUND_TASK: Checking for new podcast episodes');
    
    try {
      // Initialize Hive in the background isolate
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(PodcastAdapter());
      
      final followedBox = await Hive.openBox<Podcast>('followed_podcasts');
      final podcasts = followedBox.values.toList();
      
      if (podcasts.isEmpty) {
        debugPrint('BACKGROUND_TASK: No followed podcasts found');
        return;
      }

      final podcastService = PodcastService();
      await podcastService.init();
      
      final notificationService = NotificationService();
      await notificationService.init();

      for (var i = 0; i < podcasts.length; i++) {
        final podcast = podcasts[i];
        if (podcast.rss.isEmpty || !podcast.notificationsEnabled) {
          debugPrint('BACKGROUND_TASK: Skipping ${podcast.title} (RSS empty or notifications disabled)');
          continue;
        }

        final newCount = await podcastService.checkNewEpisodes(podcast.rss);
        if (newCount > 0) {
          debugPrint('BACKGROUND_TASK: Found $newCount new episodes for ${podcast.title}');
          await notificationService.showNewEpisodeNotification(
            id: podcast.id.hashCode,
            podcastTitle: podcast.title,
            episodeCount: newCount,
          );
        }
      }
    } catch (e) {
      debugPrint('BACKGROUND_TASK: Error - $e');
    }
  }
}
