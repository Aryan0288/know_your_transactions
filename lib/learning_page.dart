import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:know_your_expenses/riverpod_learn.dart';

/*class LearningPage extends ConsumerWidget {
  const LearningPage({super.key});

  @override
  Widget build(BuildContext context,WidgetRef ref) {
    final txt = ref.watch(name);
    return Scaffold(
      body: SafeArea(
          child: Center(
            child: Text(txt),
          )
      ),
    );
  }
}*/

/// for StateProvider

class LearningPage extends ConsumerWidget {
  const LearningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print("build");
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Consumer(
              builder: (context, ref, child) {
                final count = ref.watch(counter);
                print("build-2");
                return Text(count.toString(), style: TextStyle(fontSize: 28));
              },
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                ref.read(counter.notifier).state++;
              },
              child: Text("+"),
            ),
            SizedBox(height: 12),
            Consumer(
              builder: (context, ref, child) {
                final count = ref.watch(counter1);
                print("build-3");
                return Text(count.toString(), style: TextStyle(fontSize: 28));
              },
            ),

            SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                ref.read(counter1.notifier).state++;
              },
              child: Text("++"),
            ),
          ],
        ),
      ),
    );
  }
}
