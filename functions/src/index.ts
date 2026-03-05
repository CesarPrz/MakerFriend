import { onDocumentCreated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/logger';
import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

initializeApp();
const db = getFirestore();

const USERS = 'users';

/**
 * Trigger: users/{uid}/following/{targetUid} CREATED
 * - create mirror doc: users/{targetUid}/followers/{uid}
 * - increment counters once (idempotent if re-run)
 */
export const onFollowingCreated = onDocumentCreated(
  {
    document: 'users/{uid}/following/{targetUid}',
    region: 'us-central1',
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
    region: 'us-central1',
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
