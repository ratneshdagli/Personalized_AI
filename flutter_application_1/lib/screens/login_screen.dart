import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _userIdController = TextEditingController(text: '1');
  bool _isLoading = false;
  Map<String, bool> _connectorStatus = {};

  @override
  void initState() {
    super.initState();
    _loadConnectorStatus();
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _loadConnectorStatus() async {
    final connectors = ['gmail', 'whatsapp', 'news', 'reddit'];
    Map<String, bool> status = {};
    
    for (String connector in connectors) {
      final isAuth = await _authService.isConnectorAuthenticated(connector);
      status[connector] = isAuth;
    }
    
    setState(() {
      _connectorStatus = status;
    });
  }

  Future<void> _handleGmailAuth() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = int.tryParse(_userIdController.text) ?? 1;
      final authUrl = await _authService.getGmailAuthUrl(userId);
      
      if (authUrl != null) {
        final launched = await _authService.launchOAuthUrl(authUrl);
        
        if (launched) {
          _showAuthDialog('Gmail', authUrl);
        } else {
          _showErrorSnackBar('Failed to launch Gmail authentication');
        }
      } else {
        _showErrorSnackBar('Failed to get Gmail authentication URL');
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleConnectorToggle(String connectorType) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = int.tryParse(_userIdController.text) ?? 1;
      final isCurrentlyEnabled = _connectorStatus[connectorType] ?? false;
      
      bool success;
      if (isCurrentlyEnabled) {
        success = await _authService.disableConnector(connectorType, userId);
      } else {
        success = await _authService.enableConnector(connectorType, userId);
      }
      
      if (success) {
        await _loadConnectorStatus();
        _showSuccessSnackBar(
          '${connectorType.toUpperCase()} ${isCurrentlyEnabled ? 'disabled' : 'enabled'}'
        );
      } else {
        _showErrorSnackBar('Failed to ${isCurrentlyEnabled ? 'disable' : 'enable'} $connectorType');
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAuthDialog(String connectorType, String authUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$connectorType Authentication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Complete authentication in your browser, then return to this app.'),
            const SizedBox(height: 16),
            Text(
              'Auth URL:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SelectableText(
              authUrl,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connector Setup'),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User ID Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User ID',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _userIdController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        hintText: 'Enter your user ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 300.ms).moveY(begin: 8, end: 0),
            
            const SizedBox(height: 24),
            
            // Connector Cards
            Text(
              'Data Sources',
              style: Theme.of(context).textTheme.headlineSmall,
            ).animate().fadeIn(duration: 300.ms).moveY(begin: 8, end: 0),
            const SizedBox(height: 16),
            
            Expanded(
              child: ListView(
                children: [
                  _buildConnectorCard(
                    'Gmail',
                    'Connect your Gmail account to process emails',
                    PhosphorIconsBold.envelopeSimple,
                    'gmail',
                    onAuthTap: _handleGmailAuth,
                  ),
                  _buildConnectorCard(
                    'WhatsApp',
                    'Process WhatsApp chat exports and notifications',
                    PhosphorIconsBold.whatsappLogo,
                    'whatsapp',
                  ),
                  _buildConnectorCard(
                    'News',
                    'Get personalized news from RSS feeds and APIs',
                    PhosphorIconsBold.newspaper,
                    'news',
                  ),
                  _buildConnectorCard(
                    'Reddit',
                    'Monitor Reddit posts from your subscribed subreddits',
                    PhosphorIconsBold.redditLogo,
                    'reddit',
                  ),
                ],
              ),
            ),
            
            // Clear All Button
            if (_connectorStatus.values.any((enabled) => enabled))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _clearAllConnections,
                  icon: const Icon(PhosphorIconsBold.broom),
                  label: const Text('Clear All Connections'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectorCard(
    String title,
    String description,
    IconData icon,
    String connectorType, {
    VoidCallback? onAuthTap,
  }) {
    final isEnabled = _connectorStatus[connectorType] ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: isEnabled ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  onChanged: _isLoading ? null : (_) => _handleConnectorToggle(connectorType),
                ),
              ],
            ),
            
            if (connectorType == 'gmail' && !isEnabled) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : onAuthTap,
                  icon: const Icon(PhosphorIconsBold.arrowSquareOut),
                  label: const Text('Authenticate with Gmail'),
                ),
              ),
            ],
            
            if (isEnabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    PhosphorIconsFill.checkCircle,
                    size: 16,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Connected',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).moveY(begin: 8, end: 0);
  }

  Future<void> _clearAllConnections() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Connections'),
        content: const Text(
          'This will disconnect all data sources. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.clearAllAuth();
      await _loadConnectorStatus();
      _showSuccessSnackBar('All connections cleared');
    }
  }
}
