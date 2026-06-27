import { performance } from 'node:perf_hooks';

const apiKey = process.env.FIREBASE_API_KEY;
const projectId = 'ai-project-manager-12d8d';

const email = process.env.PERF_EMAIL;
const password = process.env.PERF_PASSWORD;
const vus = Number.parseInt(process.env.LOAD_VUS || '10', 10);
const iterationsPerVu = Number.parseInt(process.env.LOAD_ITERATIONS || '5', 10);

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

async function requestJson(url, options = {}) {
  const response = await fetch(url, options);
  const text = await response.text();
  const data = text ? JSON.parse(text) : {};
  if (!response.ok) {
    throw new Error(data.error?.message || `${response.status} ${response.statusText}`);
  }
  return data;
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

function summarize(label, samples) {
  const total = samples.length;
  const okSamples = samples.filter((sample) => sample.ok);
  const elapsedValues = okSamples.map((sample) => sample.elapsed).sort((a, b) => a - b);
  const avg = elapsedValues.length
    ? Math.round(elapsedValues.reduce((sum, value) => sum + value, 0) / elapsedValues.length)
    : 0;
  const min = elapsedValues.length ? elapsedValues[0] : 0;
  const max = elapsedValues.length ? elapsedValues[elapsedValues.length - 1] : 0;
  const p95Index = elapsedValues.length ? Math.min(elapsedValues.length - 1, Math.ceil(elapsedValues.length * 0.95) - 1) : 0;
  const p95 = elapsedValues.length ? elapsedValues[p95Index] : 0;
  const errorRate = total ? Number((((total - okSamples.length) / total) * 100).toFixed(2)) : 0;

  return {
    label,
    total,
    success: okSamples.length,
    avg,
    min,
    max,
    p95,
    errorRate: `${errorRate}%`,
  };
}

async function prepareSharedTarget() {
  const session = await signIn();
  const projects = await queryProjects(session.idToken, session.uid);

  for (const project of projects) {
    const tasks = await queryTasks(session.idToken, project.__id);
    if (tasks.length > 0) {
      return {
        uid: session.uid,
        projectId: project.__id,
        taskId: tasks[0].__id,
        taskStatus: tasks[0].status || 'todo',
      };
    }
  }

  throw new Error('No project with tasks was found for the test account.');
}

async function runVirtualUser(sharedTarget) {
  const samples = {
    login: [],
    projects: [],
    taskDetail: [],
    updateStatus: [],
  };

  const loginSample = await timed('login', signIn);
  samples.login.push(loginSample);
  if (!loginSample.ok) {
    return samples;
  }

  const session = loginSample.result;

  for (let i = 0; i < iterationsPerVu; i += 1) {
    samples.projects.push(await timed(
      'projects',
      () => queryProjects(session.idToken, session.uid),
    ));
    samples.taskDetail.push(await timed(
      'taskDetail',
      () => getTaskDetail(session.idToken, sharedTarget.taskId),
    ));
    samples.updateStatus.push(await timed(
      'updateStatus',
      () => updateTaskStatus(session.idToken, sharedTarget.taskId, sharedTarget.taskStatus),
    ));
  }

  return samples;
}

function flattenSamples(results, key) {
  return results.flatMap((result) => result[key]);
}

const sharedTarget = await prepareSharedTarget();
const startedAt = new Date().toISOString();
const totalStarted = performance.now();

const virtualUsers = Array.from({ length: vus }, () => runVirtualUser(sharedTarget));
const results = await Promise.all(virtualUsers);

const totalDurationMs = Math.round(performance.now() - totalStarted);
const loginSamples = flattenSamples(results, 'login');
const projectSamples = flattenSamples(results, 'projects');
const taskDetailSamples = flattenSamples(results, 'taskDetail');
const updateSamples = flattenSamples(results, 'updateStatus');

console.log(JSON.stringify({
  measuredAt: startedAt,
  config: {
    vus,
    iterationsPerVu,
    totalDurationMs,
  },
  target: sharedTarget,
  summary: [
    summarize('Dang nhap bang Firebase Auth', loginSamples),
    summarize('Lay danh sach du an tu Firestore', projectSamples),
    summarize('Xem chi tiet task', taskDetailSamples),
    summarize('Cap nhat trang thai task tren Kanban', updateSamples),
  ],
  rawCounts: {
    login: loginSamples.length,
    projects: projectSamples.length,
    taskDetail: taskDetailSamples.length,
    updateStatus: updateSamples.length,
  },
}, null, 2));
