import { performance } from 'node:perf_hooks';

const apiKey = process.env.FIREBASE_API_KEY;
const projectId = 'ai-project-manager-12d8d';
const email = process.env.PERF_EMAIL;
const password = process.env.PERF_PASSWORD;
const iterations = Number.parseInt(process.env.PERF_ITERATIONS || '20', 10);

if (!apiKey || !email || !password) {
  throw new Error('Missing FIREBASE_API_KEY, PERF_EMAIL or PERF_PASSWORD environment variable.');
}

const authUrl = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`;
const firestoreBaseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;

function fieldToValue(field) {
  if (!field) return null;
  if ('stringValue' in field) return field.stringValue;
  if ('integerValue' in field) return Number(field.integerValue);
  if ('doubleValue' in field) return field.doubleValue;
  if ('booleanValue' in field) return field.booleanValue;
  if ('timestampValue' in field) return field.timestampValue;
  if ('arrayValue' in field) return (field.arrayValue.values || []).map(fieldToValue);
  if ('mapValue' in field) {
    return Object.fromEntries(
      Object.entries(field.mapValue.fields || {}).map(([key, value]) => [key, fieldToValue(value)]),
    );
  }
  return null;
}

function docToObject(doc) {
  const fields = doc.fields || {};
  const object = {};
  for (const [key, value] of Object.entries(fields)) {
    object[key] = fieldToValue(value);
  }
  object.__name = doc.name;
  object.__id = doc.name.split('/').pop();
  return object;
}

async function timed(label, operation) {
  const started = performance.now();
  try {
    const result = await operation();
    const elapsed = Math.round(performance.now() - started);
    return { label, elapsed, ok: true, result };
  } catch (error) {
    const elapsed = Math.round(performance.now() - started);
    return { label, elapsed, ok: false, error: String(error.message || error) };
  }
}

async function requestJson(url, options = {}) {
  const response = await fetch(url, options);
  const text = await response.text();
  const data = text ? JSON.parse(text) : {};
  if (!response.ok) {
    throw new Error(data.error?.message || `${response.status} ${response.statusText}`);
  }
  return data;
}

async function signIn() {
  const data = await requestJson(authUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email,
      password,
      returnSecureToken: true,
    }),
  });
  return { idToken: data.idToken, uid: data.localId };
}

function authHeaders(idToken) {
  return {
    Authorization: `Bearer ${idToken}`,
    'Content-Type': 'application/json',
  };
}

async function getUserProfile(idToken, uid) {
  const doc = await requestJson(`${firestoreBaseUrl}/USERS/${uid}`, {
    headers: authHeaders(idToken),
  });
  return docToObject(doc);
}

async function queryProjects(idToken, uid) {
  const data = await requestJson(`${firestoreBaseUrl}:runQuery`, {
    method: 'POST',
    headers: authHeaders(idToken),
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'PROJECTS' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'memberIds' },
            op: 'ARRAY_CONTAINS',
            value: { stringValue: uid },
          },
        },
        limit: 20,
      },
    }),
  });
  return data.filter((item) => item.document).map((item) => docToObject(item.document));
}

async function queryTasks(idToken, selectedProjectId) {
  const data = await requestJson(`${firestoreBaseUrl}:runQuery`, {
    method: 'POST',
    headers: authHeaders(idToken),
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'TASKS' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'projectId' },
            op: 'EQUAL',
            value: { stringValue: selectedProjectId },
          },
        },
        limit: 20,
      },
    }),
  });
  return data.filter((item) => item.document).map((item) => docToObject(item.document));
}

async function getTaskDetail(idToken, taskId) {
  const doc = await requestJson(`${firestoreBaseUrl}/TASKS/${taskId}`, {
    headers: authHeaders(idToken),
  });
  return docToObject(doc);
}

async function updateTaskStatus(idToken, taskId, status) {
  await requestJson(`${firestoreBaseUrl}/TASKS/${taskId}?updateMask.fieldPaths=status`, {
    method: 'PATCH',
    headers: authHeaders(idToken),
    body: JSON.stringify({
      fields: {
        status: { stringValue: status || 'todo' },
      },
    }),
  });
}

function summarize(label, values) {
  const okValues = values.filter((item) => item.ok);
  const elapsed = okValues.map((item) => item.elapsed);
  const avg = elapsed.length
    ? Math.round(elapsed.reduce((sum, value) => sum + value, 0) / elapsed.length)
    : 0;
  const min = elapsed.length ? Math.min(...elapsed) : 0;
  const max = elapsed.length ? Math.max(...elapsed) : 0;
  const errorRate = Math.round(((values.length - okValues.length) / values.length) * 100);
  return {
    label,
    count: values.length,
    avg,
    min,
    max,
    errorRate: `${errorRate}%`,
    status: avg < 200 && errorRate === 0 ? 'Dat' : 'Dat co dieu kien',
  };
}

const loginSamples = [];
let session;
for (let i = 0; i < iterations; i += 1) {
  const sample = await timed('Dang nhap bang Firebase Auth', signIn);
  loginSamples.push(sample);
  if (sample.ok) session = sample.result;
}

if (!session) {
  console.log(JSON.stringify({
    error: 'Khong dang nhap duoc bang tai khoan test.',
    samples: loginSamples,
  }, null, 2));
  process.exit(1);
}

await getUserProfile(session.idToken, session.uid);
const projects = await queryProjects(session.idToken, session.uid);
if (projects.length === 0) {
  console.log(JSON.stringify({
    error: 'Tai khoan test khong co project nao de do task.',
    uid: session.uid,
    login: summarize('Dang nhap bang Firebase Auth', loginSamples),
  }, null, 2));
  process.exit(1);
}

let selectedProject = null;
let tasks = [];
for (const project of projects) {
  const projectTasks = await queryTasks(session.idToken, project.__id);
  if (projectTasks.length > 0) {
    selectedProject = project;
    tasks = projectTasks;
    break;
  }
}

if (!selectedProject || tasks.length === 0) {
  console.log(JSON.stringify({
    error: 'Tai khoan test co project nhung chua co task nao de do chi tiet/cap nhat.',
    uid: session.uid,
    projectIds: projects.map((project) => project.__id),
    login: summarize('Dang nhap bang Firebase Auth', loginSamples),
  }, null, 2));
  process.exit(1);
}

const selectedTask = tasks[0];
const currentStatus = selectedTask.status || 'todo';

const projectSamples = [];
const detailSamples = [];
const updateSamples = [];

for (let i = 0; i < iterations; i += 1) {
  projectSamples.push(await timed(
    'Lay danh sach du an tu Firestore',
    () => queryProjects(session.idToken, session.uid),
  ));
  detailSamples.push(await timed(
    'Xem chi tiet task',
    () => getTaskDetail(session.idToken, selectedTask.__id),
  ));
  updateSamples.push(await timed(
    'Cap nhat trang thai task tren Kanban',
    () => updateTaskStatus(session.idToken, selectedTask.__id, currentStatus),
  ));
}

const summary = [
  summarize('Dang nhap bang Firebase Auth', loginSamples),
  summarize('Lay danh sach du an tu Firestore', projectSamples),
  summarize('Xem chi tiet task', detailSamples),
  summarize('Cap nhat trang thai task tren Kanban', updateSamples),
];

console.log(JSON.stringify({
  measuredAt: new Date().toISOString(),
  iterations,
  uid: session.uid,
  selectedProjectId: selectedProject.__id,
  selectedTaskId: selectedTask.__id,
  selectedTaskStatus: currentStatus,
  summary,
  raw: {
    login: loginSamples.map(({ elapsed, ok, error }) => ({ elapsed, ok, error })),
    projects: projectSamples.map(({ elapsed, ok, error }) => ({ elapsed, ok, error })),
    taskDetail: detailSamples.map(({ elapsed, ok, error }) => ({ elapsed, ok, error })),
    updateStatus: updateSamples.map(({ elapsed, ok, error }) => ({ elapsed, ok, error })),
  },
}, null, 2));
