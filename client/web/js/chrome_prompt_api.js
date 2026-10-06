/**
 * Chrome Prompt API Bridge (Gemini Nano on-device in Chrome)
 * Follows Chrome Built-in AI specifications (window.ai.languageModel / self.ai.languageModel)
 * Model Matrix spec: Gemini Nano (~1.8B params, 4-bit), TTFT: 30-55ms, 0 KB egress.
 * 
 * STRICT NEVER MOCK DIRECTIVE: Never mock, simulate, or hardcode fake data across APIs or services.
 * Surface true availability, runtime status, and errors directly.
 */

(function() {
  'use strict';

  const FLAG_INSTRUCTIONS =
    'To enable on-device Gemini Nano in Chrome:\n' +
    '1. Open chrome://flags/#prompt-api (or #prompt-api-for-gemini-nano) -> set to "Enabled"\n' +
    '2. Note: The legacy flag #optimization-guide-on-device-model has been deprecated and removed in modern Chrome; do not look for it.\n' +
    '3. Storage & Hardware: Ensure >= 22 GB free disk space on your startup drive (Chrome automatically blocks/evicts on-device models if free space is below 10 GB) and an unmetered connection.\n' +
    '4. Relaunch Chrome, then visit chrome://on-device-internals to inspect model download status, or trigger download in DevTools console via: await LanguageModel.create()';

  class ChromePromptAPIBridge {
    constructor() {
      this._session = null;
      this._initialized = false;
      this._hasNativeAI = false;
      this._status = 'no';
      this._contextWindow = 0;
      this._errorMessage = null;
    }

    _resolveLanguageModelAPI() {
      // 1. Standardized Prompt API (Chrome 131+ / 2025-2026 window.LanguageModel)
      if (typeof window !== 'undefined' && window.LanguageModel) {
        return window.LanguageModel;
      }
      if (typeof globalThis !== 'undefined' && globalThis.LanguageModel) {
        return globalThis.LanguageModel;
      }
      if (typeof self !== 'undefined' && self.LanguageModel) {
        return self.LanguageModel;
      }
      // 2. Early preview & Origin Trial namespaces (window.ai.languageModel)
      if (typeof window !== 'undefined' && window.ai && window.ai.languageModel) {
        return window.ai.languageModel;
      }
      if (typeof globalThis !== 'undefined' && globalThis.ai && globalThis.ai.languageModel) {
        return globalThis.ai.languageModel;
      }
      if (typeof self !== 'undefined' && self.ai && self.ai.languageModel) {
        return self.ai.languageModel;
      }
      if (typeof window !== 'undefined' && window.model && window.model.languageModel) {
        return window.model.languageModel;
      }
      return null;
    }

    async init() {
      const lm = this._resolveLanguageModelAPI();
      if (!lm) {
        this._hasNativeAI = false;
        this._status = 'not_supported';
        this._errorMessage = `Chrome Built-in AI (window.LanguageModel / window.ai.languageModel) not detected in this browser session. ${FLAG_INSTRUCTIONS}`;
        this._initialized = true;
        return {
          isAvailable: false,
          isNative: false,
          status: 'no',
          modelName: 'Gemini Nano (Chrome Built-in AI)',
          contextWindow: 0,
          errorMessage: this._errorMessage
        };
      }

      try {
        let status = 'no';
        let contextWindow = 4096;

        if (typeof lm.availability === 'function') {
          status = await lm.availability();
        } else if (typeof lm.capabilities === 'function') {
          const caps = await lm.capabilities();
          status = (caps && caps.available) ? caps.available : 'no';
          if (caps && caps.maxTokens) contextWindow = caps.maxTokens;
        } else {
          status = 'available';
        }

        this._status = status;
        // Standard Chrome values: 'available', 'downloadable', 'downloading', legacy: 'readily', 'after-download'
        const available = (status === 'available' || status === 'readily' || status === 'downloadable' || status === 'after-download');
        this._hasNativeAI = available;
        this._contextWindow = available ? contextWindow : 0;

        if (!available) {
          this._errorMessage = `Chrome Prompt API status is '${status}'. ${FLAG_INSTRUCTIONS}`;
        } else {
          this._errorMessage = null;
        }

        console.log('[ChromePromptAPIBridge] Probe status:', status, 'Available:', available);
      } catch (err) {
        console.warn('[ChromePromptAPIBridge] Error probing capabilities:', err);
        this._hasNativeAI = false;
        this._status = 'error';
        this._errorMessage = `Failed to probe Chrome Built-in AI: ${err && err.message ? err.message : String(err)}. ${FLAG_INSTRUCTIONS}`;
      }

      this._initialized = true;
      const isDownloaded = (this._status === 'available' || this._status === 'readily');
      return {
        isAvailable: this._hasNativeAI,
        isNative: this._hasNativeAI,
        isDownloaded: isDownloaded,
        isActive: isDownloaded,
        needsDownload: (this._status === 'downloadable' || this._status === 'after-download'),
        status: this._status,
        modelName: 'Gemini Nano (Chrome Built-in AI)',
        contextWindow: this._contextWindow,
        errorMessage: this._errorMessage,
        instructions: FLAG_INSTRUCTIONS
      };
    }

    getInstructions() {
      return FLAG_INSTRUCTIONS;
    }

    async checkAvailability() {
      if (!this._initialized) {
        return await this.init();
      }
      const isDownloaded = (this._status === 'available' || this._status === 'readily');
      return {
        isAvailable: this._hasNativeAI,
        isNative: this._hasNativeAI,
        isDownloaded: isDownloaded,
        isActive: isDownloaded,
        needsDownload: (this._status === 'downloadable' || this._status === 'after-download'),
        status: this._status,
        modelName: 'Gemini Nano (Chrome Built-in AI)',
        contextWindow: this._contextWindow,
        errorMessage: this._errorMessage,
        instructions: FLAG_INSTRUCTIONS
      };
    }

    async createSession(systemPrompt = '', onProgress = null) {
      const lm = this._resolveLanguageModelAPI();
      if (!lm) {
        throw new Error(this._errorMessage || `Chrome Prompt API not detected in browser. ${FLAG_INSTRUCTIONS}`);
      }

      if (this._session && typeof this._session.destroy === 'function') {
        try {
          this._session.destroy();
        } catch (_) {}
      }

      try {
        const options = {};
        if (systemPrompt) options.systemPrompt = systemPrompt;
        if (typeof onProgress === 'function') {
          options.monitor = (m) => {
            m.addEventListener('downloadprogress', (e) => {
              const loaded = (typeof e.loaded === 'number') ? e.loaded : 0;
              const total = (typeof e.total === 'number') ? e.total : 0;
              onProgress(loaded, total);
            });
          };
        }
        this._status = 'downloading';
        this._session = await lm.create(options);
        this._status = 'available';
        this._hasNativeAI = true;
        this._errorMessage = null;
        return this._session;
      } catch (err) {
        this._session = null;
        this._status = 'error';
        const msg = err && err.message ? err.message : String(err);
        this._errorMessage = msg;
        console.error('[ChromePromptAPIBridge] Failed to create session:', err);
        throw err;
      }
    }

    async createLanguageModel(onProgress) {
      return await this.triggerDownload(onProgress);
    }

    async triggerDownload(onProgress) {
      const lm = this._resolveLanguageModelAPI();
      if (!lm) {
        return {
          success: false,
          status: 'no_api',
          message: `Chrome Prompt API not detected. ${FLAG_INSTRUCTIONS}`
        };
      }
      try {
        await this.createSession('', onProgress);
        this._status = 'available';
        this._hasNativeAI = true;
        this._errorMessage = null;
        return {
          success: true,
          status: 'available',
          message: 'Gemini Nano initialized successfully in Chrome.'
        };
      } catch (err) {
        const msg = err && err.message ? err.message : String(err);
        return {
          success: false,
          status: this._status,
          message: msg
        };
      }
    }

    async promptStreaming(promptText, onChunk, onDone, onError) {
      if (!this._initialized) await this.init();

      if (!this._hasNativeAI) {
        const err = new Error(this._errorMessage || `Chrome Built-in AI is unavailable. ${FLAG_INSTRUCTIONS}`);
        if (typeof onError === 'function') onError(err.message);
        return;
      }

      const startTime = performance.now();
      let firstTokenTime = null;
      let tokenCount = 0;
      let accumulated = '';
      let previousLength = 0;

      try {
        const isGameMaster = promptText.includes('Game Master') || promptText.includes('GAME MASTER ARBITER') || promptText.includes('OPERATION AETHER BREACH');
        const isPersona = promptText.includes('[NPC PERSONA:');
        const currentTaskType = isGameMaster ? 'gamemaster' : (isPersona ? 'persona' : 'default');

        if (this._session && this._lastTaskType && this._lastTaskType !== currentTaskType) {
          try {
            this._session.destroy();
          } catch (_) {}
          this._session = null;
        }
        this._lastTaskType = currentTaskType;

        if (!this._session) {
          await this.createSession();
        }

        const stream = this._session.promptStreaming(promptText);

        for await (const chunk of stream) {
          if (firstTokenTime === null) {
            firstTokenTime = performance.now();
          }

          let delta = '';
          if (typeof chunk === 'string') {
            if (chunk.startsWith(accumulated)) {
              // Cumulative streaming behavior (standard Chrome Prompt API)
              delta = chunk.slice(previousLength);
              accumulated = chunk;
              previousLength = chunk.length;
            } else {
              // Delta-only streaming behavior
              delta = chunk;
              accumulated += chunk;
              previousLength = accumulated.length;
            }
          }

          if (delta && delta.length > 0) {
            tokenCount += delta.trim().split(/\s+/).filter(Boolean).length || 1;
            if (typeof onChunk === 'function') onChunk(delta);
          }
        }

        const totalTime = performance.now() - startTime;
        const ttft = firstTokenTime ? (firstTokenTime - startTime) : Math.max(totalTime, 1);
        const tps = Number((tokenCount / (Math.max(totalTime, 1) / 1000)).toFixed(1));

        if (typeof onDone === 'function') {
          onDone({
            ttftMs: Math.round(ttft),
            totalLatencyMs: Math.round(totalTime),
            tokenCount: Math.max(1, tokenCount),
            tps: tps,
            egressBytes: 0,
            model: 'Gemini Nano (Chrome Built-in AI)'
          });
        }
      } catch (err) {
        console.error('[ChromePromptAPIBridge] Streaming failure:', err);
        const message = err && err.message ? err.message : String(err);
        if (typeof onError === 'function') onError(message);
      }
    }
  }

  window.chromePromptAPIBridge = new ChromePromptAPIBridge();
  window.chromePromptAPIBridge.init();
})();
