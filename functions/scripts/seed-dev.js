#!/usr/bin/env node

/*
 * Firestore dev seeder for MakerFlow screenshot data.
 *
 * Credentials needed:
 * - GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
 * OR
 * - gcloud auth application-default login
 */

const fs = require("fs");
const path = require("path");
const {initializeApp, applicationDefault, cert} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const HOUR_MS = 60 * 60 * 1000;
const DANGEROUS_PROJECTS = new Set(["makerflow---prod", "makerflow---stage"]);

const USER_FIXTURES = [
  {uid: "demo_mila_printlab", displayName: "Mila PrintLab", specialty: "Impression 3D"},
  {uid: "demo_nolan_firmware", displayName: "Nolan Firmware", specialty: "Electronique"},
  {uid: "demo_lina_couture", displayName: "Lina Couture", specialty: "Couture"},
  {uid: "demo_hugo_figs", displayName: "Hugo MiniFigs", specialty: "Peinture figurines"},
  {uid: "demo_emma_kitbuild", displayName: "Emma KitBuild", specialty: "Model kits"},
  {uid: "demo_karim_cnc", displayName: "Karim CNC", specialty: "CNC"},
  {uid: "demo_zoe_brushes", displayName: "Zoe Brushes", specialty: "Figurines"},
  {uid: "demo_lucas_dev", displayName: "Lucas BuildLog", specialty: "Dev"},
];

const PROJECT_FIXTURES = [
  {
    id: "demo_project_bambu_enclosure",
    short: "enclosure",
    ownerUid: "demo_mila_printlab",
    title: "Caisson silencieux pour Bambu A1",
    description: "PETG + panneaux acrylique, LED, filtration d'air.",
    types: ["Impression 3D", "DIY", "Hardware"],
  },
  {
    id: "demo_project_esp32_greenhouse",
    short: "greenhouse",
    ownerUid: "demo_nolan_firmware",
    title: "Mini serre ESP32 autonome",
    description: "Capteurs humidite + pompe + dashboard local.",
    types: ["Electronique", "IoT", "Firmware"],
  },
  {
    id: "demo_project_split_keyboard",
    short: "keyboard",
    ownerUid: "demo_nolan_firmware",
    title: "Clavier split low-profile",
    description: "PCB maison, keymap QMK, boitier imprime.",
    types: ["Dev", "PCB", "Keyboard"],
  },
  {
    id: "demo_project_denim_tote",
    short: "tote",
    ownerUid: "demo_lina_couture",
    title: "Tote bag upcycle denim",
    description: "Recyclage jean avec doublure et poches internes.",
    types: ["Couture", "Upcycling", "DIY"],
  },
  {
    id: "demo_project_orc_warband",
    short: "orc",
    ownerUid: "demo_hugo_figs",
    title: "Warband orc 28mm",
    description: "Escouade complete avec weathering et socles.",
    types: ["Figurines", "Peinture", "Wargame"],
  },
  {
    id: "demo_project_gundam_hangar",
    short: "gundam",
    ownerUid: "demo_emma_kitbuild",
    title: "Diorama hangar Gundam 1/144",
    description: "Montage, panel lining, weathering, LED.",
    types: ["Model Kit", "Gunpla", "Diorama"],
  },
  {
    id: "demo_project_cnc_wall_sign",
    short: "cnc",
    ownerUid: "demo_karim_cnc",
    title: "Enseigne murale CNC",
    description: "Usinage bois + epoxy noire.",
    types: ["CNC", "Bois", "Atelier"],
  },
  {
    id: "demo_project_weather_dashboard",
    short: "dashboard",
    ownerUid: "demo_lucas_dev",
    title: "Dashboard meteo atelier",
    description: "Flutter + API meteo + alertes hygrometrie.",
    types: ["Dev", "Flutter", "Data"],
  },
  {
    id: "demo_project_paint_booth",
    short: "paintbooth",
    ownerUid: "demo_zoe_brushes",
    title: "Mini booth peinture figurines",
    description: "Boite pliante avec extraction et eclairage.",
    types: ["Figurines", "DIY", "Atelier"],
  },
];

function parseArgs(argv) {
  const opts = {
    help: false,
    reset: false,
    allowNonDev: false,
    project: undefined,
    viewerUid: undefined,
    serviceAccount: undefined,
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--help" || arg === "-h") opts.help = true;
    else if (arg === "--reset") opts.reset = true;
    else if (arg === "--allow-non-dev") opts.allowNonDev = true;
    else if (arg.startsWith("--project=")) opts.project = arg.slice("--project=".length).trim();
    else if (arg === "--project" && i + 1 < argv.length) opts.project = argv[++i].trim();
    else if (arg.startsWith("--viewerUid=")) opts.viewerUid = arg.slice("--viewerUid=".length).trim();
    else if (arg === "--viewerUid" && i + 1 < argv.length) opts.viewerUid = argv[++i].trim();
    else if (arg.startsWith("--serviceAccount=")) opts.serviceAccount = arg.slice("--serviceAccount=".length).trim();
    else if (arg === "--serviceAccount" && i + 1 < argv.length) opts.serviceAccount = argv[++i].trim();
    else throw new Error(`Unknown argument: ${arg}`);
  }

  return opts;
}

function printHelp() {
  console.log(`
Seed MakerFlow Firestore data (dev)

Usage:
  node scripts/seed-dev.js [options]

Options:
  --viewerUid <uid>        Real Auth uid used for screenshots feed/notifications.
  --project <projectId>    Firebase project id (default: .firebaserc projects.dev)
  --serviceAccount <path>  Path to a service-account JSON key.
  --reset                  Delete seeded docs first, then reseed.
  --allow-non-dev          Allow stage/prod projects.
  -h, --help               Show this help.

Examples:
  npm run seed:dev -- --viewerUid <YOUR_UID>
  npm run seed:dev:reset -- --viewerUid <YOUR_UID>
`);
}

function readDevProjectIdFromFirebaserc() {
  try {
    const rcPath = path.resolve(__dirname, "..", "..", ".firebaserc");
    if (!fs.existsSync(rcPath)) return undefined;
    const json = JSON.parse(fs.readFileSync(rcPath, "utf8"));
    const id = json?.projects?.dev;
    if (typeof id === "string" && id.trim()) return id.trim();
  } catch (e) {
    // ignore
  }
  return undefined;
}

function hoursAgo(now, hours) {
  return new Date(now.getTime() - (hours * HOUR_MS));
}

function photo(seed, w = 1200, h = 900) {
  return `https://picsum.photos/seed/${seed}/${w}/${h}`;
}

function cleanUndefined(obj) {
  return Object.fromEntries(Object.entries(obj).filter(([, v]) => v !== undefined));
}

function uniquePairs(pairs) {
  const seen = new Set();
  const out = [];
  for (const [from, to] of pairs) {
    if (!from || !to || from === to) continue;
    const key = `${from}::${to}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push([from, to]);
  }
  return out;
}

function addLike(map, uid, projectIds) {
  const set = new Set(map.get(uid) || []);
  for (const projectId of projectIds) set.add(projectId);
  map.set(uid, [...set]);
}

function queueSet(plan, ref, data, options) {
  plan.sets.push({ref, data, options});
  plan.refsByPath.set(ref.path, ref);
}

async function commitDeletes(db, refs) {
  if (refs.length === 0) return;
  let batch = db.batch();
  let count = 0;
  for (const ref of refs) {
    batch.delete(ref);
    count++;
    if (count >= 450) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }
  if (count > 0) await batch.commit();
}

async function commitSets(db, setOps) {
  if (setOps.length === 0) return;
  let batch = db.batch();
  let count = 0;
  for (const op of setOps) {
    if (op.options) batch.set(op.ref, op.data, op.options);
    else batch.set(op.ref, op.data);
    count++;
    if (count >= 450) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }
  if (count > 0) await batch.commit();
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.help) {
    printHelp();
    return;
  }

  const projectId =
    opts.project ||
    process.env.FIREBASE_PROJECT_ID ||
    readDevProjectIdFromFirebaserc() ||
    "makerfriend-a3cc3";
  if (DANGEROUS_PROJECTS.has(projectId) && !opts.allowNonDev) {
    throw new Error(`Refusing project "${projectId}". Use --allow-non-dev to override.`);
  }

  const viewerUid = opts.viewerUid || process.env.VIEWER_UID || "demo_viewer_portfolio";
  if (!viewerUid.trim()) throw new Error("viewerUid cannot be empty.");

  const serviceAccountPath = opts.serviceAccount || process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  let credential = applicationDefault();
  if (serviceAccountPath) {
    const resolved = path.resolve(serviceAccountPath);
    if (!fs.existsSync(resolved)) {
      throw new Error(`Service account file not found: ${resolved}`);
    }
    const raw = fs.readFileSync(resolved, "utf8");
    const parsed = JSON.parse(raw);
    credential = cert(parsed);
  }

  initializeApp({credential, projectId});
  const db = getFirestore();
  db.settings({ignoreUndefinedProperties: true});

  const now = new Date();
  const userByUid = new Map(USER_FIXTURES.map((u) => [u.uid, u]));
  const projectByShort = new Map(PROJECT_FIXTURES.map((p) => [p.short, p]));
  const projectIdByShort = new Map(PROJECT_FIXTURES.map((p) => [p.short, p.id]));
  const latestByIndex = [36, 44, 28, 24, 20, 30, 18, 16, 14];

  const timelineDocs = [];
  const timelineByKey = new Map();
  const comments = [];
  const commentBodies = [
    "Super propre, j'aime beaucoup ce rendu.",
    "Top progression, tu peux partager tes reglages ?",
    "Tres inspirant, hate de voir la suite.",
    "Le resultat est net, beau taf.",
  ];

  PROJECT_FIXTURES.forEach((project, projectIndex) => {
    const owner = userByUid.get(project.ownerUid);
    const latest = latestByIndex[projectIndex] || (20 + projectIndex);
    const timeline = [
      {
        id: `demo_item_${project.short}_01`,
        type: "step",
        title: "Plan et materiaux",
        body: `Preparation du projet ${project.title} (${project.types[0]}).`,
        createdAt: hoursAgo(now, latest + 200),
        photoUrls: [],
      },
      {
        id: `demo_item_${project.short}_02`,
        type: "post",
        title: "Prototype v1",
        body: `Premier test terrain pour ${project.title}.`,
        createdAt: hoursAgo(now, latest + 80),
        photoUrls: [photo(`${project.short}-p1-a`), photo(`${project.short}-p1-b`)],
      },
      {
        id: `demo_item_${project.short}_03`,
        type: "post",
        title: "Version finale",
        body: `Update final, optimisation et finitions sur ${project.title}.`,
        createdAt: hoursAgo(now, latest),
        photoUrls: [photo(`${project.short}-p2`)],
      },
    ];

    timeline.forEach((item, itemIndex) => {
      timelineDocs.push({
        projectId: project.id,
        itemId: item.id,
        ...item,
        authorUid: owner.uid,
        authorName: owner.displayName,
        authorPhotoUrl: photo(`avatar-${project.short}`, 300, 300),
      });
      timelineByKey.set(`${project.short}:${itemIndex + 1}`, {itemId: item.id, title: item.title});

      if (item.type === "post") {
        const otherUsers = USER_FIXTURES.filter((u) => u.uid !== project.ownerUid);
        const first = otherUsers[(projectIndex + itemIndex) % otherUsers.length];
        const second = otherUsers[(projectIndex + itemIndex + 1) % otherUsers.length];
        [first, second].forEach((u, i) => {
          comments.push({
            projectId: project.id,
            itemId: item.id,
            commentId: `demo_comment_${project.short}_${itemIndex + 1}_${i + 1}`,
            body: commentBodies[(projectIndex + i) % commentBodies.length],
            createdAt: new Date(item.createdAt.getTime() + ((i + 1) * HOUR_MS)),
            authorUid: u.uid,
            authorName: u.displayName,
            authorPhotoUrl: photo(`avatar-${u.uid}`, 300, 300),
          });
        });
      }
    });
  });

  const followPairs = uniquePairs([
    ...USER_FIXTURES.map((u) => [viewerUid, u.uid]),
    ["demo_mila_printlab", "demo_nolan_firmware"],
    ["demo_mila_printlab", "demo_hugo_figs"],
    ["demo_nolan_firmware", "demo_karim_cnc"],
    ["demo_nolan_firmware", "demo_lucas_dev"],
    ["demo_lina_couture", "demo_zoe_brushes"],
    ["demo_hugo_figs", "demo_emma_kitbuild"],
    ["demo_emma_kitbuild", "demo_hugo_figs"],
    ["demo_karim_cnc", "demo_mila_printlab"],
    ["demo_lucas_dev", "demo_nolan_firmware"],
    ["demo_zoe_brushes", "demo_lina_couture"],
  ]);

  const likesByUser = new Map();
  addLike(likesByUser, "demo_mila_printlab", [projectIdByShort.get("greenhouse"), projectIdByShort.get("orc"), projectIdByShort.get("cnc")]);
  addLike(likesByUser, "demo_nolan_firmware", [projectIdByShort.get("enclosure"), projectIdByShort.get("gundam"), projectIdByShort.get("dashboard")]);
  addLike(likesByUser, "demo_lina_couture", [projectIdByShort.get("enclosure"), projectIdByShort.get("orc"), projectIdByShort.get("paintbooth")]);
  addLike(likesByUser, "demo_hugo_figs", [projectIdByShort.get("tote"), projectIdByShort.get("gundam"), projectIdByShort.get("paintbooth")]);
  addLike(likesByUser, "demo_emma_kitbuild", [projectIdByShort.get("orc"), projectIdByShort.get("keyboard"), projectIdByShort.get("greenhouse")]);
  addLike(likesByUser, "demo_karim_cnc", [projectIdByShort.get("enclosure"), projectIdByShort.get("keyboard"), projectIdByShort.get("gundam")]);
  addLike(likesByUser, "demo_zoe_brushes", [projectIdByShort.get("orc"), projectIdByShort.get("tote"), projectIdByShort.get("dashboard")]);
  addLike(likesByUser, "demo_lucas_dev", [projectIdByShort.get("greenhouse"), projectIdByShort.get("orc"), projectIdByShort.get("tote")]);
  addLike(likesByUser, viewerUid, [
    projectIdByShort.get("enclosure"),
    projectIdByShort.get("orc"),
    projectIdByShort.get("gundam"),
    projectIdByShort.get("dashboard"),
    projectIdByShort.get("paintbooth"),
  ]);

  const likesCountByProject = new Map(PROJECT_FIXTURES.map((p) => [p.id, 0]));
  for (const ids of likesByUser.values()) {
    ids.filter(Boolean).forEach((id) => {
      likesCountByProject.set(id, (likesCountByProject.get(id) || 0) + 1);
    });
  }

  const followingCountByUser = new Map();
  const followersCountByUser = new Map();
  followPairs.forEach(([from, to]) => {
    followingCountByUser.set(from, (followingCountByUser.get(from) || 0) + 1);
    followersCountByUser.set(to, (followersCountByUser.get(to) || 0) + 1);
  });

  const plan = {sets: [], refsByPath: new Map()};
  USER_FIXTURES.forEach((user, index) => {
    queueSet(plan, db.doc(`users/${user.uid}`), {
      uid: user.uid,
      displayName: user.displayName,
      email: `${user.uid}@demo.makerflow.app`,
      photoUrl: photo(`avatar-${user.uid}`, 300, 300),
      providerIds: ["seed"],
      createdAt: hoursAgo(now, 1600 - (index * 60)),
      lastLoginAt: hoursAgo(now, 2 + index),
      followingCount: followingCountByUser.get(user.uid) || 0,
      followersCount: followersCountByUser.get(user.uid) || 0,
    });
  });

  const viewerIsDemo = userByUid.has(viewerUid);
  if (!viewerIsDemo) {
    const viewerRef = db.doc(`users/${viewerUid}`);
    const viewerSnap = await viewerRef.get();
    if (!viewerSnap.exists) {
      queueSet(plan, viewerRef, {
        uid: viewerUid,
        displayName: "Portfolio Viewer",
        email: "viewer@demo.makerflow.app",
        photoUrl: photo("avatar-viewer", 300, 300),
        providerIds: ["seed"],
        createdAt: hoursAgo(now, 24),
        lastLoginAt: hoursAgo(now, 1),
      }, {merge: true});
    }
  }

  PROJECT_FIXTURES.forEach((project, index) => {
    const owner = userByUid.get(project.ownerUid);
    const lastTimelineUpdate = timelineDocs
      .filter((item) => item.projectId === project.id)
      .map((item) => item.createdAt)
      .sort((a, b) => b.getTime() - a.getTime())[0];

    queueSet(plan, db.doc(`projects/${project.id}`), {
      ownerUid: project.ownerUid,
      ownerDisplayName: owner.displayName,
      ownerPhotoUrl: photo(`avatar-${owner.uid}`, 300, 300),
      title: project.title,
      description: project.description,
      coverUrl: photo(`cover-${project.short}`, 1280, 720),
      types: project.types,
      createdAt: hoursAgo(now, 720 - (index * 40)),
      updatedAt: lastTimelineUpdate,
      lastTimelineUpdate,
      followersCount: 0,
      likesCount: likesCountByProject.get(project.id) || 0,
    });
  });

  timelineDocs.forEach((item) => {
    queueSet(plan, db.doc(`projects/${item.projectId}/timeline/${item.itemId}`), {
      type: item.type,
      title: item.title,
      body: item.body,
      createdAt: item.createdAt,
      authorUid: item.authorUid,
      authorName: item.authorName,
      authorPhotoUrl: item.authorPhotoUrl,
      photoUrls: item.photoUrls,
    });
  });

  comments.forEach((comment) => {
    queueSet(plan, db.doc(`projects/${comment.projectId}/timeline/${comment.itemId}/comments/${comment.commentId}`), {
      body: comment.body,
      createdAt: comment.createdAt,
      authorUid: comment.authorUid,
      authorName: comment.authorName,
      authorPhotoUrl: comment.authorPhotoUrl,
    });
  });

  followPairs.forEach(([from, to], i) => {
    const createdAt = hoursAgo(now, 200 + i);
    queueSet(plan, db.doc(`users/${from}/following/${to}`), {uid: to, createdAt});
    queueSet(plan, db.doc(`users/${to}/followers/${from}`), {uid: from, createdAt});
  });

  let userLikeIndex = 0;
  for (const [uid, projectIds] of likesByUser.entries()) {
    projectIds.filter(Boolean).forEach((projectId, i) => {
      const createdAt = hoursAgo(now, 100 + (userLikeIndex * 2) + i);
      queueSet(plan, db.doc(`projects/${projectId}/likes/${uid}`), {uid, createdAt});
      queueSet(plan, db.doc(`users/${uid}/likedProjects/${projectId}`), {projectId, createdAt});
    });
    userLikeIndex++;
  }

  const notifFixtures = [
    {id: "demo_notification_01", type: "new_follower", actorUid: "demo_hugo_figs", hours: 8, read: false},
    {id: "demo_notification_02", type: "project_like", actorUid: "demo_lina_couture", projectShort: "enclosure", hours: 12, read: false},
    {id: "demo_notification_03", type: "post_comment", actorUid: "demo_nolan_firmware", projectShort: "gundam", timelineKey: "gundam:3", hours: 16, read: false},
    {id: "demo_notification_04", type: "project_like", actorUid: "demo_emma_kitbuild", projectShort: "dashboard", hours: 30, read: true},
    {id: "demo_notification_05", type: "post_comment", actorUid: "demo_zoe_brushes", projectShort: "orc", timelineKey: "orc:2", hours: 40, read: true},
  ];

  notifFixtures.forEach((n) => {
    if (n.actorUid === viewerUid) return;
    const actor = userByUid.get(n.actorUid);
    if (!actor) return;
    const projectId = n.projectShort ? projectByShort.get(n.projectShort)?.id : undefined;
    const projectTitle = n.projectShort ? projectByShort.get(n.projectShort)?.title : undefined;
    const timelineMeta = n.timelineKey ? timelineByKey.get(n.timelineKey) : undefined;
    const createdAt = hoursAgo(now, n.hours);
    const readAt = n.read ? new Date(createdAt.getTime() + (2 * HOUR_MS)) : null;

    queueSet(plan, db.doc(`users/${viewerUid}/notifications/${n.id}`), cleanUndefined({
      type: n.type,
      recipientUid: viewerUid,
      actorUid: actor.uid,
      actorName: actor.displayName,
      actorPhotoUrl: photo(`avatar-${actor.uid}`, 300, 300),
      projectId,
      projectTitle,
      itemId: timelineMeta?.itemId,
      itemTitle: timelineMeta?.title,
      createdAt,
      readAt,
    }));
  });

  if (opts.reset) {
    const refsToDelete = [...plan.refsByPath.values()].sort(
      (a, b) => b.path.split("/").length - a.path.split("/").length
    );
    await commitDeletes(db, refsToDelete);
  }
  await commitSets(db, plan.sets);

  const likeDocsCount = [...likesByUser.values()].reduce((acc, ids) => acc + ids.filter(Boolean).length, 0);
  console.log("Seed complete.");
  console.log(`Project: ${projectId}`);
  console.log(`Viewer UID: ${viewerUid}`);
  console.log(`Users: ${USER_FIXTURES.length}`);
  console.log(`Projects: ${PROJECT_FIXTURES.length}`);
  console.log(`Timeline items: ${timelineDocs.length}`);
  console.log(`Comments: ${comments.length}`);
  console.log(`Follow links: ${followPairs.length}`);
  console.log(`Likes: ${likeDocsCount}`);
  console.log("Open app in dev flavor and take screenshots.");
}

main().catch((err) => {
  console.error("Seed failed.");
  console.error(err?.message || err);
  if (String(err?.message || "").toLowerCase().includes("default credentials")) {
    console.error("Tip: pass --serviceAccount <path> or configure ADC via GOOGLE_APPLICATION_CREDENTIALS / gcloud auth application-default login.");
  }
  process.exit(1);
});
