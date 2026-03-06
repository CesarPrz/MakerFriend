import { onDocumentCreated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions';
import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

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
      if (followerSnap.exists) {
        return;
      }

      tx.set(followerRef, {
        uid,
        createdAt: FieldValue.serverTimestamp(),
      });
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
 * - decrement counters
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
      const followerSnap = await tx.get(followerRef);
      if (!followerSnap.exists) {
        return;
      }

      tx.delete(followerRef);
      tx.set(sourceUserRef, {
        followingCount: FieldValue.increment(-1),
      }, { merge: true });
      tx.set(targetUserRef, {
        followersCount: FieldValue.increment(-1),
      }, { merge: true });
    });

    logger.info('Follow removed', { uid, targetUid });
  },
);

/**
 * Trigger: users/{uid}/likedProjects/{projectId} CREATED
 * - create mirror doc: projects/{projectId}/likes/{uid}
 * - increment projects/{projectId}.likesCount
 */
export const onProjectLikedCreated = onDocumentCreated(
  'users/{uid}/likedProjects/{projectId}',
  async (event) => {
    const { uid, projectId } = event.params;
    if (!uid || !projectId) return;

    const projectRef = db.collection('projects').doc(projectId);
    const projectLikeRef = projectRef.collection('likes').doc(uid);

    await db.runTransaction(async (tx) => {
      const projectLikeSnap = await tx.get(projectLikeRef);
      if (projectLikeSnap.exists) {
        return;
      }

      tx.set(projectLikeRef, {
        uid,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(projectRef, {
        likesCount: FieldValue.increment(1),
      }, { merge: true });
    });

    logger.info('Project liked', { uid, projectId });
  },
);

/**
 * Trigger: users/{uid}/likedProjects/{projectId} DELETED
 * - delete mirror doc: projects/{projectId}/likes/{uid}
 * - decrement projects/{projectId}.likesCount
 */
export const onProjectLikedDeleted = onDocumentDeleted(
  'users/{uid}/likedProjects/{projectId}',
  async (event) => {
    const { uid, projectId } = event.params;
    if (!uid || !projectId) return;

    const projectRef = db.collection('projects').doc(projectId);
    const projectLikeRef = projectRef.collection('likes').doc(uid);

    await db.runTransaction(async (tx) => {
      const projectLikeSnap = await tx.get(projectLikeRef);
      if (!projectLikeSnap.exists) {
        return;
      }

      tx.delete(projectLikeRef);
      tx.set(projectRef, {
        likesCount: FieldValue.increment(-1),
      }, { merge: true });
    });

    logger.info('Project unliked', { uid, projectId });
  },
);

/**
 * Trigger: users/{uid}/notifications/{notificationId} CREATED
 * - envoie une push FCM au destinataire (si tokens disponibles)
 */
export const onNotificationCreated = onDocumentCreated(
  'users/{uid}/notifications/{notificationId}',
  async (event) => {
    const { uid, notificationId } = event.params;
    if (!uid || !notificationId) return;

    const data = event.data?.data();
    if (!data) return;

    const userDoc = await db.collection('users').doc(uid).get();
    const userData = userDoc.data() ?? {};
    const tokens = (userData.fcmTokens as string[] | undefined) ?? [];
    const cleanTokens = tokens.filter((t) => typeof t === 'string' && t.length > 0);
    if (cleanTokens.length === 0) return;

    const actorName = (data.actorName as string | undefined) ?? 'Quelqu\'un';
    const type = (data.type as string | undefined) ?? 'post_comment';

    let title = 'Nouvelle notification';
    let body = 'Tu as une nouvelle notification.';

    if (type === 'new_follower') {
      title = 'Nouveau follower';
      body = `${actorName} te suit maintenant.`;
    } else if (type === 'project_like') {
      const projectTitle = (data.projectTitle as string | undefined) ?? '';
      title = 'Nouveau like';
      body = projectTitle
        ? `${actorName} a like ton projet "${projectTitle}".`
        : `${actorName} a like ton projet.`;
    } else if (type === 'post_comment') {
      const itemTitle = (data.itemTitle as string | undefined) ?? '';
      title = 'Nouveau commentaire';
      body = itemTitle
        ? `${actorName} a commente ton post "${itemTitle}".`
        : `${actorName} a commente ton post.`;
    }

    const response = await getMessaging().sendEachForMulticast({
      tokens: cleanTokens,
      notification: { title, body },
      data: {
        type,
        projectId: (data.projectId as string | undefined) ?? '',
        itemId: (data.itemId as string | undefined) ?? '',
      },
      android: {
        priority: 'high',
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
      },
    });

    if (response.failureCount > 0) {
      const invalidTokens: string[] = [];
      response.responses.forEach((r, idx) => {
        if (!r.success) {
          const code = r.error?.code ?? '';
          if (
            code.includes('registration-token-not-registered') ||
            code.includes('invalid-registration-token')
          ) {
            invalidTokens.push(cleanTokens[idx]);
          }
        }
      });

      if (invalidTokens.length > 0) {
        await db.collection('users').doc(uid).set({
          fcmTokens: FieldValue.arrayRemove(...invalidTokens),
        }, { merge: true });
      }
    }

    logger.info('Notification push sent', {
      uid,
      notificationId,
      sent: response.successCount,
      failed: response.failureCount,
    });
  },
);
