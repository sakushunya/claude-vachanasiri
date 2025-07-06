import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shunya_vachanasiri/providers/app_state.dart';
import 'package:shunya_vachanasiri/screens/sharanas_page.dart';
import 'package:shunya_vachanasiri/screens/login_page.dart';
import 'package:shunya_vachanasiri/screens/all_vachanas_page.dart';
import 'package:shunya_vachanasiri/utils/main_layout.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  // int _currentIndex = 4; // About page is selected by default (index 4)

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    // final audioService =
    //     Provider.of<AudioPlayerService>(context, listen: false);

    // bool isLoggedIn = appState.isLoggedIn;
    // String? phoneNumber = appState.phoneNumber;
    return Scaffold(
      backgroundColor: Colors.black,
      body: MainLayout(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/ShunyaSunset.webp',
                        height: 170,
                        width: 380,
                        fit: BoxFit.fill,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Vachanasiri',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Greetings section
                if (appState.isLoggedIn && appState.phoneNumber != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Greetings,',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        appState.phoneNumber!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    'Greetings,',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),

                const SizedBox(height: 10),
                const Divider(color: Colors.grey),
                const SizedBox(height: 10),

                // Mission section
                const Center(
                  child: Text(
                    'Support Our Mission to Preserve 12th-Century Vachanas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Mission description
                const Text(
                  'Shunya Organisation is dedicated to preserving the timeless wisdom of 12th-century vachanas by digitizing them for future generations.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'By supporting this project, you help us preserve, share, and pass on this treasure to future generations. Your donation, no matter the amount, ensures that these vachanas remain accessible to all, and forever.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Join us in this noble cause. Contribute today and be a part of history!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                // Donate section with button
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      // Handle donation
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          // elevation: 5,
                          // shadowColor: Colors.blue[900],
                        )),
                    child: const Text(
                      'Donate Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // About Shunya Organisation card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // "About Shunya Organisation" as a link
                      InkWell(
                        onTap: () {
                          // Navigate to detailed about page
                          // Placeholder for now - we'll build this later
                        },
                        child: const Text(
                          'About Shunya Organisation',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'Shunya Organisation is a non-profit initiative dedicated to preserving and promoting the cultural heritage of 12th-century Vachana literature. Our mission is to digitize, translate, and make these profound spiritual teachings accessible to all.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Login/Logout button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: appState.isLoggedIn
                              ? () {
                                  // appState.logout();
                                  Navigator.pop(context);
                                }
                              : () {
                                  // Navigate to login page using MaterialPageRoute
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const LoginPage(), // Update with your actual login page
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appState.isLoggedIn
                                ? Colors.blue[800]
                                : Colors.grey[700],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            appState.isLoggedIn ? 'Logout' : 'Login with Phone',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
      // New bottom navigation bar with 5 items
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          border: const Border(top: BorderSide(color: Colors.grey, width: 0.5)),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.blue[300],
          unselectedItemColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          // currentIndex: _currentIndex,
          // onTap: _onBottomNavTap,
          items: [
            // Sharanas button
            const BottomNavigationBarItem(
              icon: Icon(Icons.account_circle),
              label: 'Sharanas',
            ),
            // All Vachanas button
            const BottomNavigationBarItem(
              icon: Icon(Icons.library_books),
              label: 'All Vachanas',
            ),
            // Audio playback center button
            BottomNavigationBarItem(
              icon: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.blue[800],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.keyboard_command_key_rounded,
                    color: Colors.white),
              ),
              label: '',
            ),
            // Favorites button (conditionally enabled)
            BottomNavigationBarItem(
              icon: Icon(
                Icons.favorite,
                color: appState.isLoggedIn ? Colors.white70 : Colors.grey[600],
              ),
              label: 'Favorites',
            ),
            // About button
            const BottomNavigationBarItem(
              icon: Icon(Icons.info),
              label: 'About',
            ),
          ],
          currentIndex: 4,
          onTap: (index) {
            // Add this to prevent duplicate players
            if (index == 4) return;
            _onBottomNavTap(index);
          },
        ),
      ),
    );
  }

  // _onBottomNavTap
  void _onBottomNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SharanasPage(),
          ),
        );

      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AllVachanasPage(),
          ),
        );
    }
  }
}
