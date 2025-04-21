import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  late bool _isDarkTheme;
  late bool _notificationsEnabled;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final prefs = auth.currentUser?.preferences ?? {};
    _isDarkTheme = prefs['darkMode'] ?? false;
    _notificationsEnabled = prefs['notifications'] ?? true;

    isDarkThemeNotifier.value = _isDarkTheme;

    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initSettings);
  }

  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'channel_id',
      'Dyslexia Helper Notifications',
      channelDescription: 'Notifications for Dyslexia Helper app',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      0,
      'Dyslexia Helper',
      'This is a test notification!',
      notificationDetails,
    );
  }

  void _onDarkModeChanged(bool value, AuthProvider auth) async {
    await auth.setDarkMode(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: isDark ? Colors.black : Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: isDark ? Colors.black : null,
        padding: EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Row(
              children: [
                Icon(Icons.settings,
                    size: 30, color: isDark ? Colors.purple : Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.blueGrey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            _buildSwitchCard(
              title: 'Dark Theme',
              subtitle: 'Enable dark mode for the app',
              value: _isDarkTheme,
              onChanged: (value) async {
                setState(() {
                  _isDarkTheme = value;
                  isDarkThemeNotifier.value = value;
                });
                _onDarkModeChanged(value, auth);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Dark Theme: ${value ? 'On' : 'Off'}')),
                );
              },
              icon: Icons.brightness_6,
              isDark: isDark,
            ),
            _buildSwitchCard(
              title: 'Notifications',
              subtitle: 'Receive app notifications',
              value: _notificationsEnabled,
              onChanged: (value) async {
                setState(() {
                  _notificationsEnabled = value;
                });

                if (value) _showNotification();

                final newPrefs = {
                  ...auth.currentUser!.preferences,
                  'notifications': value,
                };
                await auth.setDarkMode(value);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Notifications: ${value ? 'On' : 'Off'}')),
                );
              },
              icon: Icons.notifications,
              isDark: isDark,
            ),
            SizedBox(height: 20),
            Card(
              elevation: 4,
              color: isDark ? Colors.black : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isDark
                    ? BorderSide(
                        color: Colors.purple.withOpacity(0.5), width: 1)
                    : BorderSide.none,
              ),
              child: ListTile(
                leading: Icon(Icons.info,
                    color: isDark ? Colors.purple : Colors.blue),
                title: Text('About Dyslexia Helper',
                    style: TextStyle(color: isDark ? Colors.white : null)),
                subtitle: Text(
                  'Version 1.0.0\nA tool to assist with dyslexia support.',
                  style: TextStyle(color: isDark ? Colors.white70 : null),
                ),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Dyslexia Helper',
                    applicationVersion: '1.0.0',
                    applicationLegalese: ' 2025 xAI',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
    required bool isDark,
  }) {
    return Card(
      elevation: 4,
      color: isDark ? Colors.black : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark
            ? BorderSide(color: Colors.purple.withOpacity(0.5), width: 1)
            : BorderSide.none,
      ),
      child: SwitchListTile(
        title:
            Text(title, style: TextStyle(color: isDark ? Colors.white : null)),
        subtitle: Text(subtitle,
            style: TextStyle(color: isDark ? Colors.white70 : null)),
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon, color: isDark ? Colors.purple : null),
        activeColor: isDark ? Colors.purple : Colors.blue,
      ),
    );
  }
}
