import 'package:flutter/material.dart';

class AuthLayout extends StatelessWidget {
  final Widget child;
  final bool showLogo;

  const AuthLayout({
    super.key,
    required this.child,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Màu nền hơi xám nhẹ giống thiết kế
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  // Phần Logo (Chiếm không gian trống phía trên)
                  Expanded(
                    child: showLogo
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.apartment,
                                  size: 64,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'ROOMIO',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).primaryColor,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(),
                  ),
                  
                  // Phần Form (Container bo góc phía dưới)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                    child: child,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
