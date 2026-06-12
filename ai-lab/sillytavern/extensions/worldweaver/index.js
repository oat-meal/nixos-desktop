// World Weaver — SillyTavern extension.
// Registers function tools so a tool-calling model can build and extend the World Info
// during chat: the model calls create_world() / add_world_entry() and the lorebook is
// written natively in SillyTavern — no copying, no import, no leaving the app.
//
// Uses only the stable SillyTavern.getContext() surface (no app-module imports), so it
// works as a local third-party extension regardless of where it's installed.
//
// Requires tool calling: connect via Chat Completion (Ollama OpenAI-compatible /v1) with
// a tools-capable model (qwen2.5) and Function Calling enabled.

const WW = '[worldweaver]';

// Full SillyTavern World Info entry — defaults; we override a few fields per entry.
const ENTRY_DEFAULTS = {
    uid: 0, key: [], keysecondary: [], comment: '', content: '',
    constant: false, vectorized: false, selective: true, selectiveLogic: 0,
    addMemo: true, order: 100, position: 0, disable: false,
    excludeRecursion: false, preventRecursion: false, delayUntilRecursion: false,
    probability: 100, useProbability: true, depth: 4, group: '',
    groupOverride: false, groupWeight: 100, scanDepth: null, caseSensitive: null,
    matchWholeWords: null, useGroupScoring: null, automationId: '', role: null,
    sticky: 0, cooldown: 0, delay: 0, displayIndex: 0,
};

function makeEntry(uid, { title, keys, content, constant }) {
    return {
        ...ENTRY_DEFAULTS, uid, displayIndex: uid,
        comment: (title || '').trim(),
        content: (content || '').trim(),
        key: constant ? [] : (keys || []),
        constant: !!constant,
    };
}

function nextUid(data) {
    const uids = Object.keys(data.entries || {}).map(Number).filter(Number.isFinite);
    return (uids.length ? Math.max(...uids) : -1) + 1;
}

function register() {
    const ctx = SillyTavern.getContext();
    if (!ctx || typeof ctx.registerFunctionTool !== 'function') {
        console.warn(WW, 'registerFunctionTool unavailable — is tool calling supported on this connection?');
        return;
    }

    ctx.registerFunctionTool({
        name: 'create_world',
        displayName: 'Create World',
        description: 'Create a new World Info lorebook for the roleplay world. Call once, when the premise and tone are established. Keep the core facts concise.',
        parameters: Object.freeze({
            $schema: 'http://json-schema.org/draft-04/schema#',
            type: 'object',
            properties: {
                name: { type: 'string', description: 'Short name for the world / lorebook.' },
                premise: { type: 'string', description: '1-3 sentences: the setting and the central hook.' },
                tone_rules: { type: 'string', description: 'The mood, and what is possible or forbidden in this world.' },
            },
            required: ['name', 'premise', 'tone_rules'],
        }),
        action: async ({ name, premise, tone_rules }) => {
            if (!name) throw new Error('Missing world name');
            const data = { entries: {} };
            data.entries['0'] = makeEntry(0, { title: 'World Premise', content: premise, constant: true });
            data.entries['1'] = makeEntry(1, { title: 'Tone & Rules', content: tone_rules, constant: true });
            await ctx.saveWorldInfo(name, data, true);
            await ctx.updateWorldInfoList();
            return `Created World Info "${name}" with its premise and tone. It now appears in the World Info panel — activate it (or bind it to the group) to use it.`;
        },
        formatMessage: ({ name }) => `Creating world "${name || ''}"...`,
    });

    ctx.registerFunctionTool({
        name: 'add_world_entry',
        displayName: 'Add World Entry',
        description: 'Add one entry to a World Info lorebook: a location, faction, character, item, or fact. Use as the world is built, and whenever new canon appears during play.',
        parameters: Object.freeze({
            $schema: 'http://json-schema.org/draft-04/schema#',
            type: 'object',
            properties: {
                name: { type: 'string', description: 'The world / lorebook to add to.' },
                title: { type: 'string', description: "The element's name (shown as the entry label)." },
                keys: { type: 'string', description: 'Comma-separated trigger words (the name plus aliases the player might type). Omit for always-on facts.' },
                content: { type: 'string', description: '2-4 sentences of concrete lore.' },
                constant: { type: 'boolean', description: 'true = always active; false (default) = only injected when a keyword appears.' },
            },
            required: ['name', 'title', 'content'],
        }),
        action: async ({ name, title, keys, content, constant }) => {
            if (!name || !title) throw new Error('Missing world name or entry title');
            let data = await ctx.loadWorldInfo(name);
            if (!data || !data.entries) data = { entries: {} };
            const uid = nextUid(data);
            const keyArr = String(keys || '').split(',').map(s => s.trim()).filter(Boolean);
            data.entries[String(uid)] = makeEntry(uid, { title, keys: keyArr, content, constant });
            await ctx.saveWorldInfo(name, data, true);
            await ctx.updateWorldInfoList();
            const how = constant ? 'always-on' : (keyArr.length ? `keywords: ${keyArr.join(', ')}` : 'no keywords set');
            return `Added "${title}" to "${name}" (${how}).`;
        },
        formatMessage: ({ title }) => `Recording "${title || 'entry'}"...`,
    });

    console.log(WW, 'registered create_world and add_world_entry tools');
}

try {
    register();
} catch (e) {
    console.error(WW, 'registration failed', e);
}
