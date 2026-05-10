import 'package:flutter/material.dart';
import '../manager/manager_data.dart';
import '../theme/app_colors.dart';
import '../widgets/hover_interaction.dart';
import 'table_selection_screen.dart';

/// Waiter Selection Screen - displays list of waiters for NAME mode login.
/// Waiters click their name to access their tables.
class WaiterSelectionScreen extends StatefulWidget {
  const WaiterSelectionScreen({super.key});

  @override
  State<WaiterSelectionScreen> createState() => _WaiterSelectionScreenState();
}

class _WaiterSelectionScreenState extends State<WaiterSelectionScreen> {
  final ManagerData _m = ManagerData.instance;

  @override
  void initState() {
    super.initState();
    _m.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _m.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    setState(() {});
  }

  void _selectWaiter(String waiterName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TableSelectionScreen(waiterName: waiterName),
      ),
    );
  }

  void _backToLogin() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final waiters = _m.waiters;

    return Scaffold(
      backgroundColor: AppColors.beige,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        title: const Text('Select Waiter'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _backToLogin,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Welcome! Please select your name',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGreenText,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: waiters.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.person_outline,
                            size: 64,
                            color: AppColors.primaryGreen,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No waiters found',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.0,
                          ),
                      itemCount: waiters.length,
                      itemBuilder: (context, index) {
                        final waiter = waiters[index];
                        return _buildWaiterButton(
                          name: waiter.name,
                          onTap: () => _selectWaiter(waiter.name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaiterButton({
    required String name,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primaryGreen, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person, size: 48, color: AppColors.primaryGreen),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGreenText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
