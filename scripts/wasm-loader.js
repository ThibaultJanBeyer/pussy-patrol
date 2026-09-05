// Inlined into the exported HTML <head> by scripts/publish-pages.sh.
//
// GitHub Pages will not let us set Content-Encoding, so the 38 MB engine binary
// ships pre-compressed as game.wasm.gz and is inflated here with the browser's
// native DecompressionStream. Two more jobs while we are in the fetch path:
//
//   * start the wasm and pck downloads during HTML parse, roughly one RTT plus
//     one game.js download earlier than Godot would ask for them;
//   * keep the body a stream, so WebAssembly.instantiateStreaming can compile
//     while bytes are still arriving instead of after the last one.
//
// Note: DecompressionStream has no 'brotli' format in any shipping browser,
// only 'gzip', 'deflate' and 'deflate-raw'. Brotli on the wire needs a server
// that sends Content-Encoding: br. See README.md.
(() => {
	'use strict';

	const WASM = 'game.wasm';
	const WASM_GZ = 'game.wasm.gz';
	const PCK = 'game.pck';

	const origFetch = window.fetch.bind(window);

	const basename = (input) => {
		const url = typeof input === 'string' ? input : (input && input.url) || '';
		return url.split(/[?#]/)[0].split('/').pop();
	};

	// --- pre-warmed downloads -------------------------------------------------

	const warm = new Map();

	const preload = (url) => {
		const res = origFetch(url, { credentials: 'same-origin' });
		// Godot may never claim it (unsupported browser, boot error). Swallow the
		// rejection here so it does not surface as an unhandled one.
		res.catch(() => {});
		warm.set(url, res);
	};

	// One shot. Godot retries a failed load up to 4 times and a consumed body
	// cannot be replayed, so every attempt after the first goes to the network.
	const claim = (url) => {
		const warmed = warm.get(url);
		warm.delete(url);
		return warmed || origFetch(url, { credentials: 'same-origin' });
	};

	// --- gzip -> wasm ---------------------------------------------------------

	async function loadWasm() {
		if (typeof DecompressionStream === 'undefined') {
			throw new Error('This browser cannot decompress the game (DecompressionStream is missing).');
		}

		const res = await claim(WASM_GZ);
		if (!res.ok) {
			throw new Error(`Failed loading file '${WASM_GZ}' (HTTP ${res.status})`);
		}

		// Peek the first two bytes. A proxy that treats .gz as a transfer encoding
		// rather than a file extension hands us the raw wasm already inflated.
		const reader = res.body.getReader();
		let head = new Uint8Array(0);
		let ended = false;
		while (head.length < 2 && !ended) {
			const chunk = await reader.read();
			ended = chunk.done;
			if (chunk.value && chunk.value.length > 0) {
				const merged = new Uint8Array(head.length + chunk.value.length);
				merged.set(head);
				merged.set(chunk.value, head.length);
				head = merged;
			}
		}

		// Re-emit the peeked bytes, then the rest of the response untouched.
		const body = new ReadableStream({
			start(controller) {
				if (head.length > 0) {
					controller.enqueue(head);
				}
				if (ended) {
					controller.close();
				}
			},
			async pull(controller) {
				const chunk = await reader.read();
				if (chunk.done) {
					controller.close();
				} else {
					controller.enqueue(chunk.value);
				}
			},
			cancel(reason) {
				return reader.cancel(reason);
			},
		});

		const gzipped = head.length >= 2 && head[0] === 0x1f && head[1] === 0x8b;
		const wasm = gzipped ? body.pipeThrough(new DecompressionStream('gzip')) : body;

		// instantiateStreaming insists on this content type.
		return new Response(wasm, {
			status: 200,
			headers: { 'Content-Type': 'application/wasm' },
		});
	}

	// --- wire it up -----------------------------------------------------------

	preload(WASM_GZ);
	preload(PCK);

	window.fetch = function (input, init) {
		// Only claim Godot's own plain `fetch(file)` boot requests; anything with
		// custom options is the game talking to the network at runtime.
		if (!init) {
			const name = basename(input);
			if (name === WASM) {
				return loadWasm();
			}
			if (name === PCK) {
				return claim(PCK);
			}
		}
		return origFetch(input, init);
	};
})();
