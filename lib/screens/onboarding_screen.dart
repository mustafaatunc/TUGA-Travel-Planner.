import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _content = [
    {
      'image': 'assets/images/onboarding_explore.png',
      'title': 'Dünyayı Keşfet',
      'description':
          'Yapay zeka destekli rotalarla hayalindeki tatili planlamaya başla. Yeni yerler seni bekliyor.',
    },
    {
      'image': 'assets/images/onboarding_ai_plan.png',
      'title': 'Akıllı Planlama',
      'description':
          'Sadece tarihleri ve bütçeni gir, gerisini yapay zekaya bırak. Saniyeler içinde sana özel plan hazır.',
    },
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF000428), Color(0xFF004e92)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ÜST BAR
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/ic_foreground.png',
                          height: 30,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.travel_explore,
                                color: Colors.white,
                              ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "TUGA",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),

                    // Atla Butonu
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: const Text(
                        "Atla",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),

              //(SAYFALAR)
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _content.length,
                  onPageChanged: (int index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return OnboardingPage(
                      image: _content[index]['image']!,
                      title: _content[index]['title']!,
                      description: _content[index]['description']!,
                    );
                  },
                ),
              ),

              // ALT BAR
              Padding(
                padding: const EdgeInsets.all(30.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(
                        _content.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 8),
                          height: 10,
                          width: _currentPage == index ? 30 : 10,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? const Color(0xFFff7e5f)
                                : Colors.white54,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),

                    ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _content.length - 1) {
                          _completeOnboarding();
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFff7e5f),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                        elevation: 5,
                      ),
                      child: Text(
                        _currentPage == _content.length - 1 ? "Başla" : "İleri",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final String image;
  final String title;
  final String description;

  const OnboardingPage({
    super.key,
    required this.image,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // RESİM ALANI
          Expanded(
            flex: 3,
            child: FadeInDown(
              duration: const Duration(milliseconds: 800),
              child: Container(
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 20),
                child: Image.asset(
                  image,
                  width: double.infinity,
                  fit: BoxFit.contain,

                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.image_not_supported_outlined,
                      size: 100,
                      color: Colors.white24,
                    );
                  },
                ),
              ),
            ),
          ),

          // YAZI ALANI
          Expanded(
            flex: 2,
            child: FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
