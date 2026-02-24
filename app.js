const STORAGE_KEY = 'notes_app_v1';

const state = loadState();
if (!state.activeTopicId && state.topics.length) state.activeTopicId = state.topics[0].id;
if (!state.activeMeetingId && state.meetings.length) state.activeMeetingId = state.meetings[0].id;

const el = {
  topicForm: document.getElementById('topic-form'),
  topicName: document.getElementById('topic-name'),
  topicList: document.getElementById('topic-list'),
  meetingForm: document.getElementById('meeting-form'),
  meetingTitle: document.getElementById('meeting-title'),
  meetingDate: document.getElementById('meeting-date'),
  meetingList: document.getElementById('meeting-list'),
  entryForm: document.getElementById('entry-form'),
  entryTitle: document.getElementById('entry-title'),
  entryBody: document.getElementById('entry-body'),
  entries: document.getElementById('entries'),
  exportBtn: document.getElementById('export-btn'),
  importInput: document.getElementById('import-input'),
  clearBtn: document.getElementById('clear-btn')
};

bindEvents();
render();

function bindEvents() {
  el.topicForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const name = el.topicName.value.trim();
    if (!name) return;
    const topic = { id: id(), name, createdAt: now() };
    state.topics.push(topic);
    state.activeTopicId = topic.id;
    state.activeMeetingId = '';
    el.topicName.value = '';
    persistAndRender();
  });

  el.meetingForm.addEventListener('submit', (e) => {
    e.preventDefault();
    if (!state.activeTopicId) return alert('Bitte zuerst ein Thema wählen.');
    const title = el.meetingTitle.value.trim();
    if (!title) return;
    const meeting = {
      id: id(),
      topicId: state.activeTopicId,
      title,
      happenedAt: el.meetingDate.value || new Date().toISOString().slice(0, 10),
      createdAt: now()
    };
    state.meetings.push(meeting);
    state.activeMeetingId = meeting.id;
    el.meetingTitle.value = '';
    el.meetingDate.value = '';
    persistAndRender();
  });

  el.entryForm.addEventListener('submit', (e) => {
    e.preventDefault();
    if (!state.activeTopicId) return alert('Bitte zuerst ein Thema wählen.');
    const title = el.entryTitle.value.trim();
    if (!title) return;
    const type = document.querySelector('input[name="entry-type"]:checked').value;
    state.entries.push({
      id: id(),
      topicId: state.activeTopicId,
      meetingId: state.activeMeetingId || '',
      type,
      title,
      body: el.entryBody.value.trim(),
      status: 'OPEN',
      createdAt: now()
    });
    el.entryTitle.value = '';
    el.entryBody.value = '';
    persistAndRender();
  });

  el.exportBtn.addEventListener('click', () => {
    const blob = new Blob([JSON.stringify(state, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'notes-export.json';
    a.click();
    URL.revokeObjectURL(url);
  });

  el.importInput.addEventListener('change', async () => {
    const file = el.importInput.files[0];
    if (!file) return;
    const imported = JSON.parse(await file.text());
    if (!imported.topics || !imported.meetings || !imported.entries) {
      return alert('Ungültige Datei.');
    }
    Object.assign(state, imported);
    persistAndRender();
  });

  el.clearBtn.addEventListener('click', () => {
    if (!confirm('Wirklich alles löschen?')) return;
    localStorage.removeItem(STORAGE_KEY);
    location.reload();
  });
}

function render() {
  renderTopics();
  renderMeetings();
  renderEntries();
}

function renderTopics() {
  el.topicList.innerHTML = '';
  state.topics.forEach((topic) => {
    const li = document.createElement('li');
    li.className = topic.id === state.activeTopicId ? 'active' : '';
    li.innerHTML = `<span>${escapeHtml(topic.name)}</span><small>${topic.createdAt.slice(0, 10)}</small>`;
    li.onclick = () => {
      state.activeTopicId = topic.id;
      const firstMeeting = state.meetings.find((m) => m.topicId === topic.id);
      state.activeMeetingId = firstMeeting ? firstMeeting.id : '';
      persistAndRender();
    };
    el.topicList.appendChild(li);
  });
}

function renderMeetings() {
  el.meetingList.innerHTML = '';
  const meetings = state.meetings
    .filter((m) => m.topicId === state.activeTopicId)
    .sort((a, b) => b.happenedAt.localeCompare(a.happenedAt));
  meetings.forEach((meeting) => {
    const li = document.createElement('li');
    li.className = meeting.id === state.activeMeetingId ? 'active' : '';
    li.innerHTML = `<span>${escapeHtml(meeting.title)}</span><small>${meeting.happenedAt}</small>`;
    li.onclick = () => {
      state.activeMeetingId = meeting.id;
      persistAndRender();
    };
    el.meetingList.appendChild(li);
  });
}

function renderEntries() {
  const topicId = state.activeTopicId;
  const meetingId = state.activeMeetingId;
  const entries = state.entries
    .filter((e) => e.topicId === topicId && (!meetingId || e.meetingId === meetingId || e.meetingId === ''))
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));

  el.entries.innerHTML = entries
    .map((e) => {
      const doneClass = e.status === 'DONE' ? 'done' : '';
      const todoBtn = e.type === 'TODO' && e.status !== 'DONE'
        ? `<button data-done="${e.id}">Done</button>`
        : '';
      return `<article class="entry ${e.type === 'TODO' ? 'todo' : ''} ${doneClass}">
        <h4>${escapeHtml(e.title)} <span>${e.type} ${todoBtn}</span></h4>
        <div>${escapeHtml(e.body || '')}</div>
        <small>${e.createdAt}</small>
      </article>`;
    })
    .join('') || '<p>Keine Einträge vorhanden.</p>';

  el.entries.querySelectorAll('button[data-done]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const item = state.entries.find((x) => x.id === btn.dataset.done);
      if (item) item.status = 'DONE';
      persistAndRender();
    });
  });
}

function persistAndRender() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  render();
}

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw);
  } catch (_e) {}
  return { topics: [], meetings: [], entries: [], activeTopicId: '', activeMeetingId: '' };
}

function now() { return new Date().toISOString().slice(0, 19); }
function id() { return Math.random().toString(36).slice(2, 10); }
function escapeHtml(str) {
  return String(str)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}
