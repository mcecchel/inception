/* THE GAME - countdown logic (plain JavaScript, no libraries). */

const DURATION_MS = 30 * 60 * 1000;
const STORAGE_KEY = 'thegame-deadline';

const minEl = document.getElementById('min');
const secEl = document.getElementById('sec');
const captionEl = document.getElementById('caption');
const badgeEl = document.getElementById('status-badge');
const progressEl = document.getElementById('progress-fill');
const resetBtn = document.getElementById('reset');

function loadDeadline() {
	try {
		const saved = Number(localStorage.getItem(STORAGE_KEY));
		if (saved > 0) return saved;
	} catch (e) { /* ignore */ }
	return null;
}

function saveDeadline(value) {
	try { localStorage.setItem(STORAGE_KEY, String(value)); } catch (e) { /* ignore */ }
}

let deadline = loadDeadline();
if (deadline === null) {
	deadline = Date.now() + DURATION_MS;
	saveDeadline(deadline);
}

const pad = (n) => String(n).padStart(2, '0');

function render() {
	const remainingMs = Math.max(0, deadline - Date.now());
	const totalSeconds = Math.ceil(remainingMs / 1000);
	const minutes = Math.floor(totalSeconds / 60);
	const seconds = totalSeconds % 60;

	minEl.textContent = pad(minutes);
	secEl.textContent = pad(seconds);
	document.title = `${pad(minutes)}:${pad(seconds)} - you just lost the game`;

	const pct = Math.min(100, Math.max(0, (remainingMs / DURATION_MS) * 100));
	progressEl.style.width = `${pct}%`;

	const over = totalSeconds === 0;
	document.body.classList.toggle('over', over);
	captionEl.textContent = over ? 'you can lose again!' : "you can't lose again for";
	badgeEl.textContent = over ? 'WARNING // VULNERABLE' : 'GRACE PERIOD ACTIVE';
}

resetBtn.addEventListener('click', () => {
	deadline = Date.now() + DURATION_MS;
	saveDeadline(deadline);
	render();
});

render();
setInterval(render, 250);