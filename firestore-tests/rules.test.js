// Firestore security rules tests. Run from the repo root:
//   firebase emulators:exec --only firestore --project demo-memory-stack "npm --prefix firestore-tests test"
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, deleteField, doc, getDoc, getDocs, limit, orderBy, query, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-memory-stack',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();
const guest = () => env.unauthenticatedContext().firestore();

const problem = { name: 'Two Sum', platform: 'LeetCode', difficulty: 'Easy', topic: 'Arrays', url: null,
  solvedOn: '2026-10-01', stage: 0, nextDue: '2026-10-02', reviews: 0, remembered: 0 };

describe('user document', () => {
  it('owner can create, read, update and delete it', async () => {
    const ref = doc(alice(), 'users/alice');
    await assertSucceeds(setDoc(ref, { v: 2, problems: { p1: problem } }, { merge: true }));
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(updateDoc(ref, { 'days.2026-10-02': 1, 'topics.Arrays.total': 1 }));
    await assertSucceeds(updateDoc(ref, { 'problems.p1': deleteField() }));
    await assertSucceeds(deleteDoc(ref));
  });

  it('nobody else can read or write it', async () => {
    await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'users/alice'), { v: 2 }));
    await assertFails(getDoc(doc(bob(), 'users/alice')));
    await assertFails(setDoc(doc(bob(), 'users/alice'), { v: 2 }));
    await assertFails(deleteDoc(doc(bob(), 'users/alice')));
    await assertFails(getDoc(doc(guest(), 'users/alice')));
  });

  it('nobody can list all users', async () => {
    await assertFails(getDocs(collection(alice(), 'users')));
  });

  it('rejects unknown fields and wrong types', async () => {
    const ref = doc(alice(), 'users/alice');
    await assertFails(setDoc(ref, { v: 2, isAdmin: true }));
    await assertFails(setDoc(ref, { v: 'two' }));
    await assertFails(setDoc(ref, { problems: 'not a map' }));
  });
});

describe('notes', () => {
  it('owner can save, read and delete a note', async () => {
    const ref = doc(alice(), 'users/alice/notes/p1');
    await assertSucceeds(setDoc(ref, { text: 'hash map, O(n)' }));
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(deleteDoc(ref));
  });

  it('accepts a full solution card', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'users/alice/notes/p1'),
      { idea: 'two pointers', time: 'O(n)', space: 'O(1)', mistake: 'off by one', text: 'code' }));
  });

  it('rejects oversized card fields', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice/notes/p1'), { idea: 'x'.repeat(501) }));
    await assertFails(setDoc(doc(alice(), 'users/alice/notes/p1'), { time: 'x'.repeat(41) }));
    await assertFails(setDoc(doc(alice(), 'users/alice/notes/p1'), {}));
  });

  it('rejects oversized, empty or extra-field notes, and other users', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice/notes/p1'), { text: 'x'.repeat(20001) }));
    await assertFails(setDoc(doc(alice(), 'users/alice/notes/p1'), { text: '' }));
    await assertFails(setDoc(doc(alice(), 'users/alice/notes/p1'), { text: 'ok', extra: 1 }));
    await assertFails(setDoc(doc(alice(), `users/alice/notes/${'x'.repeat(65)}`), { text: 'ok' }));
    await assertFails(setDoc(doc(bob(), 'users/alice/notes/p1'), { text: 'hi' }));
  });
});

describe('old layout and anything else', () => {
  it('old problems/reviews can be read and deleted but never written', async () => {
    await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'users/alice/problems/p1'), problem));
    await assertSucceeds(getDocs(collection(alice(), 'users/alice/problems')));
    await assertSucceeds(deleteDoc(doc(alice(), 'users/alice/problems/p1')));
    await assertFails(setDoc(doc(alice(), 'users/alice/problems/p2'), problem));
    await assertFails(setDoc(doc(alice(), 'users/alice/reviews/r1'), { problemId: 'p1' }));
  });

  it('any other path is denied', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice/secrets/x'), { a: 1 }));
    await assertFails(setDoc(doc(alice(), 'config/app'), { a: 1 }));
  });
});

describe('leaderboard', () => {
  const entry = (extra = {}) => ({ name: 'Alice', streak: 5, solved: 20, updatedAt: serverTimestamp(), ...extra });

  it('you can publish, update and remove only your own entry', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'leaderboard/alice'), entry()));
    await assertSucceeds(setDoc(doc(alice(), 'leaderboard/alice'), entry({ streak: 6 })));
    await assertFails(setDoc(doc(bob(), 'leaderboard/alice'), entry({ name: 'Bob' })));
    await assertFails(deleteDoc(doc(bob(), 'leaderboard/alice')));
    await assertSucceeds(deleteDoc(doc(alice(), 'leaderboard/alice')));
  });

  it('signed-in users can read the top list; visitors cannot', async () => {
    await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'leaderboard/alice'), { name: 'Alice', streak: 5, solved: 1 }));
    await assertSucceeds(getDocs(query(collection(bob(), 'leaderboard'), orderBy('streak', 'desc'), limit(50))));
    await assertFails(getDocs(collection(guest(), 'leaderboard')));
  });

  it('rejects fake or oversized values and extra fields', async () => {
    const ref = doc(alice(), 'leaderboard/alice');
    await assertFails(setDoc(ref, entry({ streak: 999999 })));
    await assertFails(setDoc(ref, entry({ solved: -1 })));
    await assertFails(setDoc(ref, entry({ name: 'x'.repeat(31) })));
    await assertFails(setDoc(ref, entry({ email: 'a@b.c' })));
    await assertFails(setDoc(ref, { name: 'Alice', streak: 5, solved: 2, updatedAt: new Date(0) }));
  });
});
