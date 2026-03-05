import { onDocumentCreated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions';
import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

initializeApp();
const db = getFirestore();

/**
 * Trigger: users/{uid}/following/{targetUid} CREATED
 * - create mirror doc: users/{targetUid}/followers/{uid}
 * - increment counters:
 *   users/{uid}.followingCount += 1
 *   users/{targetUid}.followersCount += 1
 */
export const onFollowingCreated = onDocumentCreated(
  'users/{uid}/following/{targetUid}',
  async (event) => {
    const { uid, targetUid } = event.params;
    if (!uid || !targetUid || uid === targetUid) return;

    const followerRef = db.collection('users').doc(targetUid)
      .collection('followers').doc(uid);
    const sourceUserRef = db.collection('users').doc(uid);
    const targetUserRef = db.collection('users').doc(targetUid);

    await db.runTransaction(async (tx) => {
      const followerSnap = await tx.get(followerRef);
      if (!followerSnap.exists) {
        tx.set(followerRef, {
          uid,
          createdAt: FieldValue.serverTimestamp(),
        });
      }

      tx.set(sourceUserRef, {
        followingCount: FieldValue.increment(1),
      }, { merge: true });
      tx.set(targetUserRef, {
        followersCount: FieldValue.increment(1),
      }, { merge: true });
    });

    logger.info('Follow created', { uid, targetUid });
  },
);

/**
 * Trigger: users/{uid}/following/{targetUid} DELETED
 * - delete mirror doc: users/{targetUid}/followers/{uid}
 * - decrement counters (bounded to >=0)
 */
export const onFollowingDeleted = onDocumentDeleted(
  'users/{uid}/following/{targetUid}',
  async (event) => {
    const { uid, targetUid } = event.params;
    if (!uid || !targetUid || uid === targetUid) return;

    const followerRef = db.collection('users').doc(targetUid)
      .collection('followers').doc(uid);
    const sourceUserRef = db.collection('users').doc(uid);
    const targetUserRef = db.collection('users').doc(targetUid);

    await db.runTransaction(async (tx) => {
      tx.delete(followerRef);

      const sourceSnap = await tx.get(sourceUserRef);
      const targetSnap = await tx.get(targetUserRef);

      const currentFollowing = Number(sourceSnap.get('followingCount') || 0);
      const currentFollowers = Number(targetSnap.get('followersCount') || 0);

      tx.set(sourceUserRef, {
        followingCount: Math.max(0, currentFollowing - 1),
      }, { merge: true });
      tx.set(targetUserRef, {
        followersCount: Math.max(0, currentFollowers - 1),
      }, { merge: true });
    });

    logger.info('Follow removed', { uid, targetUid });
  },
);
