import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'mocha';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const CODE = 'ABCD2345';
const HOUR = 60 * 60 * 1000;

let env;

const db = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();
const room = (uid, code = CODE) => doc(db(uid), 'rooms', code);

function newRoom(ownerUid, code = CODE, extra = {}) {
  return {
    roomCode: code,
    ownerUid,
    viewerUid: null,
    createdAt: serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + 24 * HOUR),
    isPaired: false,
    offer: null,
    answer: null,
    facingMode: 'environment',
    cryAlert: false,
    cryDb: null,
    cryUpdated: serverTimestamp(),
    videoSettings: { fps: 15, quality: 'MEDIUM' },
    noiseThreshold: 60,
    viewerSession: null,
    ...extra,
  };
}

const claim = (uid, session = 's1') =>
  updateDoc(room(uid), { viewerUid: uid, viewerSession: session, isPaired: false });

/** Writes data bypassing the rules (test setup only). */
async function seed(path, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), ...path), data);
  });
}

const candidate = (session = 's1') => ({
  candidate: 'candidate:1 1 udp 1 1.2.3.4 5 typ host',
  sdpMid: '0',
  sdpMLineIndex: 0,
  session,
  expiresAt: Timestamp.fromMillis(Date.now() + 24 * HOUR),
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-baby-monitor',
    firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

describe('creating rooms', () => {
  it('the baby can create a valid room', async () => {
    await assertSucceeds(setDoc(room('baby'), newRoom('baby')));
  });

  it('requires sign-in', async () => {
    await assertFails(setDoc(room(null), newRoom('baby')));
  });

  it('rejects invalid codes (old 6-digit, look-alikes, lower case)', async () => {
    for (const code of ['123456', 'ABCD0234', 'ABCD1234', 'abcd2345', 'ABCD23456']) {
      await assertFails(setDoc(room('baby', code), newRoom('baby', code)));
    }
  });

  it('rejects rooms for another owner, with a viewer, or extra keys', async () => {
    await assertFails(setDoc(room('baby'), newRoom('someoneElse')));
    await assertFails(setDoc(room('baby'), newRoom('baby', CODE, { viewerUid: 'parent' })));
    await assertFails(setDoc(room('baby'), newRoom('baby', CODE, { hacked: true })));
    await assertFails(setDoc(room('baby'), newRoom('baby', CODE, { roomCode: 'ZZZZ2345' })));
  });

  it('rejects a client-chosen createdAt and too long lifetimes', async () => {
    await assertFails(setDoc(room('baby'), newRoom('baby', CODE, { createdAt: Timestamp.now() })));
    await assertFails(setDoc(room('baby'), newRoom('baby', CODE, {
      expiresAt: Timestamp.fromMillis(Date.now() + 48 * HOUR),
    })));
  });

  it('overwriting an existing code (collision) is denied', async () => {
    await assertSucceeds(setDoc(room('baby'), newRoom('baby')));
    await assertFails(setDoc(room('otherBaby'), newRoom('otherBaby')));
  });
});

describe('reading rooms', () => {
  beforeEach(async () => {
    await setDoc(room('baby'), newRoom('baby'));
  });

  it('nobody can list rooms', async () => {
    await assertFails(getDocs(collection(db('baby'), 'rooms')));
    await assertFails(getDocs(collection(db('stranger'), 'rooms')));
  });

  it('only the owner can read an unclaimed room', async () => {
    await assertSucceeds(getDoc(room('baby')));
    await assertFails(getDoc(room('stranger')));
    await assertFails(getDoc(room(null)));
  });

  it('a missing room cannot be probed', async () => {
    await assertFails(getDoc(room('stranger', 'ZZZZ2345')));
  });
});

describe('claiming (parent joins)', () => {
  beforeEach(async () => {
    await setDoc(room('baby'), newRoom('baby'));
  });

  it('the first parent can claim and then read', async () => {
    await assertSucceeds(claim('parent'));
    await assertSucceeds(getDoc(room('parent')));
  });

  it('a second parent cannot claim a claimed room', async () => {
    await claim('parent');
    await assertFails(claim('intruder'));
    await assertFails(getDoc(room('intruder')));
  });

  it('the baby cannot claim its own room', async () => {
    await assertFails(claim('baby'));
  });

  it('claiming a missing room fails', async () => {
    await assertFails(updateDoc(room('parent', 'ZZZZ2345'), { viewerUid: 'parent' }));
  });

  it('claiming after 10 minutes fails (server time)', async () => {
    await seed(['rooms', CODE], {
      ...newRoom('baby'),
      createdAt: Timestamp.fromMillis(Date.now() - 11 * 60 * 1000),
      cryUpdated: Timestamp.now(),
    });
    await assertFails(claim('parent'));
  });

  it('claiming an expired room fails', async () => {
    await seed(['rooms', CODE], {
      ...newRoom('baby'),
      createdAt: Timestamp.now(),
      cryUpdated: Timestamp.now(),
      expiresAt: Timestamp.fromMillis(Date.now() - 1000),
    });
    await assertFails(claim('parent'));
  });

  it('the claim may only touch viewer fields', async () => {
    await assertFails(updateDoc(room('parent'), { viewerUid: 'parent', cryAlert: true }));
    await assertFails(updateDoc(room('parent'), { viewerUid: 'parent', ownerUid: 'parent' }));
  });
});

describe('updates by each side', () => {
  beforeEach(async () => {
    await setDoc(room('baby'), newRoom('baby'));
    await claim('parent');
  });

  it('the viewer can answer, leave and rejoin (same uid, new session)', async () => {
    await assertSucceeds(updateDoc(room('parent'), { answer: { sdp: 'x', type: 'answer', session: 's1' }, isPaired: true }));
    await assertSucceeds(updateDoc(room('parent'), { viewerSession: null, isPaired: false }));
    await assertSucceeds(updateDoc(room('parent'), { viewerSession: 's2', isPaired: false }));
    await assertSucceeds(updateDoc(room('parent'), { viewerFcmToken: 'tok', viewerLocale: 'tr' }));
  });

  it('the viewer cannot write baby-only fields or hand the room over', async () => {
    await assertFails(updateDoc(room('parent'), { offer: { sdp: 'x', type: 'offer' } }));
    await assertFails(updateDoc(room('parent'), { cryAlert: true }));
    await assertFails(updateDoc(room('parent'), { viewerUid: 'friend' }));
    await assertFails(updateDoc(room('parent'), { ownerUid: 'parent' }));
  });

  it('the owner can write stream state but not the viewer identity', async () => {
    await assertSucceeds(updateDoc(room('baby'), { offer: { sdp: 'x', type: 'offer', session: 's1' } }));
    await assertSucceeds(updateDoc(room('baby'), { cryAlert: true, cryDb: 71.5, cryUpdated: serverTimestamp() }));
    await assertSucceeds(updateDoc(room('baby'), { noiseThreshold: 70, facingMode: 'user' }));
    await assertFails(updateDoc(room('baby'), { viewerUid: null }));
    await assertFails(updateDoc(room('baby'), { viewerSession: 'fake' }));
  });

  it('the owner can extend expiresAt, but not beyond 25 h', async () => {
    await assertSucceeds(updateDoc(room('baby'), { expiresAt: Timestamp.fromMillis(Date.now() + 24 * HOUR) }));
    await assertFails(updateDoc(room('baby'), { expiresAt: Timestamp.fromMillis(Date.now() + 30 * HOUR) }));
  });

  it('strangers cannot update', async () => {
    await assertFails(updateDoc(room('stranger'), { isPaired: true }));
  });

  it('only the owner can delete the room', async () => {
    await assertFails(deleteDoc(room('parent')));
    await assertFails(deleteDoc(room('stranger')));
    await assertSucceeds(deleteDoc(room('baby')));
  });
});

describe('subcollections', () => {
  beforeEach(async () => {
    await setDoc(room('baby'), newRoom('baby'));
    await claim('parent');
  });

  for (const name of ['callerCandidates', 'calleeCandidates']) {
    it(`${name}: members write and read, owner deletes, strangers locked out`, async () => {
      const babyRef = await assertSucceeds(addDoc(collection(db('baby'), 'rooms', CODE, name), candidate()));
      await assertSucceeds(addDoc(collection(db('parent'), 'rooms', CODE, name), candidate()));
      await assertSucceeds(getDocs(collection(db('parent'), 'rooms', CODE, name)));
      await assertFails(getDocs(collection(db('stranger'), 'rooms', CODE, name)));
      await assertFails(addDoc(collection(db('stranger'), 'rooms', CODE, name), candidate()));
      await assertFails(addDoc(collection(db('parent'), 'rooms', CODE, name), { ...candidate(), extra: 1 }));
      await assertFails(deleteDoc(doc(db('parent'), 'rooms', CODE, name, babyRef.id)));
      await assertSucceeds(deleteDoc(doc(db('baby'), 'rooms', CODE, name, babyRef.id)));
    });
  }

  it('alerts: only the baby writes, both read, strangers locked out', async () => {
    const alert = {
      title: 'Bebek Ağlama Alarmı',
      body: 'Ses seviyesi: 72.0 dB',
      timestamp: serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + 24 * HOUR),
    };
    await assertSucceeds(addDoc(collection(db('baby'), 'rooms', CODE, 'alerts'), alert));
    await assertFails(addDoc(collection(db('parent'), 'rooms', CODE, 'alerts'), alert));
    await assertSucceeds(getDocs(collection(db('parent'), 'rooms', CODE, 'alerts')));
    await assertFails(getDocs(collection(db('stranger'), 'rooms', CODE, 'alerts')));
  });

  it('before a parent claims, a stranger cannot read candidates either', async () => {
    await seed(['rooms', 'WXYZ2345'], { ...newRoom('baby', 'WXYZ2345'), createdAt: Timestamp.now(), cryUpdated: Timestamp.now() });
    await assertFails(getDocs(collection(db('stranger'), 'rooms', 'WXYZ2345', 'callerCandidates')));
  });
});

describe('other paths', () => {
  it('everything outside rooms is closed', async () => {
    await assertFails(setDoc(doc(db('baby'), 'users', 'baby'), { a: 1 }));
    await assertFails(getDoc(doc(db('baby'), 'users', 'baby')));
  });
});
