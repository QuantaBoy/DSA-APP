import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/models.dart';
import 'add_problem_page.dart';
import 'sheet_page.dart';
import 'stack_page.dart';

/// Signed-in shell: bottom tabs for the A2Z sheet and your review stack.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.user});

  final User user;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final store = Store(widget.user.uid);
  late final Stream<List<Problem>> _problems = store.problems();
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Problem>>(
      stream: _problems,
      builder: (context, snapshot) {
        final problems = snapshot.data;
        final Widget body;
        if (snapshot.hasError) {
          body = Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Could not load your data.\n${snapshot.error}', textAlign: TextAlign.center)));
        } else if (problems == null) {
          body = const Center(child: CircularProgressIndicator());
        } else {
          body = _tab == 0 ? SheetPage(store: store, problems: problems) : StackPage(store: store, problems: problems);
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(_tab == 0 ? 'Striver A2Z Sheet' : 'My stack'),
            actions: [
              IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
            ],
          ),
          body: body,
          floatingActionButton: _tab == 1
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddProblemPage(store: store))),
                  icon: const Icon(Icons.add),
                  label: const Text('Add other problem'),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'A2Z Sheet'),
              NavigationDestination(icon: Icon(Icons.layers_outlined), selectedIcon: Icon(Icons.layers), label: 'My stack'),
            ],
          ),
        );
      },
    );
  }
}
