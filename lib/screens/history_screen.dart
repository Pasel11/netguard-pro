import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../providers/history_provider.dart';
import '../utils/theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final historyProvider = Provider.of<HistoryProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('history.title')),
        actions: [
          if (historyProvider.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => _showClearDialog(context, loc, historyProvider),
            ),
        ],
      ),
      body: historyProvider.items.isEmpty
          ? _buildEmptyState(loc)
          : _buildHistoryList(loc, historyProvider),
    );
  }
  
  Widget _buildEmptyState(AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: AppTheme.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            loc.t('history.empty'),
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            loc.t('history.empty_desc'),
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildHistoryList(AppLocalizations loc, HistoryProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.items.length,
      itemBuilder: (context, index) {
        final item = provider.items[index];
        return _buildHistoryCard(item, loc);
      },
    );
  }
  
  Widget _buildHistoryCard(ScanHistoryItem item, AppLocalizations loc) {
    final typeIcons = {
      'port': Icons.lock,
      'wps': Icons.calculate,
      'password': Icons.key,
      'cve': Icons.bug_report,
      'router': Icons.router,
      'signal': Icons.wifi,
    };
    
    final typeNames = {
      'port': loc.t('nav.ports'),
      'wps': loc.t('nav.wps'),
      'password': loc.t('nav.password'),
      'cve': loc.t('nav.cve'),
      'router': loc.t('nav.router'),
      'signal': loc.t('nav.signal'),
    };
    
    final icon = typeIcons[item.type] ?? Icons.history;
    final typeName = typeNames[item.type] ?? item.type;
    final scoreColor = AppTheme.getScoreColor(item.score);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scoreColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: scoreColor),
        ),
        title: Row(
          children: [
            Text(
              typeName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: scoreColor),
              ),
              child: Text(
                '${item.score}',
                style: TextStyle(
                  color: scoreColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              item.target,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('yyyy-MM-dd HH:mm').format(item.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            // TODO: عرض التفاصيل
          },
        ),
        onTap: () {
          // TODO: عرض التفاصيل
        },
      ),
    );
  }
  
  void _showClearDialog(BuildContext context, AppLocalizations loc, HistoryProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t('settings.clear_history')),
        content: Text(loc.t('settings.clear_history_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.t('common.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              provider.clearHistory();
              Navigator.pop(context);
            },
            child: Text(loc.t('common.confirm')),
          ),
        ],
      ),
    );
  }
}
