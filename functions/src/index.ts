import { onDocumentCreated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/logger';
import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

initializeApp();
const db = getFirestore();

const USERS = 'users';
const REGION = 'us-central1';

function requireAuthUid(request: { auth?: { uid?: string } }): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
  return uid;
}

export const followUser = onCall({ region: REGION }, async (request) => {
  const currentUid = requireAuthUid(request);
  const targetUid = String(request.data?.targetUid ?? '').trim();

  if (!targetUid) {
    throw new HttpsError('invalid-argument', 'targetUid is required.');
  }
  if (targetUid == currentUid) {
    throw new HttpsError('failed-precondition', 'Cannot follow yourself.');
  }

  await db
    .collection(USERS)
    .doc(currentUid)
    .collection('following')
    .doc(targetUid)
    .set(
      {
        uid: targetUid,
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  return { ok: true };
});

export const unfollowUser = onCall({ region: REGION }, async (request) => {
  const currentUid = requireAuthUid(request);
  const targetUid = String(request.data?.targetUid ?? '').trim();

  if (!targetUid) {
    throw new HttpsError('invalid-argument', 'targetUid is required.');
  }
  if (targetUid == currentUid) {
    throw new HttpsError('failed-precondition', 'Cannot unfollow yourself.');
  }

  await db
    .collection(USERS)
    .doc(currentUid)
    .collection('following')
    .doc(targetUid)
    .delete();

  return { ok: true };
});

/**
 * Trigger: users/{uid}/following/{targetUid} CREATED
 * - create mirror doc: users/{targetUid}/followers/{uid}
 * - increment counters once (idempotent if re-run)
 */
export const onFollowingCreated = onDocumentCreated(
  {
    document: 'users/{uid}/following/{targetUid}',
    region: REGION,
  },
  async (event) => {
    const { uid, targetUid } = event.params;
    if (!uid || !targetUid || uid === targetUid) return;

    const followerRef = db
      .collection(USERS)
      .doc(targetUid)
      .collection('followers')
      .doc(uid);
    const sourceUserRef = db.collection(USERS).doc(uid);
    const targetUserRef = db.collection(USERS).doc(targetUid);

    await db.runTransaction(async (tx) => {
      const followerSnap = await tx.get(followerRef);

      // Déjà synchronisé => ne pas doubler les compteurs.
      if (followerSnap.exists) {
        return;
      }

      tx.set(followerRef, {
        uid,
        createdAt: FieldValue.serverTimestamp(),
      });

      tx.set(
        sourceUserRef,
        { followingCount: FieldValue.increment(1) },
        { merge: true },
      );
      tx.set(
        targetUserRef,
        { followersCount: FieldValue.increment(1) },
        { merge: true },
      );
    });

    logger.info('Follow created', { uid, targetUid });
  },
);

/**
 * Trigger: users/{uid}/following/{targetUid} DELETED
 * - delete mirror doc: users/{targetUid}/followers/{uid}
 * - decrement counters once (idempotent + borné à 0)
 */
export const onFollowingDeleted = onDocumentDeleted(
  {
    document: 'users/{uid}/following/{targetUid}',
    region: REGION,
  },
  async (event) => {
    const { uid, targetUid } = event.params;
    if (!uid || !targetUid || uid === targetUid) return;

    const followerRef = db
      .collection(USERS)
      .doc(targetUid)
      .collection('followers')
      .doc(uid);
    const sourceUserRef = db.collection(USERS).doc(uid);
    const targetUserRef = db.collection(USERS).doc(targetUid);

    await db.runTransaction(async (tx) => {
      const followerSnap = await tx.get(followerRef);

      // Rien à supprimer => ne pas décrémenter par erreur.
      if (!followerSnap.exists) {
        return;
      }

      tx.delete(followerRef);

      const [sourceSnap, targetSnap] = await Promise.all([
        tx.get(sourceUserRef),
        tx.get(targetUserRef),
      ]);

      const currentFollowing = Number(sourceSnap.get('followingCount') || 0);
      const currentFollowers = Number(targetSnap.get('followersCount') || 0);

      tx.set(
        sourceUserRef,
        { followingCount: Math.max(0, currentFollowing - 1) },
        { merge: true },
      );
      tx.set(
        targetUserRef,
        { followersCount: Math.max(0, currentFollowers - 1) },
        { merge: true },
      );
    });

    logger.info('Follow removed', { uid, targetUid });
  },
);
