import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_data.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import 'sign_in_screen.dart';

class UserInfoScreen extends StatefulWidget {
  final UserData? userData;

  const UserInfoScreen({super.key, this.userData});

  @override
  UserInfoScreenState createState() => UserInfoScreenState();
}

class UserInfoScreenState extends State<UserInfoScreen> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _signOut(BuildContext context) async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => SignInScreen()),
      (route) => false,
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPasswordField(
                  _currentPasswordController, 'Current Password'),
              SizedBox(height: 16),
              _buildPasswordField(_newPasswordController, 'New Password'),
              SizedBox(height: 16),
              _buildPasswordField(
                  _confirmPasswordController, 'Confirm New Password'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_currentPasswordController.text.isEmpty ||
                  _newPasswordController.text.isEmpty ||
                  _confirmPasswordController.text.isEmpty) {
                _showError('All fields are required');
                return;
              }

              if (_newPasswordController.text !=
                  _confirmPasswordController.text) {
                _showError('New passwords don\'t match');
                return;
              }

              if (_newPasswordController.text.length < 6) {
                _showError('Password must be at least 6 characters');
                return;
              }

              try {
                await FirebaseService().reauthenticateAndChangePassword(
                  currentPassword: _currentPasswordController.text.trim(),
                  newPassword: _newPasswordController.text.trim(),
                );
                Navigator.pop(context);
                _clearFields();
                _showSnack('Password changed successfully');
              } catch (_) {
                _showError('Failed to change password');
              }
            },
            child: Text('Change Password'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration:
          InputDecoration(labelText: label, border: OutlineInputBorder()),
    );
  }

  void _clearFields() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSupportContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Support Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContactRow(Icons.email, 'Email', 'support@sightline.com'),
            SizedBox(height: 16),
            _buildContactRow(Icons.phone, 'Phone', '+1 (123) 456-7890'),
            SizedBox(height: 16),
            _buildContactRow(Icons.chat, 'Live Chat', 'Available 9am–5pm EST'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Close'))
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            Text(value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, color: isDark ? Colors.purple : Colors.blue, size: 24),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600])),
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = widget.userData;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person,
                  size: 30, color: isDark ? Colors.purple : Colors.blue),
              SizedBox(width: 8),
              Text('User Profile',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.blueGrey[800])),
            ],
          ),
          SizedBox(height: 20),
          if (user != null)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.email, 'Email', user.email),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _showChangePasswordDialog,
                      icon: Icon(Icons.lock_outline),
                      label: Text('Change Password'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.purple : Colors.blue,
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No user data available',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
              ),
            ),
          SizedBox(height: 24),
          Text('Support',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.blueGrey[800])),
          SizedBox(height: 12),
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: _showSupportContactDialog,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.support_agent,
                        size: 24, color: isDark ? Colors.purple : Colors.blue),
                    SizedBox(width: 16),
                    Text('Contact Support',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    Spacer(),
                    Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 30),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _signOut(context),
              icon: Icon(Icons.logout),
              label: Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
