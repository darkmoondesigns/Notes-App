const STORAGE_KEY = 'meeting_notes_board_v2';

const state = loadState();
normalizeState();

const el = {
  topicList: document.getElementById('topic-list'),
  meetingList: document.getElementById('meeting-list'),
  contextTitle: document.getElementById('context-title'),
  contextSubtitle: document.getElementById('context-subtitle'),
  searchInput: document.getElementById('search-input'),
  filterType: document.getElementById('filter-type'),
  entryList: document.getElementById('entry-list'),
  addTopic: document.getElementById('add-topic'),
  addMeeting: document.getElementById('add-meeting'),
  newNote: document.getElementById('new-note'),
  newTodo: document.getElementById('new-todo'),
  exportBtn: document.getElementById('export-btn'),
  importInput: document.getElementById('import-input'),
  entryDialog: document.getElementById('entry-dialog'),
  entryForm: document.getElementById('entry-form'),
  entryTitle: document.getElementById('entry-title'),
  entryBody: document.getElementById('entry-body'),
  entryDone: document.getElementById('entry-done'),
  dialogTitle: document.getElementById('dialog-title'),
  cancelEntry: document.getElementById('cancel-entry'),
  textDialog: document.getElementById('text-dialog'),
  textForm: document.getElementById('text-form'),
  textTitle: document.getElementById('text-title'),
  textInput: document.getElementById('text-input'),
  textDate: document.getElementById('text-date'),
  cancelText: document.getElementById('cancel-text')
};

let entryDraft = null;
let textDraft = null;

bindEvents();
render();

function bindEvents() {
  el.addTopic.addEventListener('click', () => openTextDialog('Neues Thema', false, ({ text }) => {
    const topic = { id: id(), name: text, createdAt: now() };
    state.topics.push(topic);
    state.activeTopicId = topic.id;
    state.activeMeetingId = '';
    persistAndRender();
  }));

  el.addMeeting.addEventListener('click', () => {
    if (!state.activeTopicId) return alert('Bitte zuerst ein Thema anlegen/auswählen.');
    openTextDialog('Neues Meeting', true, ({ text, date }) => {
      const meeting = {
        id: id(),
        topicId: state.activeTopicId,
        title: text,
        happenedAt: date || new Date().toISOString().slice(0, 10),
        createdAt: now()
      };
      state.meetings.push(meeting);
      state.activeMeetingId = meeting.id;
      persistAndRender();
    });
  });

  el.newNote.addEventListener('click', () => openEntryDialog('NOTE'));
  el.newTodo.addEventListener('click', () => openEntryDialog('TODO'));
  el.searchInput.addEventListener('input', renderEntries);
  el.filterType.addEventListener('change', renderEntries);

  el.entryForm.addEventListener('submit', (event) => {
    event.preventDefault();
    if (!entryDraft) return;
    const title = el.entryTitle.value.trim();
    if (!title) return;

    if (entryDraft.mode === 'create') {
      state.entries.push({
        id: id(),
        topicId: state.activeTopicId,
        meetingId: state.activeMeetingId || '',
        type: entryDraft.type,
        title,
        body: el.entryBody.value.trim(),
        status: entryDraft.type === 'TODO' && el.entryDone.checked ? 'DONE' : 'OPEN',
        createdAt: now(),
        updatedAt: now()
      });
    } else {
      const found = state.entries.find((item) => item.id === entryDraft.entryId);
      if (found) {
        found.title = title;
        found.body = el.entryBody.value.trim();
        if (found.type === 'TODO') found.status = el.entryDone.checked ? 'DONE' : 'OPEN';
        found.updatedAt = now();
      }
    }

    el.entryDialog.close();
    entryDraft = null;
    persistAndRender();
  });

  el.cancelEntry.addEventListener('click', () => {
    entryDraft = null;
    el.entryDialog.close();
  });

  el.textForm.addEventListener('submit', (event) => {
    event.preventDefault();
    if (!textDraft) return;
    const text = el.textInput.value.trim();
    if (!text) return;
    textDraft.onSave({ text, date: el.textDate.value });
    textDraft = null;
    el.textDialog.close();
  });

  el.cancelText.addEventListener('click', () => {
    textDraft = null;
    el.textDialog.close();
  });

  el.exportBtn.addEventListener('click', exportState);
  el.importInput.addEventListener('change', importState);
}

function openTextDialog(title, withDate, onSave) {
  el.textTitle.textContent = title;
  el.textInput.value = '';
  el.textDate.value = '';
  el.textDate.style.display = withDate ? 'block' : 'none';
  textDraft = { onSave };
  el.textDialog.showModal();
  el.textInput.focus();
}

function openEntryDialog(type, existing) {
  if (!state.activeTopicId) return alert('Bitte zuerst ein Thema anlegen/auswählen.');
  el.entryDone.parentElement.style.visibility = type === 'TODO' ? 'visible' : 'hidden';

  if (existing) {
    entryDraft = { mode: 'edit', entryId: existing.id, type: existing.type };
    el.dialogTitle.textContent = `${existing.type === 'TODO' ? 'Todo' : 'Notiz'} bearbeiten`;
    el.entryTitle.value = existing.title;
    el.entryBody.value = existing.body;
    el.entryDone.checked = existing.status === 'DONE';
  } else {
    entryDraft = { mode: 'create', type };
    el.dialogTitle.textContent = `${type === 'TODO' ? 'Neues Todo' : 'Neue Notiz'}`;
    el.entryTitle.value = '';
    el.entryBody.value = '';
    el.entryDone.checked = false;
  }

  el.entryDialog.showModal();
  el.entryTitle.focus();
}

function render() {
  renderSidebar();
  renderContext();
  renderEntries();
}

function renderSidebar() {
  el.topicList.innerHTML = '';
  state.topics.forEach((topic) => {
    const li = document.createElement('li');
    li.className = topic.id === state.activeTopicId ? 'active' : '';
    li.innerHTML = `<span>${escapeHtml(topic.name)}</span>
      <div><small>${topic.createdAt.slice(0, 10)}</small> <button data-delete-topic="${topic.id}" title="Thema löschen">✕</button></div>`;
    li.addEventListener('click', () => {
      state.activeTopicId = topic.id;
      const firstMeeting = state.meetings.find((m) => m.topicId === topic.id);
      state.activeMeetingId = firstMeeting ? firstMeeting.id : '';
      persistAndRender();
    });
    li.querySelector('[data-delete-topic]').addEventListener('click', (e) => {
      e.stopPropagation();
      deleteTopic(topic.id);
    });
    el.topicList.appendChild(li);
  });

  el.meetingList.innerHTML = '';
  const meetings = state.meetings
    .filter((meeting) => meeting.topicId === state.activeTopicId)
    .sort((a, b) => b.happenedAt.localeCompare(a.happenedAt));

  meetings.forEach((meeting) => {
    const li = document.createElement('li');
    li.className = meeting.id === state.activeMeetingId ? 'active' : '';
    li.innerHTML = `<span>${escapeHtml(meeting.title)}</span>
      <div><small>${meeting.happenedAt}</small> <button data-delete-meeting="${meeting.id}" title="Meeting löschen">✕</button></div>`;
    li.addEventListener('click', () => {
      state.activeMeetingId = meeting.id;
      persistAndRender();
    });
    li.querySelector('[data-delete-meeting]').addEventListener('click', (e) => {
      e.stopPropagation();
      deleteMeeting(meeting.id);
    });
    el.meetingList.appendChild(li);
  });
}

function renderContext() {
  const topic = state.topics.find((item) => item.id === state.activeTopicId);
  const meeting = state.meetings.find((item) => item.id === state.activeMeetingId);

  if (!topic) {
    el.contextTitle.textContent = 'Kein Thema ausgewählt';
    el.contextSubtitle.textContent = 'Lege links ein Thema an.';
    return;
  }

  el.contextTitle.textContent = topic.name;
  el.contextSubtitle.textContent = meeting
    ? `Meeting: ${meeting.title} (${meeting.happenedAt})`
    : 'Kein Meeting ausgewählt (zeigt allgemeine Thema-Notizen).';
}

function renderEntries() {
  const query = el.searchInput.value.trim().toLowerCase();
  const typeFilter = el.filterType.value;
  const topicId = state.activeTopicId;
  const meetingId = state.activeMeetingId;

  let entries = state.entries
    .filter((entry) => entry.topicId === topicId)
    .filter((entry) => !meetingId || entry.meetingId === meetingId || entry.meetingId === '');

  if (typeFilter !== 'ALL') entries = entries.filter((entry) => entry.type === typeFilter);
  if (query) {
    entries = entries.filter((entry) => `${entry.title} ${entry.body}`.toLowerCase().includes(query));
  }

  entries.sort((a, b) => (b.updatedAt || b.createdAt).localeCompare(a.updatedAt || a.createdAt));

  if (!entries.length) {
    el.entryList.innerHTML = `<article class="empty">Keine Einträge gefunden. Lege eine Notiz oder ein Todo an.</article>`;
    return;
  }

  el.entryList.innerHTML = entries.map((entry) => {
    const doneClass = entry.status === 'DONE' ? 'done' : '';
    const typeBadge = entry.type === 'TODO' ? 'Todo' : 'Notiz';

    return `<article class="card ${entry.type === 'TODO' ? 'todo' : ''} ${doneClass}">
      <h3>${escapeHtml(entry.title)} <span class="chip">${typeBadge}</span></h3>
      <p>${escapeHtml(entry.body || '')}</p>
      <div class="row">
        <small>${entry.updatedAt || entry.createdAt}</small>
        <div class="actions">
          ${entry.type === 'TODO' ? `<button class="secondary" data-toggle="${entry.id}">${entry.status === 'DONE' ? 'Open' : 'Done'}</button>` : ''}
          <button class="secondary" data-edit="${entry.id}">Bearbeiten</button>
          <button class="secondary" data-delete="${entry.id}">Löschen</button>
        </div>
      </div>
    </article>`;
  }).join('');

  el.entryList.querySelectorAll('[data-toggle]').forEach((button) => {
    button.addEventListener('click', () => {
      const found = state.entries.find((entry) => entry.id === button.dataset.toggle);
      if (!found) return;
      found.status = found.status === 'DONE' ? 'OPEN' : 'DONE';
      found.updatedAt = now();
      persistAndRender();
    });
  });

  el.entryList.querySelectorAll('[data-edit]').forEach((button) => {
    button.addEventListener('click', () => {
      const found = state.entries.find((entry) => entry.id === button.dataset.edit);
      if (found) openEntryDialog(found.type, found);
    });
  });

  el.entryList.querySelectorAll('[data-delete]').forEach((button) => {
    button.addEventListener('click', () => {
      state.entries = state.entries.filter((entry) => entry.id !== button.dataset.delete);
      persistAndRender();
    });
  });
}

function deleteTopic(topicId) {
  state.topics = state.topics.filter((topic) => topic.id !== topicId);
  const meetingIds = new Set(state.meetings.filter((m) => m.topicId === topicId).map((m) => m.id));
  state.meetings = state.meetings.filter((m) => m.topicId !== topicId);
  state.entries = state.entries.filter((entry) => entry.topicId !== topicId && !meetingIds.has(entry.meetingId));

  if (state.activeTopicId === topicId) {
    state.activeTopicId = state.topics[0]?.id || '';
    const firstMeeting = state.meetings.find((m) => m.topicId === state.activeTopicId);
    state.activeMeetingId = firstMeeting ? firstMeeting.id : '';
  }
  persistAndRender();
}

function deleteMeeting(meetingId) {
  state.meetings = state.meetings.filter((meeting) => meeting.id !== meetingId);
  state.entries = state.entries.map((entry) => (
    entry.meetingId === meetingId ? { ...entry, meetingId: '', updatedAt: now() } : entry
  ));

  if (state.activeMeetingId === meetingId) {
    const firstMeeting = state.meetings.find((m) => m.topicId === state.activeTopicId);
    state.activeMeetingId = firstMeeting ? firstMeeting.id : '';
  }
  persistAndRender();
}

function exportState() {
  const blob = new Blob([JSON.stringify(state, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'meeting-notes-backup.json';
  a.click();
  URL.revokeObjectURL(url);
}

async function importState(event) {
  const file = event.target.files[0];
  if (!file) return;
  try {
    const imported = JSON.parse(await file.text());
    if (!imported.topics || !imported.meetings || !imported.entries) {
      alert('Ungültiges Backup-Format.');
      return;
    }
    Object.assign(state, imported);
    normalizeState();
    persistAndRender();
  } catch (_error) {
    alert('Import fehlgeschlagen: Datei ist kein valides JSON.');
  } finally {
    event.target.value = '';
  }
}

function normalizeState() {
  state.topics ||= [];
  state.meetings ||= [];
  state.entries ||= [];
  state.activeTopicId ||= state.topics[0]?.id || '';

  const topicExists = state.topics.some((topic) => topic.id === state.activeTopicId);
  if (!topicExists) state.activeTopicId = state.topics[0]?.id || '';

  const meetingExists = state.meetings.some((meeting) => meeting.id === state.activeMeetingId);
  if (!meetingExists) {
    const firstMeeting = state.meetings.find((meeting) => meeting.topicId === state.activeTopicId);
    state.activeMeetingId = firstMeeting ? firstMeeting.id : '';
  }
}

function persistAndRender() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  render();
}

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw);
  } catch (_err) {}
  return { topics: [], meetings: [], entries: [], activeTopicId: '', activeMeetingId: '' };
}

function now() { return new Date().toISOString().slice(0, 19); }
function id() { return Math.random().toString(36).slice(2, 10); }
function escapeHtml(text) {
  return String(text)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}
