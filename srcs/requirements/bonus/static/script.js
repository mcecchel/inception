/* THE GAME - countdown logic (plain JavaScript, no libraries).
 *
 * After "losing", the player is safe for 30 minutes. The page keeps a deadline
 * (a timestamp), not a counter: the remaining time is recomputed from the clock
 * at every tick, so it stays exact even if the tab is throttled in background.
 * The deadline is saved in localStorage, so a page refresh does not restart the
 * countdown. The "YES I DO" button sets a new deadline: now + 30 minutes. */

const DURATION_MS = 30 * 60 * 1000;
const STORAGE_KEY = 'thegame-deadline';

const minEl = document.getElementById('min');
const secEl = document.getElementById('sec');
const captionEl = document.getElementById('caption');
const resetBtn = document.getElementById('reset');

/* localStorage can be unavailable (private mode, blocked cookies): never crash. */
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

/* First visit: the countdown starts now. */
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
	document.title = pad(minutes) + ':' + pad(seconds) + ' - you just lost the game';

	const over = totalSeconds === 0;
	document.body.classList.toggle('over', over);
	captionEl.textContent = over ? 'you can lose again!' : "you can't lose again for";
}

resetBtn.addEventListener('click', () => {
	deadline = Date.now() + DURATION_MS;
	saveDeadline(deadline);
	render();
});

render();
setInterval(render, 250);