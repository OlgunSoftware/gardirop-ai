// screens/settings_screen.dart
import 'package:combiner_ai/models/clothing_item.dart';
import 'package:flutter/material.dart';

import '../services/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  // Ayar değişkenleri
  bool _notificationsEnabled = true;
  bool _autoBackupEnabled = false;
  bool _removeBackgroundEnabled = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    // SharedPreferences'dan ayarları yükle (opsiyonel)
    // Bu örnek için varsayılan değerler kullanıyoruz
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF2a6a73),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tüm Verileri Sil'),
        content: const Text(
          'Bu işlem tüm kıyafetlerinizi, kombinlerinizi ve favorilerinizi silecek. Bu işlem geri alınamaz. Emin misiniz?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _databaseHelper.deleteDatabase();
        _showSnackBar('Tüm veriler başarıyla silindi', isError: false);
      } catch (e) {
        _showSnackBar('Veriler silinirken hata oluştu: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Ayarlar',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profil Bilgileri
          
          const SizedBox(height: 20),

          // Uygulama Ayarları
          _buildSettingsSection(),
          const SizedBox(height: 20),

          // Veri Yönetimi
          _buildDataSection(),
          const SizedBox(height: 20),

          // Hakkında
          _buildAboutSection(),
        ],
      ),
    );
  }

  
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2a6a73),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Sabit renk
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Uygulama Ayarları',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          
          _buildSwitchTile(
            icon: Icons.notifications_outlined,
            title: 'Bildirimler',
            subtitle: 'Yeni özellikler hakkında bildirim al',
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          
          _buildSwitchTile(
            icon: Icons.auto_fix_high_outlined,
            title: 'Otomatik Optimizasyon',
            subtitle: 'Resimleri otomatik optimize et',
            value: _removeBackgroundEnabled,
            onChanged: (value) {
              setState(() {
                _removeBackgroundEnabled = value;
              });
            },
          ),
          
          _buildSwitchTile(
            icon: Icons.backup_outlined,
            title: 'Otomatik Yedekleme',
            subtitle: 'Verilerini otomatik yedekle',
            value: _autoBackupEnabled,
            onChanged: (value) {
              setState(() {
                _autoBackupEnabled = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Sabit renk
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Veri Yönetimi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          
          _buildActionTile(
            icon: Icons.refresh_outlined,
            title: 'Önbelleği Temizle',
            subtitle: 'Geçici dosyaları sil',
            onTap: () {
              _showSnackBar('Önbellek temizlendi');
            },
          ),
          
          _buildActionTile(
            icon: Icons.delete_forever_outlined,
            title: 'Tüm Verileri Sil',
            subtitle: 'Tüm kıyafetleri ve ayarları sil',
            onTap: _clearAllData,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Sabit renk
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Hakkında',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          
          _buildActionTile(
            icon: Icons.help_outline,
            title: 'Yardım ve Destek',
            subtitle: 'SSS ve kullanım kılavuzu',
            onTap: () {
              _showSnackBar('Yardım sayfası açılacak');
            },
          ),
          
          _buildActionTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Gizlilik Politikası',
            subtitle: 'Veri kullanım şartları',
            onTap: () {
              _showSnackBar('Gizlilik politikası açılacak');
            },
          ),
          
          _buildActionTile(
            icon: Icons.info_outline,
            title: 'Uygulama Hakkında',
            subtitle: 'Versiyon 1.0.0',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Kıyafet Kombini',
                applicationVersion: '1.0.0',
                applicationIcon: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2a6a73),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.checkroom_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                children: [
                  const Text('Kıyafetlerinizi organize edin ve kombinler oluşturun.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2a6a73).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF2a6a73),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF2a6a73),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive 
              ? Colors.red.withOpacity(0.1)
              : const Color(0xFF2a6a73).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : const Color(0xFF2a6a73),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: isDestructive ? Colors.red : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey[400],
      ),
      onTap: onTap,
    );
  }
}