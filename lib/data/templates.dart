/// Starter programs that already read the input, so solving starts at the algorithm, not at parsing.
library;

/// The shape of a problem's input.
enum InputKind {
  number('Number', 'n'),
  array('Array', 'n, then n numbers'),
  string('String', 'one line'),
  matrix('Matrix', 'rows cols, then the grid');

  const InputKind(this.label, this.format);
  final String label;
  final String format;
}

/// Example input for each kind, filled into the first test case.
const sampleInput = {
  InputKind.number: '5',
  InputKind.array: '5\n3 1 4 1 5',
  InputKind.string: 'racecar',
  InputKind.matrix: '2 3\n1 2 3\n4 5 6',
};

/// A program in [language] that reads input of [kind] and prints it back, ready to replace with a solution.
String template(String language, InputKind kind) => switch ((language, kind)) {
  ('C++', InputKind.number) =>
    '''#include <bits/stdc++.h>
using namespace std;

int main() {
    long long n;
    cin >> n;
    // your solution
    cout << n << endl;
    return 0;
}
''',
  ('C++', InputKind.array) =>
    '''#include <bits/stdc++.h>
using namespace std;

int main() {
    int n;
    cin >> n;
    vector<long long> a(n);
    for (auto &x : a) cin >> x;
    // your solution
    for (auto x : a) cout << x << ' ';
    cout << endl;
    return 0;
}
''',
  ('C++', InputKind.string) =>
    '''#include <bits/stdc++.h>
using namespace std;

int main() {
    string s;
    getline(cin, s);
    // your solution
    cout << s << endl;
    return 0;
}
''',
  ('C++', InputKind.matrix) =>
    '''#include <bits/stdc++.h>
using namespace std;

int main() {
    int r, c;
    cin >> r >> c;
    vector<vector<long long>> g(r, vector<long long>(c));
    for (auto &row : g) for (auto &x : row) cin >> x;
    // your solution
    for (auto &row : g) { for (auto x : row) cout << x << ' '; cout << endl; }
    return 0;
}
''',
  ('Java', InputKind.number) =>
    '''import java.util.*;

public class Main {
    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);
        long n = in.nextLong();
        // your solution
        System.out.println(n);
    }
}
''',
  ('Java', InputKind.array) =>
    '''import java.util.*;

public class Main {
    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);
        int n = in.nextInt();
        long[] a = new long[n];
        for (int i = 0; i < n; i++) a[i] = in.nextLong();
        // your solution
        StringBuilder out = new StringBuilder();
        for (long x : a) out.append(x).append(' ');
        System.out.println(out.toString().trim());
    }
}
''',
  ('Java', InputKind.string) =>
    '''import java.util.*;

public class Main {
    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);
        String s = in.nextLine();
        // your solution
        System.out.println(s);
    }
}
''',
  ('Java', InputKind.matrix) =>
    '''import java.util.*;

public class Main {
    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);
        int r = in.nextInt(), c = in.nextInt();
        long[][] g = new long[r][c];
        for (int i = 0; i < r; i++) for (int j = 0; j < c; j++) g[i][j] = in.nextLong();
        // your solution
        for (long[] row : g) {
            StringBuilder line = new StringBuilder();
            for (long x : row) line.append(x).append(' ');
            System.out.println(line.toString().trim());
        }
    }
}
''',
  ('Python', InputKind.number) =>
    '''n = int(input())
# your solution
print(n)
''',
  ('Python', InputKind.array) =>
    '''n = int(input())
a = list(map(int, input().split()))
# your solution
print(*a)
''',
  ('Python', InputKind.string) =>
    '''s = input()
# your solution
print(s)
''',
  ('Python', InputKind.matrix) =>
    '''r, c = map(int, input().split())
g = [list(map(int, input().split())) for _ in range(r)]
# your solution
for row in g:
    print(*row)
''',
  ('JavaScript', InputKind.number) =>
    '''const data = require('fs').readFileSync(0, 'utf8').trim().split(/\\s+/);
const n = Number(data[0]);
// your solution
console.log(n);
''',
  ('JavaScript', InputKind.array) =>
    '''const data = require('fs').readFileSync(0, 'utf8').trim().split(/\\s+/).map(Number);
const n = data[0];
const a = data.slice(1, 1 + n);
// your solution
console.log(a.join(' '));
''',
  ('JavaScript', InputKind.string) =>
    '''const s = require('fs').readFileSync(0, 'utf8').split('\\n')[0];
// your solution
console.log(s);
''',
  ('JavaScript', InputKind.matrix) =>
    '''const data = require('fs').readFileSync(0, 'utf8').trim().split(/\\s+/).map(Number);
const [r, c] = data;
const g = [];
for (let i = 0; i < r; i++) g.push(data.slice(2 + i * c, 2 + (i + 1) * c));
// your solution
for (const row of g) console.log(row.join(' '));
''',
  _ => throw ArgumentError.value(language, 'language', 'no template'),
};

/// True when [actual] output matches [expected], ignoring trailing spaces on each line and trailing blank lines.
bool outputsMatch(String actual, String expected) {
  List<String> lines(String s) {
    final out = s.replaceAll('\r\n', '\n').split('\n').map((l) => l.trimRight()).toList();
    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }
    return out;
  }

  final a = lines(actual), e = lines(expected);
  if (a.length != e.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != e[i]) return false;
  }
  return true;
}
